import Foundation
import Testing
@testable import BabyLog

struct Fixes1023Tests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    // MARK: Sleep classification (5)

    @Test func sleepMostlyInNightHoursIsNightEvenIfItStartsBeforeNight() {
        // Night 8pm-7am; 7pm-3am has 7 of 8 hours inside night.
        let result = SleepClassifier.classify(
            startTime: date(10, 19), endTime: date(11, 3),
            nightStartMinutes: 1_200, nightEndMinutes: 420, calendar: calendar
        )
        #expect(result == .night)
    }

    @Test func napOverlappingNightEdgeStaysNap() {
        // 7:30pm-9:30pm is only 1.5h of 2h inside... but 6pm-9pm is 1h of 3h.
        let result = SleepClassifier.classify(
            startTime: date(10, 18), endTime: date(10, 21),
            nightStartMinutes: 1_200, nightEndMinutes: 420, calendar: calendar
        )
        #expect(result == .nap)
    }

    @Test func middayNapIsNapAndExactHalfIsNap() {
        let midday = SleepClassifier.classify(
            startTime: date(10, 12), endTime: date(10, 14),
            nightStartMinutes: 1_200, nightEndMinutes: 420, calendar: calendar
        )
        #expect(midday == .nap)
        // 7pm-9pm: exactly 1h of 2h in night, not a majority.
        let half = SleepClassifier.classify(
            startTime: date(10, 19), endTime: date(10, 21),
            nightStartMinutes: 1_200, nightEndMinutes: 420, calendar: calendar
        )
        #expect(half == .nap)
    }

    @Test func earlyMorningSleepInsideNightWindowIsNight() {
        let result = SleepClassifier.classify(
            startTime: date(11, 5), endTime: date(11, 8),
            nightStartMinutes: 1_200, nightEndMinutes: 420, calendar: calendar
        )
        #expect(result == .night)
    }

    // MARK: Nursing timer controls (6)

    @Test func tapActionsFollowRunningAndPausedState() {
        #expect(NursingTimerControls.action(for: .left, activeSide: nil, isPaused: true) == .start)
        #expect(NursingTimerControls.action(for: .left, activeSide: .left, isPaused: false) == .pause)
        #expect(NursingTimerControls.action(for: .right, activeSide: .left, isPaused: false) == .switchSide)
        #expect(NursingTimerControls.action(for: .left, activeSide: .left, isPaused: true) == .start)
        #expect(NursingTimerControls.action(for: .right, activeSide: .left, isPaused: true) == .start)
    }

    @Test func endSessionOnlyWhenPaused() {
        #expect(NursingTimerControls.canEndSession(isPaused: true))
        #expect(!NursingTimerControls.canEndSession(isPaused: false))
    }

    // MARK: Growth (7, 10, 11)

    @Test func valueDomainAddsQuarterHeadroomAboveHeaviest() throws {
        let domain = try #require(GrowthPercentileService.valueDomain(for: [4, 8]))
        #expect(domain.upperBound == 10)
        #expect(domain.lowerBound == 3)
        #expect(GrowthPercentileService.valueDomain(for: []) == nil)
    }

    @Test func ordinalSuffixes() {
        #expect(1.ordinal == "1st")
        #expect(12.ordinal == "12th")
        #expect(22.ordinal == "22nd")
        #expect(93.ordinal == "93rd")
    }

    // MARK: Calendar zoom (8)

    @Test func pinchSteps() {
        #expect(CalendarRange.seven.afterPinch(scale: 0.6) == .fourteen)
        #expect(CalendarRange.fourteen.afterPinch(scale: 0.6) == .thirty)
        #expect(CalendarRange.thirty.afterPinch(scale: 0.6) == .thirty)
        #expect(CalendarRange.thirty.afterPinch(scale: 1.5) == .fourteen)
        #expect(CalendarRange.seven.afterPinch(scale: 1.5) == .seven)
        #expect(CalendarRange.seven.afterPinch(scale: 0.95) == .seven)
    }

    // MARK: Header age (12)

    @Test func ageTextIncludesMonthsDaysAndWeeks() {
        let birth = date(1, 0)
        let birthPlus = calendar.date(byAdding: DateComponents(month: 3, day: 20), to: birth)!
        let text = HomeSummaryService.ageText(birthDate: birth, now: birthPlus, calendar: calendar)
        #expect(text.hasPrefix("3 months 20 days old (1"))
        #expect(text.hasSuffix("weeks)"))
    }

    @Test func ageTextForNewbornShowsDays() {
        let birth = date(1, 0)
        let text = HomeSummaryService.ageText(birthDate: birth, now: date(4, 12), calendar: calendar)
        #expect(text == "3 days old (0 weeks)")
    }

    @Test func ageUsesCalendarDaysRegardlessOfTimeOfDay() {
        let birth = calendar.date(from: DateComponents(year: 2026, month: 6, day: 22, hour: 23))!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 0))!

        #expect(
            HomeSummaryService.ageText(birthDate: birth, now: now, calendar: calendar)
                .hasPrefix("4 months 5 days old")
        )
    }

    @Test func growthAgeUsesCalendarDaysRegardlessOfTimeOfDay() {
        let birth = calendar.date(from: DateComponents(year: 2026, month: 6, day: 22, hour: 23))!
        let measurementDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 0))!
        let baby = Baby(
            id: "baby",
            name: "Baby",
            birthDate: birth,
            createdByUserID: "user",
            createdAt: birth,
            updatedAt: birth
        )

        let age = GrowthPercentileService.ageInMonths(
            on: measurementDate,
            baby: baby,
            calendar: calendar
        )
        #expect(abs(age - (127 / 30.4375)) < 0.000_001)
    }

    // MARK: Pump rate anchor and estimates (9)

    private func pump(_ id: String, start: Date, minutes: Double = 20, ml: Double, post: Bool = false, left: Double? = nil, right: Double? = nil) throws -> PumpSession {
        try PumpSession.new(
            babyID: "b", startTime: start, durationSeconds: minutes * 60,
            leftAmountMl: left, rightAmountMl: right, totalAmountMl: ml,
            isPostNursing: post, notes: "", createdByUserID: "u", now: start, id: id
        )
    }

    private func nursing(_ id: String, start: Date, minutes: Double = 15) throws -> NursingSession {
        try NursingSession.new(
            babyID: "b", startTime: start, endTime: start.addingTimeInterval(minutes * 60),
            leftDurationSeconds: minutes * 30, rightDurationSeconds: minutes * 30,
            startingSide: .left, lastSide: .right, notes: "", createdByUserID: "u", now: start, id: id
        )
    }

    @Test func postNursingRateAnchorsToLatestRemoval() throws {
        let previousPumpEnd = date(10, 8)
        let session = try pump("post", start: date(10, 11), ml: 30, post: true)
        let feed = try nursing("n", start: date(10, 10))
        let anchor = PumpRateService.rateAnchorEndTime(
            for: session, previousPumpEndTime: previousPumpEnd, nursingSessions: [feed]
        )
        #expect(anchor == feed.endTime)

        let clean = try pump("clean", start: date(10, 11), ml: 30)
        #expect(
            PumpRateService.rateAnchorEndTime(for: clean, previousPumpEndTime: previousPumpEnd, nursingSessions: [feed])
                == previousPumpEnd
        )
    }

    @Test func anchorUsesPumpWhenItIsLaterThanNursing() throws {
        let session = try pump("post", start: date(10, 12), ml: 30, post: true)
        let feed = try nursing("n", start: date(10, 8))
        let pumpEnd = date(10, 11)
        #expect(
            PumpRateService.rateAnchorEndTime(for: session, previousPumpEndTime: pumpEnd, nursingSessions: [feed]) == pumpEnd
        )
    }

    @Test func estimateIsSplitAcrossNursingSessionsBetweenPumps() throws {
        var pumps: [PumpSession] = []
        // Clean pumps every 3h, 90 mL each => 30 mL/hr.
        for index in 0..<4 {
            pumps.append(try pump("p\(index)", start: date(10, index * 3), minutes: 0.0001 * 60, ml: 90))
        }
        let postStart = pumps[3].endTime.addingTimeInterval(3 * 3_600)
        pumps.append(try pump("post", start: postStart, minutes: 0.0001 * 60, ml: 30, post: true))
        let first = try nursing("n1", start: pumps[3].endTime.addingTimeInterval(3_600))
        let second = try nursing("n2", start: pumps[3].endTime.addingTimeInterval(2 * 3_600))

        let single = NursingEstimateService.estimates(nursingSessions: [second], pumpSessions: pumps)["n2"]
        let both = NursingEstimateService.estimates(nursingSessions: [first, second], pumpSessions: pumps)
        let total = try #require(single).averageMl
        #expect(total > 0)
        #expect(abs(try #require(both["n1"]).averageMl - total / 2) < 0.01)
        #expect(abs(try #require(both["n2"]).averageMl - total / 2) < 0.01)
    }

    @Test func currentAveragesReportTotalAndSides() throws {
        var pumps: [PumpSession] = []
        for index in 0..<4 {
            pumps.append(
                try pump("p\(index)", start: date(10, index * 2), minutes: 0.0001 * 60, ml: 60 + Double(index) * 20, left: 30 + Double(index) * 10, right: 30 + Double(index) * 10)
            )
        }
        let averages = try #require(NursingEstimateService.currentAverages(pumpSessions: pumps))
        #expect(averages.sampleCount == 3)
        let total = try #require(averages.total)
        #expect(total.lowest <= total.average && total.average <= total.highest)
        let left = try #require(averages.left)
        #expect(abs(left.average * 2 - total.average) < 0.1)
        #expect(NursingEstimateService.currentAverages(pumpSessions: Array(pumps.prefix(1))) == nil)
    }

    // MARK: Timeline feed line (4)

    @Test func feedLineSeparatesBottleAndNursingCounts() {
        var feed = TimelineFeedSummary()
        feed.count = 7
        feed.bottleCount = 2
        feed.bottleTotalMl = 266
        feed.nursingCount = 5
        feed.nursingTotalSeconds = 8_100
        let line = TimelineSummaryFormatter.feedLine(feed, unit: .milliliters)
        #expect(line.contains("2× Bottle"))
        #expect(line.contains("5× Nursing 2h 15m"))
    }

    @Test func feedLineOmitsMissingKinds() {
        var feed = TimelineFeedSummary()
        feed.count = 1
        feed.nursingCount = 1
        feed.nursingTotalSeconds = 600
        #expect(TimelineSummaryFormatter.feedLine(feed, unit: .milliliters) == "1× Nursing 10m")
        #expect(TimelineSummaryFormatter.feedLine(TimelineFeedSummary(), unit: .milliliters) == "No feed logged")
    }
}
