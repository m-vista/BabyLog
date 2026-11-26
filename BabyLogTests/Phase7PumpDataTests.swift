import Foundation
import Testing
@testable import BabyLog

@MainActor
struct Phase7PumpDataTests {
    private let timestamp = Date(timeIntervalSince1970: 1_000)

    @Test func pumpSessionUsesStableFirestoreFieldNamesAndRoundTrips() throws {
        let session = try makeSession(
            leftAmountMl: 12.345678901,
            rightAmountMl: 23.456789012
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(session)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(Set(object.keys) == [
            "id", "babyID", "startTime", "durationSeconds", "leftAmountMl",
            "rightAmountMl", "totalAmountMl", "isPostNursing", "notes", "createdByUserID",
            "createdAt", "updatedAt"
        ])
        #expect(object["leftAmountMl"] as? Double == session.leftAmountMl)
        #expect(object["rightAmountMl"] as? Double == session.rightAmountMl)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(PumpSession.self, from: data)
        #expect(decoded == session)
        #expect(try #require(decoded.leftAmountMl).bitPattern == #require(session.leftAmountMl).bitPattern)
        #expect(try #require(decoded.rightAmountMl).bitPattern == #require(session.rightAmountMl).bitPattern)
        #expect(decoded.totalAmountMl.bitPattern == session.totalAmountMl.bitPattern)
    }

    @Test func newSessionUsesClientIDAndMatchingCreationTimestamps() throws {
        let first = try makeSession(id: UUID().uuidString)
        let second = try PumpSession.new(
            babyID: "baby-a",
            startTime: timestamp,
            durationSeconds: 60,
            leftAmountMl: 0,
            rightAmountMl: 0,
            totalAmountMl: 0,
            isPostNursing: false,
            notes: "",
            createdByUserID: "user-a",
            now: timestamp
        )

        #expect(UUID(uuidString: first.id) != nil)
        #expect(UUID(uuidString: second.id) != nil)
        #expect(first.id != second.id)
        #expect(second.createdAt == timestamp)
        #expect(second.updatedAt == timestamp)
    }

    @Test func updateChangesOnlyMutableValuesAndUpdatedTimestamp() throws {
        var edited = try makeSession()
        let original = edited
        edited.notes = "Updated note"
        edited.leftAmountMl = 48.7654321
        let updateTime = timestamp.addingTimeInterval(500)

        let updated = try edited.updatingTimestamp(to: updateTime)

        #expect(updated.id == original.id)
        #expect(updated.babyID == original.babyID)
        #expect(updated.createdByUserID == original.createdByUserID)
        #expect(updated.createdAt == original.createdAt)
        #expect(updated.updatedAt == updateTime)
        #expect(updated.notes == "Updated note")
        #expect(try #require(updated.leftAmountMl).bitPattern == #require(edited.leftAmountMl).bitPattern)
        #expect(try #require(updated.rightAmountMl).bitPattern == #require(original.rightAmountMl).bitPattern)
    }

    @Test func validationAllowsAllZeroEntryAndRejectsInvalidValues() throws {
        _ = try makeSession(durationSeconds: 0, leftAmountMl: 0, rightAmountMl: 0)

        #expect(throws: PumpSessionError.invalidDuration) {
            try makeSession(durationSeconds: -1)
        }
        #expect(throws: PumpSessionError.invalidAmount) {
            try makeSession(leftAmountMl: -0.1)
        }
        #expect(throws: PumpSessionError.invalidAmount) {
            try makeSession(rightAmountMl: .infinity)
        }
        #expect(throws: PumpSessionError.incompleteSideAmounts) {
            try makeSession(leftAmountMl: nil, rightAmountMl: 10, totalAmountMl: 10)
        }
    }

    @Test func totalOnlyEntryPreservesUnspecifiedSides() throws {
        let totalOnly = try makeSession(
            leftAmountMl: nil,
            rightAmountMl: nil,
            totalAmountMl: 72.3456789
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(totalOnly)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(totalOnly.leftAmountMl == nil)
        #expect(totalOnly.rightAmountMl == nil)
        #expect(!totalOnly.sideAmountsAreSpecified)
        #expect(totalOnly.totalAmountMl == 72.3456789)
        #expect(object["leftAmountMl"] is NSNull)
        #expect(object["rightAmountMl"] is NSNull)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let decoded = try decoder.decode(PumpSession.self, from: data)
        #expect(decoded == totalOnly)
    }

    @Test func amountPairsCalculateMissingField() throws {
        try expectCalculation(left: 1, right: 2, total: nil, field: .total, totalMl: 3)
        try expectCalculation(left: 1, right: nil, total: 3, field: .right, totalMl: 3)
        try expectCalculation(left: nil, right: 2, total: 3, field: .left, totalMl: 3)
    }

    @Test func amountCalculationHandlesZeroAndRejectsNegativeResult() throws {
        let zero = try AmountCalculator.calculate(
            left: 0,
            right: 0,
            total: nil,
            unit: .milliliters
        )
        #expect(zero.leftMilliliters == 0)
        #expect(zero.rightMilliliters == 0)
        #expect(zero.totalMilliliters == 0)

        #expect(throws: AmountCalculatorError.negativeResult) {
            try AmountCalculator.calculate(
                left: 10,
                right: nil,
                total: 5,
                unit: .milliliters
            )
        }
    }

    @Test func rateUsesTimeBetweenConsecutiveSessionEndTimes() throws {
        let previous = try makeSession(
            id: "previous",
            startTime: timestamp,
            durationSeconds: 600,
            totalAmountMl: 30
        )
        let session = try makeSession(
            id: "current",
            startTime: timestamp.addingTimeInterval(2_400),
            durationSeconds: 1_800,
            leftAmountMl: 29.5735295625,
            rightAmountMl: 29.5735295625
        )

        // Previous end = t+10m, current end = t+70m, so 2 oz / 1h = 2 oz/hr.
        let rate = try #require(PumpRateService.sessionRate(session, previousSessionEndTime: previous.endTime))
        #expect(rate == 59.147059125)
        #expect(VolumeService.displayString(milliliters: rate, unit: .ounces) == "2")
    }

    @Test func groupRateUsesPreviousEndToLastGroupEnd() {
        let rate = PumpRateService.groupRate(
            totalAmountMl: 180,
            lastEndTime: timestamp.addingTimeInterval(7_200),
            previousGroupEndTime: timestamp
        )
        #expect(rate == 90)
    }

    @Test func firstPumpAndNonPositiveIntervalHaveNoRate() throws {
        let session = try makeSession(durationSeconds: 0)
        #expect(PumpRateService.sessionRate(session, previousSessionEndTime: nil) == nil)
        #expect(PumpRateService.sessionRate(session, previousSessionEndTime: session.endTime) == nil)
    }

    @Test func previousSessionUsesLatestEarlierStartAndExcludesEditedSession() throws {
        let early = try makeSession(id: "early", startTime: timestamp)
        let edited = try makeSession(id: "edited", startTime: timestamp.addingTimeInterval(600))
        let later = try makeSession(id: "later", startTime: timestamp.addingTimeInterval(1_200))
        let result = PumpRateService.previousSession(
            before: later.startTime.addingTimeInterval(1),
            excluding: later.id,
            in: [later, early, edited]
        )
        #expect(result?.id == "edited")
    }

    @Test func weightedCleanRateUsesBlocksSeparatedByPostNursingPumps() throws {
        let prior = try makeSession(id: "prior", startTime: timestamp, durationSeconds: 0, totalAmountMl: 10)
        let cleanOne = try makeSession(id: "clean-1", startTime: timestamp.addingTimeInterval(3_600), durationSeconds: 0, totalAmountMl: 60)
        let cleanTwo = try makeSession(id: "clean-2", startTime: timestamp.addingTimeInterval(7_200), durationSeconds: 0, totalAmountMl: 60)
        let post = try makeSession(id: "post", startTime: timestamp.addingTimeInterval(9_000), durationSeconds: 0, totalAmountMl: 10, isPostNursing: true)
        let cleanThree = try makeSession(id: "clean-3", startTime: timestamp.addingTimeInterval(12_600), durationSeconds: 0, totalAmountMl: 30)

        let rate = PumpRateService.weightedCleanRate(
            sessions: [cleanThree, cleanTwo, post, cleanOne],
            sessionImmediatelyBeforeRange: prior
        )

        // Block one: 120 mL / 2 h. Block two: 30 mL / 1 h.
        // Weighted across three clean elapsed hours: 150 mL / 3 h.
        #expect(rate == 50)
    }

    @Test func nursingEstimateUsesLastFiveCleanRatesForAverageAndRange() throws {
        let amounts = [10.0, 600.0, 20.0, 40.0, 60.0, 80.0, 100.0]
        var pumps = try amounts.enumerated().map { index, amount in
            try makeSession(
                id: "clean-\(index)",
                startTime: timestamp.addingTimeInterval(Double(index) * 3_600),
                durationSeconds: 0,
                totalAmountMl: amount
            )
        }
        let nursing = try NursingSession(
            id: "nursing-estimate", babyID: "baby-a",
            startTime: timestamp.addingTimeInterval(6.25 * 3_600),
            endTime: timestamp.addingTimeInterval(6.5 * 3_600),
            leftDurationSeconds: 900, rightDurationSeconds: 0,
            startingSide: .left, lastSide: .left, notes: "",
            createdByUserID: "user-a", createdAt: timestamp, updatedAt: timestamp
        )
        pumps.append(try makeSession(
            id: "post", startTime: timestamp.addingTimeInterval(7 * 3_600),
            durationSeconds: 0, totalAmountMl: 20, isPostNursing: true
        ))

        let estimate = NursingEstimateService.estimates(
            nursingSessions: [nursing], pumpSessions: pumps
        )[nursing.id]
        #expect(estimate == NursingEstimate(averageMl: 40, minimumMl: 0, maximumMl: 80))
        #expect(
            TimelineRowFormatter.nursing(nursing, estimate: estimate, unit: .milliliters).secondary
                == "L 15m · R 0m · Est. 40 mL (0–80 mL)"
        )

        pumps[pumps.count - 1] = try makeSession(
            id: "post", startTime: timestamp.addingTimeInterval(7 * 3_600),
            durationSeconds: 0, totalAmountMl: 120, isPostNursing: true
        )
        #expect(
            NursingEstimateService.estimates(nursingSessions: [nursing], pumpSessions: pumps)[nursing.id]
                == NursingEstimate(averageMl: 0, minimumMl: 0, maximumMl: 0)
        )
    }

    @Test func onlyFirstPumpAfterNursingGetsPostNursingDefault() throws {
        let nursing = try NursingSession(
            id: "nursing", babyID: "baby-a", startTime: timestamp,
            endTime: timestamp.addingTimeInterval(600),
            leftDurationSeconds: 300, rightDurationSeconds: 300,
            startingSide: .left, lastSide: .right, notes: "",
            createdByUserID: "user-a", createdAt: timestamp, updatedAt: timestamp
        )
        #expect(PumpPostNursingDefaultService.shouldDefaultOn(latestNursing: nursing, latestPump: nil))

        let firstPump = try makeSession(
            startTime: timestamp.addingTimeInterval(86_400), durationSeconds: 60
        )
        #expect(!PumpPostNursingDefaultService.shouldDefaultOn(latestNursing: nursing, latestPump: firstPump))
    }

    private func makeSession(
        id: String = "pump-a",
        startTime: Date? = nil,
        durationSeconds: TimeInterval = 600,
        leftAmountMl: Double? = 20,
        rightAmountMl: Double? = 30,
        totalAmountMl: Double? = nil,
        isPostNursing: Bool = false
    ) throws -> PumpSession {
        try PumpSession(
            id: id,
            babyID: "baby-a",
            startTime: startTime ?? timestamp,
            durationSeconds: durationSeconds,
            leftAmountMl: leftAmountMl,
            rightAmountMl: rightAmountMl,
            totalAmountMl: totalAmountMl ?? ((leftAmountMl ?? 0) + (rightAmountMl ?? 0)),
            isPostNursing: isPostNursing,
            notes: "Note",
            createdByUserID: "user-a",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }

    private func expectCalculation(
        left: Decimal?,
        right: Decimal?,
        total: Decimal?,
        field: AmountField,
        totalMl: Double
    ) throws {
        let result = try AmountCalculator.calculate(
            left: left,
            right: right,
            total: total,
            unit: .milliliters
        )
        #expect(result.calculatedField == field)
        #expect(result.totalMilliliters == totalMl)
    }
}
