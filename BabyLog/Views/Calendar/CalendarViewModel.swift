import Foundation

@MainActor
@Observable
final class CalendarViewModel {
    var range: CalendarRange = .seven
    var filter: CalendarFilter = .all
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private var pumps: [PumpSession] = []
    private var bottles: [BottleFeed] = []
    private var nursing: [NursingSession] = []
    private var rangedSleep: [SleepSession] = []
    private var openSleep: [SleepSession] = []
    private var precedingSleep: SleepSession?
    private var diapers: [DiaperEvent] = []
    private var checklistEvents: [ChecklistEvent] = []
    private var checklistItems: [ChecklistItem] = []
    private var growthMeasurements: [GrowthMeasurement] = []

    @ObservationIgnored private var subscriptionTask: Task<Void, Never>?
    @ObservationIgnored private var expectedSources: Set<CalendarDataSource> = []
    @ObservationIgnored private var readySources: Set<CalendarDataSource> = []
    @ObservationIgnored private var historyInterval: DateInterval?
    @ObservationIgnored private var earliestHistoryStart: Date?

    func start(
        access: BabyAccess,
        environment: AppEnvironment,
        preferences: UserPreferences,
        now: Date = .now
    ) {
        subscriptionTask?.cancel()
        clearData()
        errorMessage = nil
        expectedSources = CalendarSubscriptionPlan.sources(for: filter)
        readySources = []
        isLoading = !expectedSources.isEmpty
        guard !expectedSources.isEmpty else { return }

        let babyID = access.baby.id
        let interval = CalendarGeometryService.initialHistoryInterval(
            range: range,
            earliestDate: access.baby.birthDate,
            now: now,
            preferences: preferences
        )
        historyInterval = interval
        earliestHistoryStart = TrackingDayService.interval(
            containing: access.baby.birthDate,
            surface: .calendar,
            preferences: preferences
        ).start
        subscribe(babyID: babyID, environment: environment, interval: interval, sources: expectedSources)
    }

    func stop() {
        subscriptionTask?.cancel()
        subscriptionTask = nil
        isLoading = false
    }

    func extendOlderIfNeeded(
        visibleStartDate: Date,
        access: BabyAccess,
        environment: AppEnvironment,
        preferences: UserPreferences
    ) {
        guard !isLoading,
              let current = historyInterval,
              let earliestHistoryStart,
              visibleStartDate <= current.start,
              current.start > earliestHistoryStart else {
            return
        }
        let extended = CalendarGeometryService.extendingHistoryInterval(
            current,
            range: range,
            earliestStart: earliestHistoryStart
        )
        guard extended != current else { return }
        historyInterval = extended
        subscribe(
            babyID: access.baby.id,
            environment: environment,
            interval: extended,
            sources: expectedSources
        )
    }

