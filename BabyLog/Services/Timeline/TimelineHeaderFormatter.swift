import Foundation

/// Text for the Timeline header's relative label and full date (design
/// section 35). `dayStart` and `today` must both be tracking-day-aligned
/// `Date`s (e.g. `TimelineDaySection.id` / the current day's interval start)
/// so the day-count difference is exact regardless of a custom day start.
enum TimelineHeaderFormatter {
    static func relativeDayLabel(for dayStart: Date, today: Date, calendar: Calendar = .autoupdatingCurrent) -> String {
        let daysAgo = calendar.dateComponents([.day], from: dayStart, to: today).day ?? 0
        switch daysAgo {
        case ..<1: return "Today"
        case 1: return "Yesterday"
        default: return "\(daysAgo) days ago"
        }
    }

    static func fullDateText(for date: Date, locale: Locale = .autoupdatingCurrent, timeZone: TimeZone = .autoupdatingCurrent) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMd")
        return formatter.string(from: date)
    }
}
