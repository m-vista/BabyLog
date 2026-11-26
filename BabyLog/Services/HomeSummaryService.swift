import Foundation

enum HomeSummaryService {
    static func duration(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int(seconds) / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)m" }
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    static func eventTime(_ date: Date, showRelative: Bool, now: Date = .now) -> String {
        showRelative ? RelativeTimeService.string(for: date, relativeTo: now) : AppFormatters.time().string(from: date)
    }

    static func bottleDescription(_ feed: BottleFeed, unit: VolumeUnit) -> String {
        let suffix = unit.rawValue
        func amount(_ ml: Double) -> String { "\(VolumeService.displayString(milliliters: ml, unit: unit)) \(suffix)" }
        if feed.unspecifiedAmountMl > 0, feed.breastMilkAmountMl == 0, feed.formulaAmountMl == 0 { return "Bottle \(amount(feed.unspecifiedAmountMl))" }
        if feed.breastMilkAmountMl > 0, feed.formulaAmountMl > 0 { return "BM \(amount(feed.breastMilkAmountMl)) & F \(amount(feed.formulaAmountMl))" }
        if feed.breastMilkAmountMl > 0 { return "Breast milk \(amount(feed.breastMilkAmountMl))" }
        if feed.formulaAmountMl > 0 { return "Formula \(amount(feed.formulaAmountMl))" }
        return "Bottle \(amount(feed.totalAmountMl))"
    }

    static func diaperCounts(_ events: [DiaperEvent]) -> (wet: Int, dirty: Int) {
        events.reduce(into: (0, 0)) { result, event in
            result.0 += event.type.wetCount
            result.1 += event.type.dirtyCount
        }
    }

    static func sleepDailySummary(
        _ sessions: [SleepSession],
        nightStartMinutes: Int,
        nightEndMinutes: Int
    ) -> String {
        var napCount = 0
        var napDuration: TimeInterval = 0
        var nightDuration: TimeInterval = 0

        for session in sessions where session.endTime != nil {
            let sessionDuration = SleepCalculator.duration(of: session)
            switch SleepClassifier.classify(
                session,
                nightStartMinutes: nightStartMinutes,
                nightEndMinutes: nightEndMinutes
            ) {
            case .nap:
                napCount += 1
                napDuration += sessionDuration
            case .night:
                nightDuration += sessionDuration
            }
        }

        let napLabel = napCount == 1 ? "1 nap" : "\(napCount) naps"
        return "\(napLabel) · \(duration(napDuration)) · Night \(duration(nightDuration))"
    }

    /// e.g. "3 months 20 days old (16 weeks)".
    static func ageText(birthDate: Date, now: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        func plural(_ value: Int, _ unit: String) -> String { "\(value) \(unit)\(value == 1 ? "" : "s")" }
        let birthDay = calendar.startOfDay(for: birthDate)
        let currentDay = calendar.startOfDay(for: now)
        let components = calendar.dateComponents([.year, .month, .day], from: birthDay, to: currentDay)
        if let years = components.year, years > 0 {
            let months = max(0, components.month ?? 0)
            return "\(plural(years, "year")) old (\(plural(months, "month")))"
        }
        let months = max(0, components.month ?? 0)
        let days = max(0, components.day ?? 0)
        let totalDays = max(0, calendar.dateComponents([.day], from: birthDay, to: currentDay).day ?? 0)
        let weekText = plural(totalDays / 7, "week")
        if months == 0 { return "\(plural(days, "day")) old (\(weekText))" }
        let monthText = days == 0 ? plural(months, "month") : "\(plural(months, "month")) \(plural(days, "day"))"
        return "\(monthText) old (\(weekText))"
    }

    static func latestByStart<T>(_ values: [T], date: (T) -> Date) -> T? { values.max { date($0) < date($1) } }
}
