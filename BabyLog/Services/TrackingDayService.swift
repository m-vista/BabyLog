import Foundation

enum TrackingSurface: Sendable {
    case home
    case timeline
    case calendar
    case analytics
}

enum TrackingDayService {
    static func interval(
        containing date: Date,
        dayStartMinutes: Int = 0,
        useCustomDay: Bool = true,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        let effectiveMinutes = useCustomDay && (0..<1_440).contains(dayStartMinutes)
            ? dayStartMinutes
            : 0
        let hour = effectiveMinutes / 60
        let minute = effectiveMinutes % 60

        var components = calendar.dateComponents([.era, .year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.nanosecond = 0

        var start = calendar.date(from: components) ?? calendar.startOfDay(for: date)
        if date < start {
            start = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        }
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }

    static func interval(
        containing date: Date,
        surface: TrackingSurface,
        preferences: UserPreferences,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        let usesCustomDay: Bool
        switch surface {
        case .home:
            usesCustomDay = true
        case .timeline:
            usesCustomDay = preferences.useCustomDayInTimeline
        case .calendar:
            usesCustomDay = preferences.useCustomDayInCalendar
        case .analytics:
            usesCustomDay = preferences.useCustomDayInAnalytics
        }

        return interval(
            containing: date,
            dayStartMinutes: preferences.dayStartMinutes,
            useCustomDay: usesCustomDay,
            calendar: calendar
        )
    }
}
