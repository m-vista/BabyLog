import Foundation
import Testing
@testable import BabyLog

struct Phase15TimelineAggregationTests {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0, month: Int = 1, year: Int = 2_026) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func preferences(dayStartMinutes: Int = 0, useCustomDayInTimeline: Bool = true) -> UserPreferences {
        UserPreferences(dayStartMinutes: dayStartMinutes, useCustomDayInTimeline: useCustomDayInTimeline)
    }

    // MARK: Fixtures

    private func pump(id: String, start: Date, total: Double = 60, left: Double? = nil, right: Double? = nil, duration: TimeInterval = 600, postNursing: Bool = false) throws -> PumpSession {
        try PumpSession(id: id, babyID: "baby", startTime: start, durationSeconds: duration, leftAmountMl: left, rightAmountMl: right, totalAmountMl: total, isPostNursing: postNursing, notes: "", createdByUserID: "user", createdAt: start, updatedAt: start)
    }

    private func bottle(id: String, start: Date, breast: Double = 0, formula: Double = 0, unspecified: Double = 60) throws -> BottleFeed {
        try BottleFeed(id: id, babyID: "baby", startTime: start, breastMilkAmountMl: breast, formulaAmountMl: formula, unspecifiedAmountMl: unspecified, notes: "", createdByUserID: "user", createdAt: start, updatedAt: start)
    }

    private func nursing(id: String, start: Date, left: TimeInterval = 300, right: TimeInterval = 300, lastSide: NursingSide = .right) throws -> NursingSession {
        try NursingSession(id: id, babyID: "baby", startTime: start, endTime: start.addingTimeInterval(left + right), leftDurationSeconds: left, rightDurationSeconds: right, startingSide: .left, lastSide: lastSide, notes: "", createdByUserID: "user", createdAt: start, updatedAt: start)
    }

    private func sleep(id: String, start: Date, end: Date?) throws -> SleepSession {
        try SleepSession(id: id, babyID: "baby", startTime: start, endTime: end, notes: "", createdByUserID: "user", createdAt: start, updatedAt: start)
    }

    private func diaper(id: String, start: Date, type: DiaperType, fullness: DiaperFullness? = nil, size: DiaperSize? = nil) throws -> DiaperEvent {
        try DiaperEvent(id: id, babyID: "baby", startTime: start, type: type, fullness: fullness, size: size, notes: "", createdByUserID: "user", createdAt: start, updatedAt: start)
    }

    private func checklistEvent(id: String, itemID: String, at timestamp: Date) throws -> ChecklistEvent {
        try ChecklistEvent(id: id, babyID: "baby", checklistItemID: itemID, timestamp: timestamp, notes: "", createdByUserID: "user", createdAt: timestamp, updatedAt: timestamp)
    }

    private func checklistItem(id: String, title: String) throws -> ChecklistItem {
        try ChecklistItem(id: id, babyID: "baby", title: title, symbol: ChecklistSymbol.bath.rawValue, sortOrder: 0, isActive: true, createdByUserID: "user", createdAt: .now, updatedAt: .now)
    }

    // MARK: Tracking-day boundaries

    @Test func midnightBoundarySeparatesCalendarDays() throws {
        let beforeMidnight = try pump(id: "a", start: date(1, 23, 59, 59))
        let afterMidnight = try pump(id: "b", start: date(2, 0, 0, 0))
        let entries = TimelineAggregator.makeEntries(pumps: [beforeMidnight, afterMidnight], bottles: [], nursingSessions: [], sleepSessions: [], diaperEvents: [], checklistEvents: [], checklistItemsByID: [:])
        let sections = TimelineAggregator.groupByDay(entries: entries, preferences: preferences(dayStartMinutes: 0), activeChecklistItemCount: 0, calendar: utcCalendar, now: date(2, 1, 0))
        #expect(sections.count == 2)
    }

    @Test func customBoundaryEventImmediatelyBeforeStaysInPreviousDay() throws {
        // 5:00 AM custom day start.
        let justBeforeBoundary = try pump(id: "before", start: date(2, 4, 59, 59))
        let entries = TimelineAggregator.makeEntries(pumps: [justBeforeBoundary], bottles: [], nursingSessions: [], sleepSessions: [], diaperEvents: [], checklistEvents: [], checklistItemsByID: [:])
        let sections = TimelineAggregator.groupByDay(entries: entries, preferences: preferences(dayStartMinutes: 300), activeChecklistItemCount: 0, calendar: utcCalendar, now: date(2, 10, 0))
        #expect(sections.count == 1)
        #expect(sections[0].id == date(1, 5, 0, 0))
    }

    @Test func customBoundaryEventExactlyAtBoundaryStartsNewDay() throws {
        let exactlyAtBoundary = try pump(id: "at", start: date(2, 5, 0, 0))
        let entries = TimelineAggregator.makeEntries(pumps: [exactlyAtBoundary], bottles: [], nursingSessions: [], sleepSessions: [], diaperEvents: [], checklistEvents: [], checklistItemsByID: [:])
        let sections = TimelineAggregator.groupByDay(entries: entries, preferences: preferences(dayStartMinutes: 300), activeChecklistItemCount: 0, calendar: utcCalendar, now: date(2, 10, 0))
        #expect(sections.count == 1)
        #expect(sections[0].id == date(2, 5, 0, 0))
    }

    @Test func customBoundaryHandlesBothSidesInOneWindow() throws {
        let before = try pump(id: "before", start: date(2, 4, 59, 59))
        let at = try pump(id: "at", start: date(2, 5, 0, 0))
        let entries = TimelineAggregator.makeEntries(pumps: [before, at], bottles: [], nursingSessions: [], sleepSessions: [], diaperEvents: [], checklistEvents: [], checklistItemsByID: [:])
        let sections = TimelineAggregator.groupByDay(entries: entries, preferences: preferences(dayStartMinutes: 300), activeChecklistItemCount: 0, calendar: utcCalendar, now: date(2, 10, 0))
        #expect(sections.count == 2)
        let previousDay = sections.first { $0.id == date(1, 5, 0, 0) }
        let newDay = sections.first { $0.id == date(2, 5, 0, 0) }
        #expect(previousDay?.entries.map(\.id) == ["pump-before"])
        #expect(newDay?.entries.map(\.id) == ["pump-at"])
    }

    // MARK: Ordering

    @Test func entriesSortNewestFirst() throws {
        let earliest = try pump(id: "earliest", start: date(1, 8, 0))
        let middle = try pump(id: "middle", start: date(1, 12, 0))
        let latest = try pump(id: "latest", start: date(1, 18, 0))
        let entries = TimelineAggregator.makeEntries(pumps: [earliest, latest, middle], bottles: [], nursingSessions: [], sleepSessions: [], diaperEvents: [], checklistEvents: [], checklistItemsByID: [:])
        #expect(entries.map(\.id) == ["pump-latest", "pump-middle", "pump-earliest"])
    }

    @Test func identicalTimestampsBreakTiesDeterministically() throws {
        let same = date(1, 12, 0)
        let b = try pump(id: "bbb", start: same)
        let a = try pump(id: "aaa", start: same)
        let orderOne = TimelineAggregator.sortedNewestFirst([TimelineEntry(kind: .pump(b)), TimelineEntry(kind: .pump(a))])
        let orderTwo = TimelineAggregator.sortedNewestFirst([TimelineEntry(kind: .pump(a)), TimelineEntry(kind: .pump(b))])
        #expect(orderOne.map(\.id) == ["pump-aaa", "pump-bbb"])
        #expect(orderOne.map(\.id) == orderTwo.map(\.id))
    }

    // MARK: Category grouping

    @Test func feedGroupingIncludesBottleAndNursing() throws {
        let b = try bottle(id: "b1", start: date(1, 9, 0))
        let n = try nursing(id: "n1", start: date(1, 10, 0))
        let entries = TimelineAggregator.makeEntries(pumps: [], bottles: [b], nursingSessions: [n], sleepSessions: [], diaperEvents: [], checklistEvents: [], checklistItemsByID: [:])
        let feedOnly = TimelineAggregator.filtered(entries, by: .feed)
        #expect(Set(feedOnly.map(\.id)) == ["bottle-b1", "nursing-n1"])
        #expect(feedOnly.allSatisfy { $0.category == .feed })
    }

    @Test func pumpDoesNotEnterFeedGrouping() throws {
        let p = try pump(id: "p1", start: date(1, 9, 0))
        let b = try bottle(id: "b1", start: date(1, 9, 30))
        let entries = TimelineAggregator.makeEntries(pumps: [p], bottles: [b], nursingSessions: [], sleepSessions: [], diaperEvents: [], checklistEvents: [], checklistItemsByID: [:])
        let feedOnly = TimelineAggregator.filtered(entries, by: .feed)
        #expect(feedOnly.map(\.id) == ["bottle-b1"])
        #expect(entries.first { $0.id == "pump-p1" }?.category == .pump)
    }

    @Test func checklistEventsGroupUnderOther() throws {
        let item = try checklistItem(id: "item-bath", title: "Bath")
        let event = try checklistEvent(id: "e1", itemID: "item-bath", at: date(1, 19, 0))
        let entries = TimelineAggregator.makeEntries(pumps: [], bottles: [], nursingSessions: [], sleepSessions: [], diaperEvents: [], checklistEvents: [event], checklistItemsByID: ["item-bath": item])
        #expect(entries.first?.category == .other)
        #expect(TimelineAggregator.filtered(entries, by: .other).count == 1)
    }

    @Test func diaperBothIncrementsBothWetAndDirtyCounts() throws {
        let both = try diaper(id: "d1", start: date(1, 10, 0), type: .both)
        let entries = TimelineAggregator.makeEntries(pumps: [], bottles: [], nursingSessions: [], sleepSessions: [], diaperEvents: [both], checklistEvents: [], checklistItemsByID: [:])
        let summary = TimelineAggregator.daySummary(for: entries, activeChecklistItemCount: 0)
        #expect(summary.diaper.count == 1)
        #expect(summary.diaper.wetCount == 1)
        #expect(summary.diaper.dirtyCount == 1)
    }

    // MARK: Zero-category summaries

    @Test func zeroCategorySummaryRowsRemainPresentInAllMode() throws {
        let onlyDiaper = try diaper(id: "d1", start: date(1, 10, 0), type: .wet)
        let entries = TimelineAggregator.makeEntries(pumps: [], bottles: [], nursingSessions: [], sleepSessions: [], diaperEvents: [onlyDiaper], checklistEvents: [], checklistItemsByID: [:])
        let summary = TimelineAggregator.daySummary(for: entries, activeChecklistItemCount: 5)
        #expect(summary.feed.count == 0)
        #expect(summary.pump.count == 0)
        #expect(summary.sleep.totalSeconds == 0)
        #expect(summary.other.totalItemCount == 5)
        #expect(summary.other.completedCount == 0)
        #expect(TimelineSummaryFormatter.feedLine(summary.feed, unit: .ounces) == "No feed logged")
        #expect(TimelineSummaryFormatter.otherLine(summary.other) == "0 of 5")
    }

    // MARK: Filters

    @Test func allFilterReturnsEveryEntryUnchanged() throws {
        let entries = try sampleOfEachCategory()
        #expect(TimelineAggregator.filtered(entries, by: .all).count == entries.count)
    }

    @Test func feedFilterReturnsOnlyFeedEntries() throws {
        let entries = try sampleOfEachCategory()
        #expect(TimelineAggregator.filtered(entries, by: .feed).allSatisfy { $0.category == .feed })
    }

    @Test func diaperFilterReturnsOnlyDiaperEntries() throws {
        let entries = try sampleOfEachCategory()
        #expect(TimelineAggregator.filtered(entries, by: .diaper).allSatisfy { $0.category == .diaper })
    }

    @Test func sleepFilterReturnsOnlySleepEntries() throws {
        let entries = try sampleOfEachCategory()
        #expect(TimelineAggregator.filtered(entries, by: .sleep).allSatisfy { $0.category == .sleep })
    }

    @Test func pumpFilterReturnsOnlyPumpEntries() throws {
        let entries = try sampleOfEachCategory()
        #expect(TimelineAggregator.filtered(entries, by: .pump).allSatisfy { $0.category == .pump })
    }

    @Test func otherFilterReturnsOnlyOtherEntries() throws {
        let entries = try sampleOfEachCategory()
        #expect(TimelineAggregator.filtered(entries, by: .other).allSatisfy { $0.category == .other })
    }

    @Test func multiFilterReturnsEverySelectedCategory() throws {
        let entries = try sampleOfEachCategory()
        let filtered = TimelineAggregator.filtered(entries, by: .multi([.feed, .sleep, .pump]))
        #expect(!filtered.isEmpty)
        #expect(filtered.allSatisfy { [.feed, .sleep, .pump].contains($0.category) })
        #expect(Set(filtered.map(\.category)) == [.feed, .sleep, .pump])
        #expect(TimelineAggregator.filtered(entries, by: .multi([])).isEmpty)
    }

    private func sampleOfEachCategory() throws -> [TimelineEntry] {
        let item = try checklistItem(id: "item-bath", title: "Bath")
        return TimelineAggregator.makeEntries(
            pumps: [try pump(id: "p1", start: date(1, 9, 0))],
            bottles: [try bottle(id: "b1", start: date(1, 9, 30))],
            nursingSessions: [try nursing(id: "n1", start: date(1, 10, 0))],
            sleepSessions: [try sleep(id: "s1", start: date(1, 7, 0), end: date(1, 8, 0))],
            diaperEvents: [try diaper(id: "d1", start: date(1, 11, 0), type: .wet)],
            checklistEvents: [try checklistEvent(id: "c1", itemID: "item-bath", at: date(1, 19, 0))],
            checklistItemsByID: ["item-bath": item]
        )
    }

    // MARK: Full-list vs summaries-only

    @Test func daySectionCarriesBothEntriesAndSummaryForEitherDisplayMode() throws {
        let entries = try sampleOfEachCategory()
        let sections = TimelineAggregator.groupByDay(entries: entries, preferences: preferences(), activeChecklistItemCount: 1, calendar: utcCalendar, now: date(1, 20, 0))
        let section = try #require(sections.first)
        // Full-list mode consumes `entries`; summaries-only mode consumes only `summary`. Both are always populated from one aggregation pass.
        #expect(!section.entries.isEmpty)
        #expect(section.summary.feed.count == 2)
        #expect(section.summary.pump.count == 1)
        #expect(section.summary.diaper.count == 1)
        #expect(section.summary.sleep.totalSeconds > 0)
        #expect(section.summary.other.completedCount == 1)
    }

    // MARK: Sleep — open sessions

    @Test func openSleepSessionIsMarkedInProgress() throws {
        let open = try sleep(id: "open", start: date(1, 22, 0), end: nil)
        #expect(open.isOpen)
        let entries = TimelineAggregator.makeEntries(pumps: [], bottles: [], nursingSessions: [], sleepSessions: [open], diaperEvents: [], checklistEvents: [], checklistItemsByID: [:])
        #expect(entries.first?.category == .sleep)
    }

    @Test func openSleepDurationUsesSuppliedNow() throws {
        let open = try sleep(id: "open", start: date(1, 22, 0), end: nil)
        let now = date(1, 23, 30)
        let duration = SleepCalculator.duration(of: open, now: now)
        #expect(duration == 90 * 60)

        let entries = TimelineAggregator.makeEntries(pumps: [], bottles: [], nursingSessions: [], sleepSessions: [open], diaperEvents: [], checklistEvents: [], checklistItemsByID: [:])
        let summary = TimelineAggregator.daySummary(for: entries, activeChecklistItemCount: 0, now: now)
        #expect(summary.sleep.totalSeconds == 90 * 60)
    }

    @Test func completedSleepDurationIgnoresNow() throws {
        let completed = try sleep(id: "done", start: date(1, 20, 0), end: date(1, 21, 30))
        let duration = SleepCalculator.duration(of: completed, now: date(5, 0, 0))
        #expect(duration == 90 * 60)
    }

    @Test func priorAwakeDurationUsesFullSleepHistory() throws {
        let previous = try sleep(id: "previous", start: date(1, 9, 0), end: date(1, 10, 0))
        let current = try sleep(id: "current", start: date(1, 11, 30), end: date(1, 12, 0))
        let awake = try #require(TimelineAggregator.priorAwakeDuration(before: current, allSleepSessions: [previous, current]))
        #expect(abs(awake - 5_400) < 0.001)
    }

    // MARK: Windowed loading

    @Test func initialWindowSpansFourteenContinuousDays() throws {
        let now = date(20, 15, 0)
        let window = TimelineAggregator.initialWindow(now: now, days: 14, preferences: preferences(dayStartMinutes: 0), calendar: utcCalendar)
        let spanDays = utcCalendar.dateComponents([.day], from: window.start, to: window.end).day
        #expect(spanDays == 14)
        #expect(window.end == date(21, 0, 0))
        #expect(window.start == date(7, 0, 0))
    }

    @Test func extendingWindowOlderMovesStartBackKeepingEnd() throws {
        let initial = TimelineAggregator.initialWindow(now: date(20, 15, 0), days: 14, preferences: preferences(dayStartMinutes: 0), calendar: utcCalendar)
        let extended = TimelineAggregator.extendedWindow(initial, olderBy: 14, calendar: utcCalendar)
        #expect(extended.end == initial.end)
        #expect(extended.start < initial.start)
        #expect(utcCalendar.dateComponents([.day], from: extended.start, to: initial.start).day == 14)
    }

    @Test func mergingSleepSessionsDedupesOverlapBetweenRangedAndOpenListeners() throws {
        let open = try sleep(id: "open", start: date(1, 22, 0), end: nil)
        let completed = try sleep(id: "done", start: date(1, 5, 0), end: date(1, 6, 0))
        // The ranged query already contains the open session (its startTime is in-window);
        // the dedicated open-session listener yields it too. Merge must not duplicate it.
        let merged = TimelineAggregator.mergeSleepSessions(ranged: [open, completed], open: [open])
        #expect(merged.count == 2)
        #expect(Set(merged.map(\.id)) == ["open", "done"])
    }

    // MARK: Identity and determinism

    @Test func entryIdentityIsStableAndUnique() throws {
        let session = try pump(id: "p1", start: date(1, 9, 0))
        let first = TimelineEntry(kind: .pump(session))
        let second = TimelineEntry(kind: .pump(session))
        #expect(first.id == second.id)
        #expect(first == second)

        let other = try pump(id: "p2", start: date(1, 9, 0))
        #expect(TimelineEntry(kind: .pump(other)).id != first.id)
    }

    @Test func groupByDayIsDeterministicAcrossRepeatedCalls() throws {
        let entries = try sampleOfEachCategory()
        let prefs = preferences()
        let first = TimelineAggregator.groupByDay(entries: entries, preferences: prefs, activeChecklistItemCount: 1, calendar: utcCalendar, now: date(1, 20, 0))
        let second = TimelineAggregator.groupByDay(entries: entries, preferences: prefs, activeChecklistItemCount: 1, calendar: utcCalendar, now: date(1, 20, 0))
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first.map { $0.entries.map(\.id) } == second.map { $0.entries.map(\.id) })
    }

    // MARK: Row + summary text formatting

    @Test func pumpRowOmitsLeftRightWhenUnspecifiedButShowsWhenKnownZero() throws {
        let unspecified = try pump(id: "p1", start: date(1, 9, 0), total: 60, left: nil, right: nil, duration: 600)
        let known = try pump(id: "p2", start: date(1, 9, 0), total: 60, left: 0, right: 60, duration: 600)
        #expect(TimelineRowFormatter.pump(unspecified, unit: .milliliters, showRate: false, rate: nil).secondary == "10m")
        #expect(TimelineRowFormatter.pump(known, unit: .milliliters, showRate: false, rate: nil).secondary == "10m · L 0 · R 60 mL")
    }

    @Test func firstPumpRowShowsUnavailableRateAndLaterPumpShowsComputedRate() throws {
        let pump = try pump(id: "p1", start: date(1, 9, 0), total: 60, duration: 600)
        #expect(TimelineRowFormatter.pump(pump, unit: .milliliters, showRate: true, rate: nil).primary == "60 mL · – mL/hr")
        #expect(TimelineRowFormatter.pump(pump, unit: .milliliters, showRate: true, rate: 30).primary == "60 mL · 30 mL/hr")
    }

    @Test func bottleRowShowsUnspecifiedAsBottleLiteral() throws {
        let unspecified = try bottle(id: "b1", start: date(1, 9, 0), breast: 0, formula: 0, unspecified: 60)
        let mixed = try bottle(id: "b2", start: date(1, 9, 0), breast: 30, formula: 30, unspecified: 0)
        #expect(TimelineRowFormatter.bottle(unspecified, unit: .milliliters).secondary == "Bottle")
        #expect(TimelineRowFormatter.bottle(mixed, unit: .milliliters).secondary == "Breast milk 30 mL · Formula 30 mL")
    }

    @Test func diaperTimelineTerminologyIsWetAndDirty() throws {
        let both = try diaper(id: "d1", start: date(1, 9, 0), type: .both, fullness: .heavy, size: .two)
        let row = TimelineRowFormatter.diaper(both)
        #expect(row.primary == "Wet & Dirty")
        #expect(row.secondary == "Heavy · Size 2")
    }

    @Test func sleepRowShowsSleepingTagOnlyWhileOpen() throws {
        let open = try sleep(id: "open", start: date(1, 22, 0), end: nil)
        let completed = try sleep(id: "done", start: date(1, 20, 0), end: date(1, 21, 0))
        #expect(TimelineRowFormatter.sleep(open, priorAwake: nil, now: date(1, 23, 0)).tag == "SLEEPING")
        #expect(TimelineRowFormatter.sleep(completed, priorAwake: nil).tag == nil)
    }
}
