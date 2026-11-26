import Foundation

enum SleepClassification: Equatable, Sendable {
    case nap
    case night
}

enum SleepClassifier {
    static func classify(
        startTime: Date,
        nightStartMinutes: Int = Baby.defaultNightStartMinutes,
        nightEndMinutes: Int = Baby.defaultNightEndMinutes,
        calendar: Calendar = .autoupdatingCurrent
    ) -> SleepClassification {
        guard (0..<1_440).contains(nightStartMinutes),
              (0..<1_440).contains(nightEndMinutes)
        else {
            return .nap
        }

        let components = calendar.dateComponents([.hour, .minute, .second], from: startTime)
        let secondsAfterMidnight =
            (components.hour ?? 0) * 3_600
            + (components.minute ?? 0) * 60
            + (components.second ?? 0)
        let startSeconds = nightStartMinutes * 60
        let endSeconds = nightEndMinutes * 60

        let isNight: Bool
        if startSeconds < endSeconds {
            isNight = secondsAfterMidnight >= startSeconds && secondsAfterMidnight < endSeconds
        } else if startSeconds > endSeconds {
            isNight = secondsAfterMidnight >= startSeconds || secondsAfterMidnight < endSeconds
        } else {
            isNight = true
        }
        return isNight ? .night : .nap
    }

    /// Night when more than half of the sleep falls inside night hours.
    static func classify(
        startTime: Date,
        endTime: Date,
        nightStartMinutes: Int = Baby.defaultNightStartMinutes,
        nightEndMinutes: Int = Baby.defaultNightEndMinutes,
        calendar: Calendar = .autoupdatingCurrent
    ) -> SleepClassification {
        let total = endTime.timeIntervalSince(startTime)
        guard total > 0,
              (0..<1_440).contains(nightStartMinutes),
              (0..<1_440).contains(nightEndMinutes)
        else {
            return classify(startTime: startTime, nightStartMinutes: nightStartMinutes, nightEndMinutes: nightEndMinutes, calendar: calendar)
        }
        guard nightStartMinutes != nightEndMinutes else { return .night }
        let nightSeconds = nightOverlap(
            start: startTime,
            end: endTime,
            nightStartMinutes: nightStartMinutes,
            nightEndMinutes: nightEndMinutes,
            calendar: calendar
        )
        return nightSeconds * 2 > total ? .night : .nap
    }

    static func classify(
        _ session: SleepSession,
        now: Date = .now,
        nightStartMinutes: Int = Baby.defaultNightStartMinutes,
        nightEndMinutes: Int = Baby.defaultNightEndMinutes,
        calendar: Calendar = .autoupdatingCurrent
    ) -> SleepClassification {
        classify(
            startTime: session.startTime,
            endTime: max(session.startTime, session.endTime ?? now),
            nightStartMinutes: nightStartMinutes,
            nightEndMinutes: nightEndMinutes,
            calendar: calendar
        )
    }

    private static func nightOverlap(
        start: Date,
        end: Date,
        nightStartMinutes: Int,
        nightEndMinutes: Int,
        calendar: Calendar
    ) -> TimeInterval {
        let wraps = nightStartMinutes > nightEndMinutes
        guard var day = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: start)) else { return 0 }
        let lastDay = calendar.startOfDay(for: end)
        var overlap: TimeInterval = 0
        while day <= lastDay {
            if let windowStart = date(on: day, minutes: nightStartMinutes, calendar: calendar),
               let endDay = wraps ? calendar.date(byAdding: .day, value: 1, to: day) : day,
               let windowEnd = date(on: endDay, minutes: nightEndMinutes, calendar: calendar) {
                let lower = max(start, windowStart)
                let upper = min(end, windowEnd)
                if upper > lower { overlap += upper.timeIntervalSince(lower) }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return overlap
    }

    private static func date(on day: Date, minutes: Int, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day)
    }
}
