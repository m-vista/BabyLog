import Foundation

/// Deterministic, Firestore-agnostic Timeline aggregation (Phase 15). Pure
/// functions only — no SwiftUI, no snapshot types — so results depend only
/// on their inputs and are easy to unit test.
enum TimelineAggregator {

    // MARK: Entry construction

    static func makeEntries(
        pumps: [PumpSession],
        bottles: [BottleFeed],
        nursingSessions: [NursingSession],
        sleepSessions: [SleepSession],
        diaperEvents: [DiaperEvent],
        checklistEvents: [ChecklistEvent],
        checklistItemsByID: [String: ChecklistItem],
        growthMeasurements: [GrowthMeasurement] = []
    ) -> [TimelineEntry] {
        var entries: [TimelineEntry] = []
        entries.reserveCapacity(
            pumps.count + bottles.count + nursingSessions.count
                + sleepSessions.count + diaperEvents.count + checklistEvents.count
                + growthMeasurements.count
        )
        entries.append(contentsOf: pumps.map { TimelineEntry(kind: .pump($0)) })
        entries.append(contentsOf: bottles.map { TimelineEntry(kind: .bottle($0)) })
        entries.append(contentsOf: nursingSessions.map { TimelineEntry(kind: .nursing($0)) })
        entries.append(contentsOf: sleepSessions.map { TimelineEntry(kind: .sleep($0)) })
        entries.append(contentsOf: diaperEvents.map { TimelineEntry(kind: .diaper($0)) })
        entries.append(contentsOf: checklistEvents.map {
            TimelineEntry(kind: .checklist($0, item: checklistItemsByID[$0.checklistItemID]))
        })
        entries.append(contentsOf: growthMeasurements.map { TimelineEntry(kind: .growth($0)) })
        return sortedNewestFirst(entries)
    }

    /// Newest first; ties break on `id` ascending so order never depends on
    /// input/insertion order (required determinism for identical timestamps).
    static func sortedNewestFirst(_ entries: [TimelineEntry]) -> [TimelineEntry] {
        entries.sorted { lhs, rhs in
            if lhs.date != rhs.date { return lhs.date > rhs.date }
            return lhs.id < rhs.id
        }
    }

    /// An open session may have started before the loaded window; merge it
    /// in regardless so it is never missing from Timeline (D5). Firestore
    /// doesn't need a second index for this since `observeOpenSessions` is
    /// already a small, bounded listener (filtered to `endTime == null`).
    static func mergeSleepSessions(ranged: [SleepSession], open: [SleepSession]) -> [SleepSession] {
        var byID: [String: SleepSession] = [:]
        for session in ranged { byID[session.id] = session }
        for session in open { byID[session.id] = session }
        return Array(byID.values)
    }

    // MARK: Filtering

    /// Filters already-loaded unified results in memory. Never issues a new
    /// query — filtering must not require fetching more historical data.
    static func filtered(_ entries: [TimelineEntry], by filter: TimelineFilter) -> [TimelineEntry] {
        let categories = filter.selectedCategories
        return entries.filter { categories.contains($0.category) }
    }

    // MARK: Grouping

    /// Groups entries into continuous day sections using the Timeline
    /// tracking-day boundary (midnight by default, custom when enabled).
    static func groupByDay(
        entries: [TimelineEntry],
        preferences: UserPreferences,
        activeChecklistItemCount: Int,
        nightStartMinutes: Int = Baby.defaultNightStartMinutes,
        nightEndMinutes: Int = Baby.defaultNightEndMinutes,
        calendar: Calendar = .autoupdatingCurrent,
        now: Date = .now
    ) -> [TimelineDaySection] {
        guard !entries.isEmpty else { return [] }

        var buckets: [Date: [TimelineEntry]] = [:]
        var intervalsByKey: [Date: DateInterval] = [:]
        for entry in entries {
            let interval = TrackingDayService.interval(
                containing: entry.date,
                surface: .timeline,
                preferences: preferences,
                calendar: calendar
            )
            buckets[interval.start, default: []].append(entry)
            intervalsByKey[interval.start] = interval
        }

        let usesCustomDayStart = preferences.useCustomDayInTimeline && preferences.dayStartMinutes != 0
        return buckets.keys.sorted(by: >).map { key in
            let dayEntries = sortedNewestFirst(buckets[key] ?? [])
            let summary = daySummary(
                for: dayEntries,
                activeChecklistItemCount: activeChecklistItemCount,
                nightStartMinutes: nightStartMinutes,
                nightEndMinutes: nightEndMinutes,
                now: now
            )
            return TimelineDaySection(
                id: key,
                interval: intervalsByKey[key] ?? DateInterval(start: key, end: key),
                dayStartMinutes: preferences.dayStartMinutes,
                usesCustomDayStart: usesCustomDayStart,
                entries: dayEntries,
                summary: summary
            )
        }
    }

    // MARK: Per-day summary

