import Foundation

/// Orchestrates bounded repository observation for Timeline (Phase 16).
/// Holds only raw per-type arrays; `TimelineAggregator` turns them into
/// `TimelineDaySection`s on demand so there is a single source of truth for
/// semantics and no duplicated grouping logic between model and view.
@MainActor
@Observable
final class TimelineViewModel {
    private(set) var loadedWindow: DateInterval
    var filter: TimelineFilter = .all
    var displayMode: TimelineDisplayMode = .fullList
    /// True whenever the loaded window is being (re)subscribed — covers the
    /// initial load, scrolling into older content, jumping to a date, and a
    /// day-boundary preference change. The UI shows a compact loading state
    /// only when `sections` is still empty; otherwise cached rows stay
    /// visible while fresh data streams in.
    private(set) var isLoadingWindow = true
    private(set) var errorMessage: String?

    private var pumps: [PumpSession] = []
    private var pumpImmediatelyBeforeWindow: PumpSession?
    private var bottles: [BottleFeed] = []
    private var nursingSessions: [NursingSession] = []
    private var sleepSessionsRanged: [SleepSession] = []
    private var openSleepSessions: [SleepSession] = []
    private var diaperEvents: [DiaperEvent] = []
    private var checklistEvents: [ChecklistEvent] = []
    private var checklistItemsAll: [ChecklistItem] = []
    private var growthMeasurements: [GrowthMeasurement] = []

    @ObservationIgnored private var babyID: String?
    @ObservationIgnored private var nightStartMinutes = Baby.defaultNightStartMinutes
    @ObservationIgnored private var nightEndMinutes = Baby.defaultNightEndMinutes
    @ObservationIgnored private var babyScopedTask: Task<Void, Never>?
    @ObservationIgnored private var windowedTask: Task<Void, Never>?
    @ObservationIgnored private var readyWindowedStreamKeys: Set<String> = []
    @ObservationIgnored private static let windowedStreamKeys: Set<String> = [
        "pumps", "bottles", "nursing", "sleep", "diapers", "checklistEvents", "growth"
    ]

    init(now: Date = .now) {
        loadedWindow = TimelineAggregator.initialWindow(now: now, preferences: .defaults)
    }

    var checklistItemsByID: [String: ChecklistItem] {
        Dictionary(uniqueKeysWithValues: checklistItemsAll.map { ($0.id, $0) })
    }

    /// All loaded sleep sessions (ranged ∪ open), deduped — used for prior-awake lookups that may span a day boundary.
    var allSleepSessions: [SleepSession] {
        TimelineAggregator.mergeSleepSessions(ranged: sleepSessionsRanged, open: openSleepSessions)
    }

    /// All loaded pump sessions in the current window — used for the
    /// previous-pump lookup that pump production-rate display needs, which
    /// may span a day boundary.
    var allPumps: [PumpSession] {
        if let pumpImmediatelyBeforeWindow {
            return pumps + [pumpImmediatelyBeforeWindow]
        }
        return pumps
    }

    func pumpRate(for session: PumpSession) -> Double? {
        let previous = PumpRateService.previousSession(
            before: session.startTime,
            excluding: session.id,
            in: allPumps
        )
        return PumpRateService.sessionRate(
            session,
            previousSessionEndTime: PumpRateService.rateAnchorEndTime(
                for: session,
                previousPumpEndTime: previous?.endTime,
                nursingSessions: nursingSessions
            )
        )
    }

    func pumpRate(for summary: TimelinePumpSummary) -> Double? {
        guard let firstStartTime = summary.cleanSessions.map(\.startTime).min() else { return nil }
        let previous = PumpRateService.previousSession(
            before: firstStartTime,
            in: allPumps
        )
        return PumpRateService.weightedCleanRate(
            sessions: allPumps.filter { session in
                summary.cleanSessions.contains { $0.id == session.id }
                    || (session.isPostNursing
                        && session.startTime >= (summary.firstStartTime ?? .distantFuture)
                        && session.endTime <= (summary.lastEndTime ?? .distantPast))
            },
            sessionImmediatelyBeforeRange: previous
        )
    }