    private func subscribe(
        babyID: String,
        environment: AppEnvironment,
        interval: DateInterval,
        sources: Set<CalendarDataSource>
    ) {
        subscriptionTask?.cancel()
        readySources = []
        isLoading = !sources.isEmpty
        guard !sources.isEmpty else { return }
        subscriptionTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    if sources.contains(.pumps) { group.addTask {
                        for try await value in environment.pumpRepository.observe(babyID: babyID, interval: interval) {
                            await self.receive(value, source: .pumps)
                        }
                    }}
                    if sources.contains(.bottles) { group.addTask {
                        for try await value in environment.bottleRepository.observe(babyID: babyID, interval: interval) {
                            await self.receive(value, source: .bottles)
                        }
                    }}
                    if sources.contains(.nursing) { group.addTask {
                        for try await value in environment.nursingRepository.observe(babyID: babyID, interval: interval) {
                            await self.receive(value, source: .nursing)
                        }
                    }}
                    if sources.contains(.diapers) { group.addTask {
                        for try await value in environment.diaperRepository.observe(babyID: babyID, interval: interval) {
                            await self.receive(value, source: .diapers)
                        }
                    }}
                    if sources.contains(.checklistEvents) { group.addTask {
                        for try await value in environment.checklistRepository.observeEvents(babyID: babyID, interval: interval) {
                            await self.receive(value, source: .checklistEvents)
                        }
                    }}
                    if sources.contains(.checklistItems) { group.addTask {
                        for try await value in environment.checklistRepository.observeItems(babyID: babyID, includeInactive: true) {
                            await self.receive(value, source: .checklistItems)
                        }
                    }}
                    if sources.contains(.growth) { group.addTask {
                        for try await value in environment.growthRepository.observe(babyID: babyID, interval: interval) {
                            await self.receive(value, source: .growth)
                        }
                    }}
                    if sources.contains(.sleep) {
                        group.addTask {
                            let value = try await environment.sleepRepository.fetchSessionImmediatelyBefore(
                                babyID: babyID,
                                startTime: interval.start
                            )
                            await self.receivePrecedingSleep(value)
                        }
                        group.addTask {
                            for try await value in environment.sleepRepository.observe(babyID: babyID, interval: interval) {
                                await self.receiveRangedSleep(value)
                            }
                        }
                        group.addTask {
                            for try await value in environment.sleepRepository.observeOpenSessions(babyID: babyID) {
                                await self.receiveOpenSleep(value)
                            }
                        }
                    }
                    try await group.waitForAll()
                }
            } catch is CancellationError {
            } catch {
                await self.fail()
            }
        }
    }

    func layout(preferences: UserPreferences, now: Date) -> CalendarLayout {
        guard let historyInterval else {
            return CalendarGeometryService.makeLayout(entries: [], range: range, filter: filter, preferences: preferences, now: now)
        }
        return CalendarGeometryService.makeLayout(
            entries: TimelineAggregator.makeEntries(
                pumps: pumps,
                bottles: bottles,
                nursingSessions: nursing,
                sleepSessions: mergedSleep,
                diaperEvents: diapers,
                checklistEvents: checklistEvents,
                checklistItemsByID: Dictionary(uniqueKeysWithValues: checklistItems.map { ($0.id, $0) }),
                growthMeasurements: growthMeasurements
            ),
            interval: historyInterval,
            filter: filter,
            preferences: preferences,
            now: now
        )
    }

    private var mergedSleep: [SleepSession] {
        var values = TimelineAggregator.mergeSleepSessions(ranged: rangedSleep, open: openSleep)
        if let precedingSleep {
            values = TimelineAggregator.mergeSleepSessions(ranged: values, open: [precedingSleep])
        }
        return values
    }

    private func clearData() {
        pumps = []; bottles = []; nursing = []; rangedSleep = []; openSleep = []
        precedingSleep = nil; diapers = []; checklistEvents = []; checklistItems = []
        growthMeasurements = []
    }

    private func markReady(_ source: CalendarDataSource) {
        readySources.insert(source)
        isLoading = !readySources.isSuperset(of: expectedSources)
    }
    private func receive(_ value: [PumpSession], source: CalendarDataSource) { pumps = value; markReady(source) }
    private func receive(_ value: [BottleFeed], source: CalendarDataSource) { bottles = value; markReady(source) }
    private func receive(_ value: [NursingSession], source: CalendarDataSource) { nursing = value; markReady(source) }
    private func receive(_ value: [DiaperEvent], source: CalendarDataSource) { diapers = value; markReady(source) }
    private func receive(_ value: [ChecklistEvent], source: CalendarDataSource) { checklistEvents = value; markReady(source) }
    private func receive(_ value: [ChecklistItem], source: CalendarDataSource) { checklistItems = value; markReady(source) }
    private func receive(_ value: [GrowthMeasurement], source: CalendarDataSource) { growthMeasurements = value; markReady(source) }
    private func receiveRangedSleep(_ value: [SleepSession]) { rangedSleep = value; markReady(.sleep) }
    private func receiveOpenSleep(_ value: [SleepSession]) { openSleep = value }
    private func receivePrecedingSleep(_ value: SleepSession?) { precedingSleep = value }
    private func fail() { errorMessage = "Calendar couldn’t refresh. Check your connection and try again."; isLoading = false }
}
