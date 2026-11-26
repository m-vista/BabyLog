import Foundation

enum CalendarGeometryService {
    static func visibleInterval(
        range: CalendarRange,
        now: Date,
        preferences: UserPreferences,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        let today = TrackingDayService.interval(
            containing: now,
            surface: .calendar,
            preferences: preferences,
            calendar: calendar
        )
        let start = calendar.date(byAdding: .day, value: -(range.rawValue - 1), to: today.start) ?? today.start
        return DateInterval(start: start, end: today.end)
    }

    /// Keeps the current range plus one preceding page in memory. Older pages
    /// are fetched only after the user scrolls to the oldest loaded page.
    static func initialHistoryInterval(
        range: CalendarRange,
        earliestDate: Date,
        now: Date,
        preferences: UserPreferences,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        let visible = visibleInterval(range: range, now: now, preferences: preferences, calendar: calendar)
        let earliest = TrackingDayService.interval(
            containing: earliestDate,
            surface: .calendar,
            preferences: preferences,
            calendar: calendar
        ).start
        let bufferedStart = calendar.date(byAdding: .day, value: -range.rawValue, to: visible.start) ?? visible.start
        return DateInterval(start: max(earliest, bufferedStart), end: visible.end)
    }

    static func extendingHistoryInterval(
        _ interval: DateInterval,
        range: CalendarRange,
        earliestStart: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> DateInterval {
        let candidate = calendar.date(byAdding: .day, value: -range.rawValue, to: interval.start) ?? interval.start
        return DateInterval(start: max(earliestStart, candidate), end: interval.end)
    }

    static func dayColumns(
        in interval: DateInterval,
        now: Date,
        preferences: UserPreferences,
        calendar: Calendar = .autoupdatingCurrent
    ) -> [CalendarDayColumn] {
        var result: [CalendarDayColumn] = []
        var cursor = interval.start
        let todayStart = TrackingDayService.interval(
            containing: now,
            surface: .calendar,
            preferences: preferences,
            calendar: calendar
        ).start
        while cursor < interval.end {
            let next = calendar.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
            let dayInterval = DateInterval(start: cursor, end: min(next, interval.end))
            result.append(CalendarDayColumn(id: cursor, interval: dayInterval, isToday: cursor == todayStart))
            cursor = next
        }
        return result
    }

    static func makeLayout(
        entries: [TimelineEntry],
        range: CalendarRange,
        filter: CalendarFilter,
        preferences: UserPreferences,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> CalendarLayout {
        let interval = visibleInterval(range: range, now: now, preferences: preferences, calendar: calendar)
        let days = dayColumns(in: interval, now: now, preferences: preferences, calendar: calendar)
        let categories = filter.selectedCategories
        let marks = entries
            .filter { categories.contains($0.category) }
            .flatMap { marks(for: $0, days: days, now: now) }
            .sorted {
                if $0.dayID != $1.dayID { return $0.dayID < $1.dayID }
                if $0.segmentStart != $1.segmentStart { return $0.segmentStart < $1.segmentStart }
                if $0.kind.rawValue != $1.kind.rawValue { return $0.kind.rawValue < $1.kind.rawValue }
                return $0.id < $1.id
            }
        return CalendarLayout(interval: interval, days: days, marks: marks)
    }

    static func makeLayout(
        entries: [TimelineEntry],
        interval: DateInterval,
        filter: CalendarFilter,
        preferences: UserPreferences,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> CalendarLayout {
        let days = dayColumns(in: interval, now: now, preferences: preferences, calendar: calendar)
        let categories = filter.selectedCategories
        let marks = entries
            .filter { categories.contains($0.category) }
            .flatMap { marks(for: $0, days: days, now: now) }
            .sorted {
                if $0.dayID != $1.dayID { return $0.dayID < $1.dayID }
                if $0.segmentStart != $1.segmentStart { return $0.segmentStart < $1.segmentStart }
                if $0.kind.rawValue != $1.kind.rawValue { return $0.kind.rawValue < $1.kind.rawValue }
                return $0.id < $1.id
            }
        return CalendarLayout(interval: interval, days: days, marks: marks)
    }

    static func frame(
        for mark: CalendarMark,
        gridHeight: Double,
        minimumHeight: Double = 3
    ) -> CalendarMarkFrame {
        CalendarMarkFrame(
            y: min(max(0, mark.startFraction * gridHeight), gridHeight),
            height: min(gridHeight, max(minimumHeight, mark.durationFraction * gridHeight))
        )
    }

    static func columnWidth(availableWidth: Double, range: CalendarRange) -> Double {
        max(1, availableWidth / Double(range.rawValue))
    }

    static func fraction(of date: Date, in interval: DateInterval) -> Double {
        guard interval.duration > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(interval.start) / interval.duration))
    }

    static func soothingOffset(
        for date: Date,
        in mark: CalendarMark,
        markHeight: Double
    ) -> Double {
        let duration = mark.segmentEnd.timeIntervalSince(mark.segmentStart)
        guard duration > 0 else { return 0 }
        let progress = date.timeIntervalSince(mark.segmentStart) / duration
        return min(markHeight, max(0, progress * markHeight))
    }

    private static func marks(
        for entry: TimelineEntry,
        days: [CalendarDayColumn],
        now: Date
    ) -> [CalendarMark] {
        let end = semanticEnd(for: entry, now: now)
        let isDuration = end > entry.date
        return days.compactMap { day in
            if !isDuration {
                guard day.interval.contains(entry.date) else { return nil }
                return mark(entry: entry, day: day, start: entry.date, end: entry.date, now: now)
            }
            let start = max(entry.date, day.interval.start)
            let clippedEnd = min(end, day.interval.end)
            guard start < clippedEnd else { return nil }
            return mark(entry: entry, day: day, start: start, end: clippedEnd, now: now)
        }
    }

    private static func mark(
        entry: TimelineEntry,
        day: CalendarDayColumn,
        start: Date,
        end: Date,
        now: Date
    ) -> CalendarMark {
        let startFraction = fraction(of: start, in: day.interval)
        let endFraction = fraction(of: end, in: day.interval)
        let isOpenSleep: Bool = if case .sleep(let session) = entry.kind { session.isOpen } else { false }
        let soothingTimes: [Date] = if case .sleep(let session) = entry.kind {
            session.soothingTimes
                .filter { $0 >= start && $0 < end }
                .sorted()
        } else {
            []
        }
        return CalendarMark(
            id: "\(entry.id)|\(day.id.timeIntervalSinceReferenceDate)",
            entry: entry,
            dayID: day.id,
            segmentStart: start,
            segmentEnd: end,
            startFraction: startFraction,
            durationFraction: max(0, endFraction - startFraction),
            kind: CalendarMarkKind(category: entry.category),
            isContinuation: start > entry.date,
            isInProgress: isOpenSleep && end == min(now, day.interval.end),
            soothingTimes: soothingTimes
        )
    }

    private static func semanticEnd(for entry: TimelineEntry, now: Date) -> Date {
        switch entry.kind {
        case .pump(let session): session.endTime
        case .nursing(let session): session.endTime
        case .sleep(let session): session.endTime ?? max(now, session.startTime)
        case .bottle, .diaper, .checklist, .growth: entry.date
        }
    }
}