    func nursingEstimate(for session: NursingSession) -> NursingEstimate? {
        NursingEstimateService.estimates(
            nursingSessions: nursingSessions,
            pumpSessions: allPumps
        )[session.id]
    }

    func sections(preferences: UserPreferences, now: Date) -> [TimelineDaySection] {
        let entries = TimelineAggregator.makeEntries(
            pumps: pumps,
            bottles: bottles,
            nursingSessions: nursingSessions,
            sleepSessions: allSleepSessions,
            diaperEvents: diaperEvents,
            checklistEvents: checklistEvents,
            checklistItemsByID: checklistItemsByID,
            growthMeasurements: growthMeasurements
        )
        let filtered = TimelineAggregator.filtered(entries, by: filter)
        return TimelineAggregator.groupByDay(
            entries: filtered,
            preferences: preferences,
            activeChecklistItemCount: checklistItemsAll.filter(\.isActive).count,
            nightStartMinutes: nightStartMinutes,
            nightEndMinutes: nightEndMinutes,
            now: now
        )
    }

    // MARK: Lifecycle

    func start(access: BabyAccess, environment: AppEnvironment, preferences: UserPreferences, now: Date = .now) {
        nightStartMinutes = access.baby.nightStartMinutes
        nightEndMinutes = access.baby.nightEndMinutes
        let isNewBaby = babyID != access.baby.id
        let hasActiveSubscriptions = babyScopedTask != nil || windowedTask != nil
        guard isNewBaby || !hasActiveSubscriptions else { return }

        if isNewBaby {
            babyID = access.baby.id
            loadedWindow = TimelineAggregator.initialWindow(now: now, preferences: preferences)
        }
        resubscribeBabyScoped(babyID: access.baby.id, environment: environment)
        resubscribeWindowed(babyID: access.baby.id, environment: environment, preferences: preferences)
    }

    func stop() {
        babyScopedTask?.cancel()
        windowedTask?.cancel()
        babyScopedTask = nil
        windowedTask = nil
        isLoadingWindow = false
    }

    /// Call when the Timeline day-start preference changes. Keeps the user's
    /// current scroll depth (same number of loaded days) under the new boundary.
    func updateDayBoundaryIfNeeded(preferences: UserPreferences, environment: AppEnvironment, now: Date = .now) {
        guard let babyID else { return }
        let calendar = Calendar.autoupdatingCurrent
        let previousSpanDays = max(14, calendar.dateComponents([.day], from: loadedWindow.start, to: loadedWindow.end).day ?? 14)
        let newWindow = TimelineAggregator.initialWindow(now: now, days: previousSpanDays, preferences: preferences)
        guard newWindow != loadedWindow else { return }
        loadedWindow = newWindow
        resubscribeWindowed(babyID: babyID, environment: environment, preferences: preferences)
    }

    /// Advances the upper query boundary when the app stays open across
    /// midnight or a custom tracking-day boundary.
    func advanceToCurrentTrackingDayIfNeeded(
        preferences: UserPreferences,
        environment: AppEnvironment,
        now: Date
    ) {
        guard let babyID else { return }
        let current = TrackingDayService.interval(containing: now, surface: .timeline, preferences: preferences)
        guard current.end != loadedWindow.end else { return }
        let calendar = Calendar.autoupdatingCurrent
        let span = max(14, calendar.dateComponents([.day], from: loadedWindow.start, to: loadedWindow.end).day ?? 14)
        loadedWindow = TimelineAggregator.initialWindow(now: now, days: span, preferences: preferences)
        resubscribeWindowed(babyID: babyID, environment: environment, preferences: preferences)
    }

    func extendOlder(preferences: UserPreferences, environment: AppEnvironment) {
        guard let babyID, !isLoadingWindow else { return }
        loadedWindow = TimelineAggregator.extendedWindow(loadedWindow, olderBy: 14)
        resubscribeWindowed(babyID: babyID, environment: environment, preferences: preferences)
    }

