import Foundation
import Testing
@testable import BabyLog

@MainActor
struct Phase17CalendarGeometryTests {

    @Test func initialHistoryKeepsOnlyOnePrecedingPage() {
        let preferences = UserPreferences.defaults
        let now = date(day: 30, hour: 12)
        let interval = CalendarGeometryService.initialHistoryInterval(
            range: .seven,
            earliestDate: date(day: 1, hour: 12),
            now: now,
            preferences: preferences,
            calendar: calendar
        )

        #expect(interval.start == date(day: 17, hour: 0))
        #expect(interval.end == date(day: 31, hour: 0))
    }

    @Test func initialHistoryDoesNotPrecedeBirthTrackingDay() {
        let preferences = UserPreferences.defaults
        let interval = CalendarGeometryService.initialHistoryInterval(
            range: .thirty,
            earliestDate: date(day: 20, hour: 12),
            now: date(day: 30, hour: 12),
            preferences: preferences,
            calendar: calendar
        )

        #expect(interval.start == date(day: 20, hour: 0))
        #expect(interval.end == date(day: 31, hour: 0))
    }

    @Test func extendingHistoryAddsOnePageAndStopsAtBirth() {
        let initial = DateInterval(start: date(day: 17, hour: 0), end: date(day: 31, hour: 0))
        let extended = CalendarGeometryService.extendingHistoryInterval(
            initial,
            range: .seven,
            earliestStart: date(day: 12, hour: 0),
            calendar: calendar
        )

        #expect(extended.start == date(day: 12, hour: 0))
        #expect(extended.end == initial.end)
    }
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0) ?? .autoupdatingCurrent
        return value
    }

    private var preferences: UserPreferences {
        UserPreferences(dayStartMinutes: 300, useCustomDayInCalendar: true)
    }

    @Test func rangesProduceRequestedDayCountsAndWidths() {
        let now = date(day: 30, hour: 12)
        for range in CalendarRange.allCases {
            let interval = CalendarGeometryService.visibleInterval(range: range, now: now, preferences: preferences, calendar: calendar)
            let days = CalendarGeometryService.dayColumns(in: interval, now: now, preferences: preferences, calendar: calendar)
            #expect(days.count == range.rawValue)
            #expect(CalendarGeometryService.columnWidth(availableWidth: 350, range: range) == 350 / Double(range.rawValue))
        }
    }

    @Test func customBoundaryStartsAtFiveAMAndMarksToday() {
        let now = date(day: 30, hour: 3)
        let interval = CalendarGeometryService.visibleInterval(range: .seven, now: now, preferences: preferences, calendar: calendar)
        let days = CalendarGeometryService.dayColumns(in: interval, now: now, preferences: preferences, calendar: calendar)
        #expect(calendar.component(.hour, from: interval.start) == 5)
        #expect(days.last?.id == date(day: 29, hour: 5))
        #expect(days.last?.isToday == true)
    }

    @Test func midnightPreferenceUsesCalendarDay() {
        let prefs = UserPreferences(dayStartMinutes: 300, useCustomDayInCalendar: false)
        let interval = CalendarGeometryService.visibleInterval(range: .seven, now: date(day: 30, hour: 12), preferences: prefs, calendar: calendar)
        #expect(calendar.component(.hour, from: interval.start) == 0)
    }

    @Test func timeAndDurationMapToExpectedGeometry() throws {
        let interval = DateInterval(start: date(day: 30, hour: 5), duration: 24 * 3_600)
        #expect(CalendarGeometryService.fraction(of: interval.start, in: interval) == 0)
        #expect(CalendarGeometryService.fraction(of: interval.start.addingTimeInterval(12 * 3_600), in: interval) == 0.5)
        #expect(CalendarGeometryService.fraction(of: interval.end, in: interval) == 1)

        let mark = CalendarMark(
            id: "mark",
            entry: TimelineEntry(kind: .pump(try pump(start: interval.start, duration: 3_600))),
            dayID: interval.start,
            segmentStart: interval.start.addingTimeInterval(6 * 3_600),
            segmentEnd: interval.start.addingTimeInterval(7 * 3_600),
            startFraction: 0.25,
            durationFraction: 1.0 / 24.0,
            kind: .pump,
            isContinuation: false,
            isInProgress: false,
            soothingTimes: []
        )
        let frame = CalendarGeometryService.frame(for: mark, gridHeight: 480)
        #expect(frame.y == 120)
        #expect(frame.height == 20)
    }

    @Test func pointEventsUseMinimumHeightAndClampInsideGrid() throws {
        let entry = TimelineEntry(kind: .bottle(try bottle(start: date(day: 30, hour: 12))))
        let layout = CalendarGeometryService.makeLayout(entries: [entry], range: .seven, filter: .all, preferences: preferences, now: date(day: 30, hour: 20), calendar: calendar)
        let mark = try #require(layout.marks.first)
        let frame = CalendarGeometryService.frame(for: mark, gridHeight: 480, minimumHeight: 3)
        #expect(frame.height == 3)
        #expect(frame.y >= 0 && frame.y <= 480)
    }

    @Test func categoryMappingAndMultiFilteringAreCorrect() throws {
        let start = date(day: 30, hour: 10)
        let bottleEntry = TimelineEntry(kind: .bottle(try bottle(start: start)))
        let nursingEntry = TimelineEntry(kind: .nursing(try nursing(start: start)))
        let pumpEntry = TimelineEntry(kind: .pump(try pump(start: start)))
        #expect(bottleEntry.category == .feed)
        #expect(nursingEntry.category == .feed)

        let empty = CalendarGeometryService.makeLayout(entries: [bottleEntry, nursingEntry, pumpEntry], range: .seven, filter: .multi([]), preferences: preferences, now: start, calendar: calendar)
        #expect(empty.marks.isEmpty)
        let feed = CalendarGeometryService.makeLayout(entries: [bottleEntry, nursingEntry, pumpEntry], range: .seven, filter: .multi([.feed]), preferences: preferences, now: start, calendar: calendar)
        #expect(feed.marks.count == 2)
        #expect(feed.marks.allSatisfy { $0.category == .feed })
    }

    @Test func overnightSleepSplitsAcrossCustomDayBoundary() throws {
        var session = try sleep(start: date(day: 29, hour: 22), end: date(day: 30, hour: 8))
        session.soothingTimes = [date(day: 30, hour: 2), date(day: 30, hour: 6)]
        let entry = TimelineEntry(kind: .sleep(session))
        let layout = CalendarGeometryService.makeLayout(entries: [entry], range: .seven, filter: .single(.sleep), preferences: preferences, now: date(day: 30, hour: 12), calendar: calendar)
        #expect(layout.marks.count == 2)
        #expect(layout.marks.last?.isContinuation == true)
        #expect(layout.marks.allSatisfy { $0.kind == .sleep })
        #expect(layout.marks.flatMap(\.soothingTimes) == session.soothingTimes)
    }

    @Test func openSleepDrawsThroughSuppliedNowAndUsesStableIdentity() throws {
        let session = try sleep(start: date(day: 29, hour: 22), end: nil)
        let entry = TimelineEntry(kind: .sleep(session))
        let now = date(day: 30, hour: 8)
        let first = CalendarGeometryService.makeLayout(entries: [entry], range: .seven, filter: .all, preferences: preferences, now: now, calendar: calendar)
        let second = CalendarGeometryService.makeLayout(entries: [entry], range: .seven, filter: .all, preferences: preferences, now: now, calendar: calendar)
        #expect(first.marks.map(\.id) == second.marks.map(\.id))
        #expect(first.marks.last?.segmentEnd == now)
        #expect(first.marks.allSatisfy { $0.isInProgress })
    }

    @Test func stackingOrderMatchesSpecification() {
        #expect(CalendarMarkKind.sleep.rawValue < CalendarMarkKind.pump.rawValue)
        #expect(CalendarMarkKind.pump.rawValue < CalendarMarkKind.feed.rawValue)
        #expect(CalendarMarkKind.feed.rawValue < CalendarMarkKind.diaper.rawValue)
        #expect(CalendarMarkKind.diaper.rawValue < CalendarMarkKind.other.rawValue)
    }

    private func date(day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    private func pump(start: Date, duration: TimeInterval = 1_200) throws -> PumpSession {
        try PumpSession(id: "pump", babyID: "baby", startTime: start, durationSeconds: duration, leftAmountMl: 30, rightAmountMl: 30, totalAmountMl: 60, isPostNursing: false, notes: "", createdByUserID: "user", createdAt: start, updatedAt: start)
    }

    private func bottle(start: Date) throws -> BottleFeed {
        try BottleFeed(id: "bottle", babyID: "baby", startTime: start, breastMilkAmountMl: 60, formulaAmountMl: 0, unspecifiedAmountMl: 0, notes: "", createdByUserID: "user", createdAt: start, updatedAt: start)
    }

    private func nursing(start: Date) throws -> NursingSession {
        try NursingSession(id: "nursing", babyID: "baby", startTime: start, endTime: start.addingTimeInterval(900), leftDurationSeconds: 450, rightDurationSeconds: 450, startingSide: .left, lastSide: .right, notes: "", createdByUserID: "user", createdAt: start, updatedAt: start)
    }

    private func sleep(start: Date, end: Date?) throws -> SleepSession {
        try SleepSession(id: "sleep", babyID: "baby", startTime: start, endTime: end, notes: "", createdByUserID: "user", createdAt: start, updatedAt: start)
    }
}
