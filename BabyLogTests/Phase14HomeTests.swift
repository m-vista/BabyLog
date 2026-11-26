import Foundation
import Testing
@testable import BabyLog

struct Phase14HomeTests {
    private let now = Date(timeIntervalSince1970: 30_000)

    @Test func durationFormattingIsCompact() {
        #expect(HomeSummaryService.duration(59) == "0m")
        #expect(HomeSummaryService.duration(600) == "10m")
        #expect(HomeSummaryService.duration(3_900) == "1h 5m")
    }

    @Test func totalOnlyBottleUsesBottleTerminology() throws {
        let feed = try bottle(breast: 0, formula: 0, unspecified: 60)
        #expect(HomeSummaryService.bottleDescription(feed, unit: .milliliters) == "Bottle 60 mL")
    }

    @Test func bottleKnownComponentsUseSpecifiedTerminology() throws {
        #expect(HomeSummaryService.bottleDescription(try bottle(breast: 30, formula: 0, unspecified: 0), unit: .milliliters) == "Breast milk 30 mL")
        #expect(HomeSummaryService.bottleDescription(try bottle(breast: 30, formula: 30, unspecified: 0), unit: .milliliters) == "BM 30 mL & F 30 mL")
    }

    @Test func diaperBothIncrementsBothCounts() throws {
        let wet = try diaper(id: "wet", type: .wet)
        let both = try diaper(id: "both", type: .both)
        let counts = HomeSummaryService.diaperCounts([wet, both])
        #expect(counts.wet == 2)
        #expect(counts.dirty == 1)
    }

    @Test func latestUsesEventStartTime() throws {
        let early = try bottle(id: "early", start: now, breast: 0, formula: 0, unspecified: 30)
        let late = try bottle(id: "late", start: now.addingTimeInterval(60), breast: 0, formula: 0, unspecified: 30)
        #expect(HomeSummaryService.latestByStart([late, early], date: \.startTime)?.id == "late")
    }

    @Test func relativeTimePreferenceIsRespected() {
        let date = now.addingTimeInterval(-600)
        #expect(HomeSummaryService.eventTime(date, showRelative: true, now: now) == "10m ago")
        #expect(HomeSummaryService.eventTime(date, showRelative: false, now: now) == AppFormatters.time().string(from: date))
    }

    @Test func sleepDailySummarySeparatesNapsAndNightSleep() throws {
        let nap = try SleepSession(
            id: "nap",
            babyID: "baby",
            startTime: calendarDate(hour: 13),
            endTime: calendarDate(hour: 14, minute: 30),
            notes: "",
            createdByUserID: "user",
            createdAt: now,
            updatedAt: now
        )
        let night = try SleepSession(
            id: "night",
            babyID: "baby",
            startTime: calendarDate(hour: 20),
            endTime: calendarDate(day: 2, hour: 4),
            notes: "",
            createdByUserID: "user",
            createdAt: now,
            updatedAt: now
        )

        #expect(HomeSummaryService.sleepDailySummary([nap, night], nightStartMinutes: 1_140, nightEndMinutes: 420) == "1 nap · 1h 30m · Night 8h")
    }

    private func bottle(id: String = "bottle", start: Date? = nil, breast: Double, formula: Double, unspecified: Double) throws -> BottleFeed {
        try BottleFeed(id: id, babyID: "baby", startTime: start ?? now, breastMilkAmountMl: breast, formulaAmountMl: formula, unspecifiedAmountMl: unspecified, notes: "", createdByUserID: "user", createdAt: now, updatedAt: now)
    }

    private func diaper(id: String, type: DiaperType) throws -> DiaperEvent {
        try DiaperEvent(id: id, babyID: "baby", startTime: now, type: type, fullness: nil, size: nil, notes: "", createdByUserID: "user", createdAt: now, updatedAt: now)
    }

    private func calendarDate(day: Int = 1, hour: Int, minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        return calendar.date(from: DateComponents(year: 2026, month: 1, day: day, hour: hour, minute: minute))!
    }
}