    /// Extends the window if needed so `date` is loaded, returning the start
    /// of its effective tracking day (the section id to scroll to).
    @discardableResult
    func jumpToDate(_ date: Date, preferences: UserPreferences, environment: AppEnvironment) -> Date {
        let targetDayStart = TrackingDayService.interval(containing: date, surface: .timeline, preferences: preferences).start
        guard let babyID else { return targetDayStart }
        let newWindow = TimelineAggregator.windowIncluding(date: date, currentWindow: loadedWindow, preferences: preferences)
        if newWindow != loadedWindow {
            loadedWindow = newWindow
            resubscribeWindowed(babyID: babyID, environment: environment, preferences: preferences)
        }
        return targetDayStart
    }

    // MARK: Subscriptions

    private func resubscribeBabyScoped(babyID: String, environment: AppEnvironment) {
        babyScopedTask?.cancel()
        babyScopedTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for try await values in environment.sleepRepository.observeOpenSessions(babyID: babyID) {
                            await MainActor.run { self.openSleepSessions = values }
                        }
                    }
                    group.addTask {
                        for try await values in environment.checklistRepository.observeItems(babyID: babyID, includeInactive: true) {
                            await MainActor.run { self.checklistItemsAll = values }
                        }
                    }
                    try await group.waitForAll()
                }
            } catch is CancellationError {
            } catch {
                await MainActor.run { self.errorMessage = Self.compactErrorMessage }
            }
        }
    }

    private func resubscribeWindowed(babyID: String, environment: AppEnvironment, preferences: UserPreferences) {
        windowedTask?.cancel()
        readyWindowedStreamKeys = []
        isLoadingWindow = true
        let interval = loadedWindow
        windowedTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        let previous = try? await environment.pumpRepository.fetchSessionImmediatelyBefore(
                            babyID: babyID,
                            startTime: interval.start
                        )
                        await MainActor.run { self.pumpImmediatelyBeforeWindow = previous }
                    }
                    group.addTask {
                        for try await values in environment.pumpRepository.observe(babyID: babyID, interval: interval) {
                            await MainActor.run { self.pumps = values; self.markWindowedStreamReady("pumps") }
                        }
                    }
                    group.addTask {
                        for try await values in environment.bottleRepository.observe(babyID: babyID, interval: interval) {
                            await MainActor.run { self.bottles = values; self.markWindowedStreamReady("bottles") }
                        }
                    }
                    group.addTask {
                        for try await values in environment.nursingRepository.observe(babyID: babyID, interval: interval) {
                            await MainActor.run { self.nursingSessions = values; self.markWindowedStreamReady("nursing") }
                        }
                    }
                    group.addTask {
                        for try await values in environment.sleepRepository.observe(babyID: babyID, interval: interval) {
                            await MainActor.run { self.sleepSessionsRanged = values; self.markWindowedStreamReady("sleep") }
                        }
                    }
                    group.addTask {
                        for try await values in environment.diaperRepository.observe(babyID: babyID, interval: interval) {
                            await MainActor.run { self.diaperEvents = values; self.markWindowedStreamReady("diapers") }
                        }
                    }
                    group.addTask {
                        for try await values in environment.checklistRepository.observeEvents(babyID: babyID, interval: interval) {
                            await MainActor.run { self.checklistEvents = values; self.markWindowedStreamReady("checklistEvents") }
                        }
                    }
                    group.addTask {
                        for try await values in environment.growthRepository.observe(babyID: babyID, interval: interval) {
                            await MainActor.run { self.growthMeasurements = values; self.markWindowedStreamReady("growth") }
                        }
                    }
                    try await group.waitForAll()
                }
            } catch is CancellationError {
            } catch {
                await MainActor.run { self.errorMessage = Self.compactErrorMessage }
            }
        }
    }

    private func markWindowedStreamReady(_ key: String) {
        readyWindowedStreamKeys.insert(key)
        if readyWindowedStreamKeys.isSuperset(of: Self.windowedStreamKeys) {
            isLoadingWindow = false
        }
    }

    private static let compactErrorMessage = "Some Timeline data is unavailable. Cached entries remain visible."
}
