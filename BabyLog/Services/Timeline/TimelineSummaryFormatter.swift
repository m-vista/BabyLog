import Foundation

/// Builds the per-day summary card text (design section 38) from
/// `TimelineDaySummary`'s raw numeric aggregates. Kept separate from
/// `TimelineAggregator` so semantic aggregation and display text stay
/// independently testable.
enum TimelineSummaryFormatter {
    static func volumeText(_ milliliters: Double, unit: VolumeUnit) -> String {
        "\(VolumeService.displayString(milliliters: milliliters, unit: unit)) \(unit.rawValue)"
    }

    static func feedLine(_ summary: TimelineFeedSummary, unit: VolumeUnit) -> String {
        guard summary.bottleCount + summary.nursingCount > 0 else { return "No feed logged" }
        var parts: [String] = []
        if summary.bottleCount > 0 {
            parts.append("\(summary.bottleCount)× Bottle \(volumeText(summary.bottleTotalMl, unit: unit))")
        }
        if summary.nursingCount > 0 {
            parts.append("\(summary.nursingCount)× Nursing \(HomeSummaryService.duration(summary.nursingTotalSeconds))")
        }
        return parts.joined(separator: " · ")
    }

    /// `rate` is precomputed by the caller (raw mL/hr, via `PumpRateService`)
    /// since it depends on a session outside this summary's own group.
    static func pumpLine(_ summary: TimelinePumpSummary, unit: VolumeUnit, showRate: Bool, rate: Double?) -> String {
        guard summary.count > 0 else { return "No pumps logged" }
        var parts = ["\(summary.count)×", volumeText(summary.totalMl, unit: unit)]
        if let left = summary.leftMl, let right = summary.rightMl {
            parts.append("L \(volumeText(left, unit: unit)) R \(volumeText(right, unit: unit))")
        }
        if showRate {
            if let rate {
                parts.append("\(volumeText(rate, unit: unit))/hr")
            } else {
                parts.append("– \(unit.rawValue)/hr")
            }
        }
        return parts.joined(separator: " · ")
    }

    static func diaperLine(_ summary: TimelineDiaperSummary) -> String {
        guard summary.count > 0 else { return "No diapers logged" }
        return "\(summary.count)× · Wet \(summary.wetCount) · Dirty \(summary.dirtyCount)"
    }

    static func sleepLine(_ summary: TimelineSleepSummary) -> String {
        guard summary.totalSeconds > 0 else { return "No sleep logged" }
        let napLabel = summary.napCount == 1 ? "1 nap" : "\(summary.napCount) naps"
        return "\(HomeSummaryService.duration(summary.totalSeconds)) · \(napLabel) \(HomeSummaryService.duration(summary.napTotalSeconds)) · Night \(HomeSummaryService.duration(summary.nightTotalSeconds))"
    }

    static func otherLine(_ summary: TimelineOtherSummary) -> String {
        let base = "\(summary.completedCount) of \(summary.totalItemCount)"
        guard !summary.completedTitlesInOrder.isEmpty else { return base }
        return "\(base) · \(summary.completedTitlesInOrder.joined(separator: " · "))"
    }

    // MARK: Date tile (left side of the day card)

    static func weekdayAbbreviation(for date: Date, calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEE")
        return formatter.string(from: date).uppercased()
    }

    static func dayNumber(for date: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        "\(calendar.component(.day, from: date))"
    }

    static func monthAbbreviation(for date: Date, calendar: Calendar = .autoupdatingCurrent, locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }

    /// e.g. "5:00 AM" / "05:00", respecting the system 12h/24h setting.
    static func dayStartTimeText(
        dayStartMinutes: Int,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        var components = DateComponents()
        components.year = 2_000
        components.month = 1
        components.day = 1
        components.hour = dayStartMinutes / 60
        components.minute = dayStartMinutes % 60
        let date = calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
        return AppFormatters.time(locale: locale, timeZone: timeZone).string(from: date)
    }
}
