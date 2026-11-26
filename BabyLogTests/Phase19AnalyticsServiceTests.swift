import Foundation
import Testing
@testable import BabyLog

@Suite("Phase 19 Analytics service")
struct Phase19AnalyticsServiceTests {
    private var calendar: Calendar { var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(secondsFromGMT: 0)!; return value }
    private func date(_ day: Int, _ hour: Int = 12) -> Date { calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour))! }
    private var baby: Baby { Baby(id: "b", name: "B", birthDate: date(1), createdByUserID: "u", createdAt: date(1), updatedAt: date(1)) }
    private func input(now: Date, range: AnalyticsRange = .sevenDays, preferences: UserPreferences = .defaults, pumps: [PumpSession] = [], previous: PumpSession? = nil, bottles: [BottleFeed] = [], sleep: [SleepSession] = [], diapers: [DiaperEvent] = [], events: [ChecklistEvent] = [], items: [ChecklistItem] = []) -> AnalyticsInput {
        AnalyticsInput(baby: baby, range: range, preferences: preferences, now: now, pumps: pumps, pumpImmediatelyBeforeRange: previous, bottles: bottles, nursing: [], sleep: sleep, diapers: diapers, checklistEvents: events, checklistItems: items)
    }

    @Test("Both increments wet and dirty") func bothCountsTwice() throws {
        let event = try DiaperEvent(id: "d", babyID: "b", startTime: date(7), type: .both, fullness: nil, size: nil, notes: "", createdByUserID: "u", createdAt: date(7), updatedAt: date(7))
        let result = AnalyticsService.calculate(input(now: date(7, 18), diapers: [event]), calendar: calendar).diaper
        #expect(result.changes == 1); #expect(result.wet == 1); #expect(result.dirty == 1); #expect(result.both == 1)
    }

    @Test("Unspecified bottle content remains its own share") func unspecifiedBottle() throws {
        let bottle = try BottleFeed(id: "f", babyID: "b", startTime: date(7), breastMilkAmountMl: 30, formulaAmountMl: 20, unspecifiedAmountMl: 50, notes: "", createdByUserID: "u", createdAt: date(7), updatedAt: date(7))
        let result = AnalyticsService.calculate(input(now: date(7, 18), bottles: [bottle]), calendar: calendar).feed
        #expect(result.bottleAmountMl == 100); #expect(result.unspecifiedMl == 50)
    }

    @Test("Clean pump rate excludes post-nursing sessions") func cleanPumpRate() throws {
        let previous = try pump("before", date(1, 8), 30, false)
        let clean = try pump("clean", date(2, 8), 60, false)
        let post = try pump("post", date(2, 9), 90, true)
        let result = AnalyticsService.calculate(input(now: date(2, 18), pumps: [clean, post], previous: previous), calendar: calendar).pump
        #expect(result.cleanMl == 60); #expect(result.postNursingCount == 1)
        #expect(result.cleanRateMlPerHour != nil)
    }

    @Test("Night window classifies night separately from naps") func nightAndNap() throws {
        let night = try SleepSession(id: "n", babyID: "b", startTime: date(6, 21), endTime: date(7, 5), notes: "", createdByUserID: "u", createdAt: date(6), updatedAt: date(6))
        let nap = try SleepSession(id: "p", babyID: "b", startTime: date(7, 13), endTime: date(7, 14), notes: "", createdByUserID: "u", createdAt: date(7), updatedAt: date(7))
        let result = AnalyticsService.calculate(input(now: date(7, 18), sleep: [night, nap]), calendar: calendar).sleep
        #expect(result.nightSeconds == 8 * 3_600); #expect(result.napSeconds == 3_600); #expect(result.napCount == 1)
    }

    @Test("Checklist completion uses active items and distinct days") func checklistCompletion() throws {
        let item = try ChecklistItem(id: "i", babyID: "b", title: "Bath", symbol: ChecklistSymbol.bath.rawValue, sortOrder: 0, isActive: true, createdByUserID: "u", createdAt: date(1), updatedAt: date(1))
        let event = try ChecklistEvent(id: "e", babyID: "b", checklistItemID: "i", timestamp: date(7), notes: "", createdByUserID: "u", createdAt: date(7), updatedAt: date(7))
        let result = AnalyticsService.calculate(input(now: date(7, 18), events: [event], items: [item]), calendar: calendar).other
        #expect(result.completedCount == 1); #expect(result.possibleCount == 7); #expect(result.items.first?.completedDays == 1)
    }

    @Test("Range respects custom analytics boundary") func customBoundary() {
        var preferences = UserPreferences.defaults; preferences.dayStartMinutes = 300; preferences.useCustomDayInAnalytics = true
        let interval = AnalyticsService.interval(range: .day, now: date(7, 4), preferences: preferences, calendar: calendar)
        #expect(interval.start == date(6, 5)); #expect(interval.end == date(7, 5))
    }

    private func pump(_ id: String, _ start: Date, _ amount: Double, _ post: Bool) throws -> PumpSession {
        try PumpSession(id: id, babyID: "b", startTime: start, durationSeconds: 1_200, leftAmountMl: amount / 2, rightAmountMl: amount / 2, totalAmountMl: amount, isPostNursing: post, notes: "", createdByUserID: "u", createdAt: start, updatedAt: start)
    }
}
