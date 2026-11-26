import Foundation

enum AnalyticsService {
    static func interval(
        range: AnalyticsRange,
        now: Date,
        preferences: UserPreferences,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        let today = TrackingDayService.interval(
            containing: now,
            surface: .analytics,
            preferences: preferences,
            calendar: calendar
        )
        let start = calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: today.start) ?? today.start
        return DateInterval(start: start, end: today.end)
    }

    static func calculate(_ input: AnalyticsInput, calendar: Calendar = .autoupdatingCurrent) -> AnalyticsSnapshot {
        let window = interval(range: input.range, now: input.now, preferences: input.preferences, calendar: calendar)
        let dayStarts = days(in: window, calendar: calendar)
        let pumps = input.pumps.filter { window.contains($0.startTime) }
        let bottles = input.bottles.filter { window.contains($0.startTime) }
        let nursing = input.nursing.filter { window.contains($0.startTime) }
        let sleep = input.sleep.filter { $0.startTime < window.end && ($0.endTime ?? input.now) > window.start }
        let diapers = input.diapers.filter { window.contains($0.startTime) }
        let events = input.checklistEvents.filter { window.contains($0.timestamp) }

        return AnalyticsSnapshot(
            interval: window,
            dayCount: dayStarts.count,
            feed: feed(bottles: bottles, nursing: nursing, days: dayStarts, preferences: input.preferences, calendar: calendar),
            sleep: sleepMetrics(sleep, window: window, now: input.now, baby: input.baby, days: dayStarts, preferences: input.preferences, calendar: calendar),
            diaper: diaperMetrics(diapers, days: dayStarts, preferences: input.preferences, calendar: calendar),
            pump: pumpMetrics(pumps, previous: input.pumpImmediatelyBeforeRange, days: dayStarts, preferences: input.preferences, calendar: calendar),
            other: otherMetrics(events, items: input.checklistItems.filter(\.isActive), days: dayStarts, preferences: input.preferences, calendar: calendar)
        )
    }

    private static func feed(bottles: [BottleFeed], nursing: [NursingSession], days: [Date], preferences: UserPreferences, calendar: Calendar) -> FeedAnalytics {
        var result = FeedAnalytics()
        result.bottleCount = bottles.count
        result.nursingCount = nursing.count
        result.bottleAmountMl = bottles.reduce(0) { $0 + $1.totalAmountMl }
        result.breastMilkMl = bottles.reduce(0) { $0 + $1.breastMilkAmountMl }
        result.formulaMl = bottles.reduce(0) { $0 + $1.formulaAmountMl }
        result.unspecifiedMl = bottles.reduce(0) { $0 + $1.unspecifiedAmountMl }
        result.nursingSeconds = nursing.reduce(0) { $0 + $1.totalDurationSeconds }
        let times = (bottles.map(\.startTime) + nursing.map(\.startTime)).sorted()
        result.longestGapSeconds = zip(times, times.dropFirst()).map { $1.timeIntervalSince($0) }.max() ?? 0
        result.dailyBottleMl = points(days: days, preferences: preferences, calendar: calendar) { interval in
            bottles.filter { interval.contains($0.startTime) }.reduce(0) { $0 + $1.totalAmountMl }
        }
        return result
    }

    private static func sleepMetrics(_ sessions: [SleepSession], window: DateInterval, now: Date, baby: Baby, days: [Date], preferences: UserPreferences, calendar: Calendar) -> SleepAnalytics {
        var result = SleepAnalytics()
        let pieces = sessions.compactMap { session -> (SleepSession, TimeInterval)? in
            let end = min(session.endTime ?? now, window.end)
            let start = max(session.startTime, window.start)
            guard end > start else { return nil }
            return (session, end.timeIntervalSince(start))
        }
        for (session, duration) in pieces {
            result.totalSeconds += duration
            result.longestStretchSeconds = max(result.longestStretchSeconds, duration)
            if SleepClassifier.classify(session, now: now, nightStartMinutes: baby.nightStartMinutes, nightEndMinutes: baby.nightEndMinutes, calendar: calendar) == .night {
                result.nightSeconds += duration
            } else {
                result.napSeconds += duration
                result.napCount += 1
            }
        }
        let sorted = sessions.sorted { $0.startTime < $1.startTime }
        let awake = zip(sorted, sorted.dropFirst()).compactMap { lhs, rhs -> TimeInterval? in
            guard let end = lhs.endTime, rhs.startTime > end else { return nil }
            return rhs.startTime.timeIntervalSince(end)
        }
        result.averageAwakeSeconds = awake.isEmpty ? 0 : awake.reduce(0, +) / Double(awake.count)
        result.dailySeconds = points(days: days, preferences: preferences, calendar: calendar) { interval in
            sessions.reduce(0) { sum, session in
                let end = min(session.endTime ?? now, interval.end)
                let start = max(session.startTime, interval.start)
                return sum + max(0, end.timeIntervalSince(start))
            }
        }
        return result
    }

    private static func diaperMetrics(_ events: [DiaperEvent], days: [Date], preferences: UserPreferences, calendar: Calendar) -> DiaperAnalytics {
        var result = DiaperAnalytics()
        result.changes = events.count
        result.wet = events.reduce(0) { $0 + $1.type.wetCount }
        result.dirty = events.reduce(0) { $0 + $1.type.dirtyCount }
        result.both = events.filter { $0.type == .both }.count
        result.latestChange = events.map(\.startTime).max()
        result.fullness = Dictionary(grouping: events.compactMap(\.fullness), by: { $0 }).mapValues(\.count)
        let sizes = Dictionary(grouping: events.compactMap(\.size), by: { $0 }).mapValues(\.count)
        result.mostUsedSize = sizes.max { lhs, rhs in lhs.value < rhs.value }?.key
        result.dailyChanges = points(days: days, preferences: preferences, calendar: calendar) { interval in
            Double(events.filter { interval.contains($0.startTime) }.count)
        }
        return result
    }

    private static func pumpMetrics(_ sessions: [PumpSession], previous: PumpSession?, days: [Date], preferences: UserPreferences, calendar: Calendar) -> PumpAnalytics {
        var result = PumpAnalytics()
        result.totalMl = sessions.reduce(0) { $0 + $1.totalAmountMl }
        let clean = preferences.separatePostNursingPumps ? sessions.filter { !$0.isPostNursing } : sessions
        result.cleanMl = clean.reduce(0) { $0 + $1.totalAmountMl }
        result.sessionCount = sessions.count
        result.cleanCount = clean.count
        result.postNursingCount = sessions.filter(\.isPostNursing).count
        result.totalSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        result.leftMl = sessions.compactMap(\.leftAmountMl).reduce(0, +)
        result.rightMl = sessions.compactMap(\.rightAmountMl).reduce(0, +)
        result.cleanRateMlPerHour = PumpRateService.weightedCleanRate(
            sessions: sessions,
            sessionImmediatelyBeforeRange: previous
        )
        result.dailyMl = points(days: days, preferences: preferences, calendar: calendar) { interval in
            sessions.filter { interval.contains($0.startTime) }.reduce(0) { $0 + $1.totalAmountMl }
        }
        return result
    }

    private static func otherMetrics(_ events: [ChecklistEvent], items: [ChecklistItem], days: [Date], preferences: UserPreferences, calendar: Calendar) -> OtherAnalytics {
        var result = OtherAnalytics()
        result.completedCount = events.count
        result.possibleCount = items.count * days.count
        result.dailyCompletion = points(days: days, preferences: preferences, calendar: calendar) { interval in
            guard !items.isEmpty else { return 0 }
            let completed = Set(events.filter { interval.contains($0.timestamp) }.map(\.checklistItemID)).count
            return Double(completed) / Double(items.count)
        }
        result.items = items.map { item in
            let completedDays = days.filter { start in
                let interval = dayInterval(start: start, preferences: preferences, calendar: calendar)
                return events.contains { $0.checklistItemID == item.id && interval.contains($0.timestamp) }
            }.count
            return ChecklistItemAnalytics(id: item.id, title: item.title, completedDays: completedDays, possibleDays: days.count)
        }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        return result
    }

    private static func days(in interval: DateInterval, calendar: Calendar) -> [Date] {
        var values: [Date] = []; var cursor = interval.start
        while cursor < interval.end { values.append(cursor); cursor = calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end }
        return values
    }

    private static func points(days: [Date], preferences: UserPreferences, calendar: Calendar, value: (DateInterval) -> Double) -> [AnalyticsPoint] {
        days.map { AnalyticsPoint(id: $0, value: value(dayInterval(start: $0, preferences: preferences, calendar: calendar))) }
    }

    private static func dayInterval(start: Date, preferences: UserPreferences, calendar: Calendar) -> DateInterval {
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }
}