    static func daySummary(
        for entries: [TimelineEntry],
        activeChecklistItemCount: Int,
        nightStartMinutes: Int = Baby.defaultNightStartMinutes,
        nightEndMinutes: Int = Baby.defaultNightEndMinutes,
        now: Date = .now
    ) -> TimelineDaySummary {
        var summary = TimelineDaySummary()
        var earliestByItem: [String: (timestamp: Date, title: String)] = [:]

        for entry in entries {
            switch entry.kind {
            case .pump(let session):
                summary.pump.count += 1
                summary.pump.totalMl += session.totalAmountMl
                if let left = session.leftAmountMl, let right = session.rightAmountMl {
                    summary.pump.leftMl = (summary.pump.leftMl ?? 0) + left
                    summary.pump.rightMl = (summary.pump.rightMl ?? 0) + right
                }
                if summary.pump.firstStartTime.map({ session.startTime < $0 }) ?? true {
                    summary.pump.firstStartTime = session.startTime
                }
                if summary.pump.lastEndTime.map({ session.endTime > $0 }) ?? true {
                    summary.pump.lastEndTime = session.endTime
                }
                if !session.isPostNursing {
                    summary.pump.cleanSessions.append(session)
                }

            case .bottle(let feed):
                summary.feed.count += 1
                summary.feed.bottleCount += 1
                summary.feed.bottleTotalMl += feed.totalAmountMl

            case .nursing(let session):
                summary.feed.count += 1
                summary.feed.nursingCount += 1
                summary.feed.nursingTotalSeconds += session.totalDurationSeconds

            case .sleep(let session):
                let duration = SleepCalculator.duration(of: session, now: now)
                summary.sleep.totalSeconds += duration
                switch SleepClassifier.classify(
                    session,
                    now: now,
                    nightStartMinutes: nightStartMinutes,
                    nightEndMinutes: nightEndMinutes
                ) {
                case .nap:
                    summary.sleep.napCount += 1
                    summary.sleep.napTotalSeconds += duration
                case .night:
                    summary.sleep.nightTotalSeconds += duration
                }

            case .diaper(let event):
                summary.diaper.count += 1
                summary.diaper.wetCount += event.type.wetCount
                summary.diaper.dirtyCount += event.type.dirtyCount

            case .checklist(let event, let item):
                let title = item?.title ?? event.checklistItemID
                if let existing = earliestByItem[event.checklistItemID] {
                    if event.timestamp < existing.timestamp {
                        earliestByItem[event.checklistItemID] = (event.timestamp, title)
                    }
                } else {
                    earliestByItem[event.checklistItemID] = (event.timestamp, title)
                }
            case .growth:
                break
            }
        }

        summary.other.totalItemCount = activeChecklistItemCount
        summary.other.completedCount = earliestByItem.count
        summary.other.completedTitlesInOrder = earliestByItem.values
            .sorted { $0.timestamp < $1.timestamp }
            .map(\.title)

        return summary
    }

    // MARK: Sleep row support

    /// The awake interval immediately before `session`, computed against the
    /// full loaded sleep history (which may span more than one day section).
    static func priorAwakeDuration(before session: SleepSession, allSleepSessions: [SleepSession]) -> TimeInterval? {
        let previousCompleted = allSleepSessions
            .filter { $0.id != session.id && $0.endTime != nil && ($0.endTime ?? .distantPast) <= session.startTime }
            .max { ($0.endTime ?? .distantPast) < ($1.endTime ?? .distantPast) }
        return SleepCalculator.awakeWindowBefore(session: session, previousCompleted: previousCompleted)
    }

    // MARK: Windowed loading (D10 — never an unbounded listener)

    /// The initial Timeline window: `days` continuous tracking days ending
    /// with (and including) today.
    static func initialWindow(
        now: Date = .now,
        days: Int = 14,
        preferences: UserPreferences,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        let today = TrackingDayService.interval(containing: now, surface: .timeline, preferences: preferences, calendar: calendar)
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: today.start) ?? today.start
        return DateInterval(start: start, end: today.end)
    }

    /// Extends the window further into the past by `days` more days, keeping
    /// the same upper bound. Re-subscribing with this interval naturally
    /// avoids duplicates since callers replace (not append) cached arrays.
    static func extendedWindow(
        _ window: DateInterval,
        olderBy days: Int = 14,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        let newStart = calendar.date(byAdding: .day, value: -days, to: window.start) ?? window.start
        return DateInterval(start: newStart, end: window.end)
    }

    /// The window needed so that jumping to `date` lands inside loaded data,
    /// with a small buffer before it so continuous scroll keeps working.
    /// Returns the existing window unchanged if `date` is already covered.
    static func windowIncluding(
        date: Date,
        currentWindow: DateInterval,
        preferences: UserPreferences,
        bufferDays: Int = 7,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        guard date < currentWindow.start else { return currentWindow }
        let targetDayStart = TrackingDayService.interval(
            containing: date,
            surface: .timeline,
            preferences: preferences,
            calendar: calendar
        ).start
        let buffered = calendar.date(byAdding: .day, value: -bufferDays, to: targetDayStart) ?? targetDayStart
        return DateInterval(start: min(buffered, currentWindow.start), end: currentWindow.end)
    }
}
