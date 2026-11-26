import Foundation
import Testing
@testable import BabyLog

@MainActor
struct Phase8PumpFormTests {
    private let locale = Locale(identifier: "en_US")
    private let timestamp = Date(timeIntervalSince1970: 2_000)

    @Test func totalOnlyKeepsSidesUnspecified() throws {
        let form = makeForm()
        form.updateAmount(.total, text: "2.5")

        let amounts = try form.resolvedAmounts()

        #expect(amounts.leftAmountMl == nil)
        #expect(amounts.rightAmountMl == nil)
        #expect(amounts.totalAmountMl == 73.93382390625)
    }

    @Test func leftOnlyMakesRightKnownZero() throws {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.left, text: "40")

        let amounts = try form.resolvedAmounts()

        #expect(amounts.leftAmountMl == 40)
        #expect(amounts.rightAmountMl == 0)
        #expect(amounts.totalAmountMl == 40)
    }

    @Test func rightOnlyMakesLeftKnownZero() throws {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.right, text: "35")

        let amounts = try form.resolvedAmounts()

        #expect(amounts.leftAmountMl == 0)
        #expect(amounts.rightAmountMl == 35)
        #expect(amounts.totalAmountMl == 35)
    }

    @Test func leftAndRightCalculateTotal() throws {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.left, text: "10.5")
        form.updateAmount(.right, text: "20.5")

        let amounts = try form.resolvedAmounts()

        #expect(form.calculatedField == .total)
        #expect(amounts.totalAmountMl == 31)
    }

    @Test func leftAndTotalCalculateRight() throws {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.left, text: "10")
        form.updateAmount(.total, text: "25")

        let amounts = try form.resolvedAmounts()

        #expect(form.calculatedField == .right)
        #expect(amounts.rightAmountMl == 15)
    }

    @Test func rightAndTotalCalculateLeft() throws {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.right, text: "8")
        form.updateAmount(.total, text: "20")

        let amounts = try form.resolvedAmounts()

        #expect(form.calculatedField == .left)
        #expect(amounts.leftAmountMl == 12)
    }

    @Test func negativeCalculatedValueIsInvalid() {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.left, text: "20")
        form.updateAmount(.total, text: "10")

        #expect(!form.validate())
        #expect(form.validationMessage == "The calculated amount can’t be negative.")
    }

    @Test func allZeroEntryIsValid() throws {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.left, text: "0")
        form.updateAmount(.right, text: "0")

        let session = try form.makeSession(babyID: "baby", userID: "user", now: timestamp, id: "zero")

        #expect(session.leftAmountMl == 0)
        #expect(session.rightAmountMl == 0)
        #expect(session.totalAmountMl == 0)
    }

    @Test func selectedUnitConvertsOnlyAtStorageBoundary() throws {
        let form = makeForm(unit: .ounces)
        form.updateAmount(.left, text: "1.25")

        let amounts = try form.resolvedAmounts()

        #expect(amounts.leftAmountMl == 36.966911953125)
        #expect(amounts.rightAmountMl == 0)
        #expect(amounts.totalAmountMl == 36.966911953125)
    }

    @Test func untouchedEditAmountsRemainBitIdentical() throws {
        let original = try existingSession(
            left: 12.345678901234,
            right: 23.456789012345,
            total: 35.802467913579
        )
        let form = PumpFormModel(session: original, volumeUnit: .ounces, locale: locale)
        form.notes = "Only the note changed"

        let updated = try form.makeSession(babyID: "ignored", userID: "ignored")

        #expect(try #require(updated.leftAmountMl).bitPattern == #require(original.leftAmountMl).bitPattern)
        #expect(try #require(updated.rightAmountMl).bitPattern == #require(original.rightAmountMl).bitPattern)
        #expect(updated.totalAmountMl.bitPattern == original.totalAmountMl.bitPattern)
    }

    @Test func changingTotalPreservesUntouchedLeftBitsAndRecalculatesRight() throws {
        let original = try existingSession(
            left: 12.345678901234,
            right: 23.456789012345,
            total: 35.802467913579
        )
        let form = PumpFormModel(session: original, volumeUnit: .milliliters, locale: locale)
        form.updateAmount(.total, text: "50")

        let updated = try form.makeSession(babyID: "ignored", userID: "ignored")

        #expect(try #require(updated.leftAmountMl).bitPattern == #require(original.leftAmountMl).bitPattern)
        #expect(abs(try #require(updated.rightAmountMl) - 37.654321098766) < 1e-12)
        #expect(updated.totalAmountMl == 50)
    }

    @Test func manualDurationMapsToSession() throws {
        let form = makeForm(unit: .milliliters)
        form.setDuration(seconds: 754)
        form.updateAmount(.total, text: "60")

        let session = try form.makeSession(babyID: "baby", userID: "user", now: timestamp, id: "manual")

        #expect(session.durationSeconds == 754)
    }

    @Test func timerDurationAndStartTimeMapToSession() throws {
        let form = makeForm(unit: .milliliters)
        let timerStart = timestamp.addingTimeInterval(-900)
        form.applyTimerStop(startTime: timerStart, measuredDuration: 615.4)
        form.updateAmount(.total, text: "30")

        let session = try form.makeSession(babyID: "baby", userID: "user", now: timestamp, id: "timer")

        #expect(session.startTime == timerStart)
        #expect(session.durationSeconds == 615)
    }

    @Test func stoppedTimerDurationCanBeAdjusted() {
        let form = makeForm()
        form.applyTimerStop(startTime: timestamp, measuredDuration: 610)
        form.setDuration(seconds: 600)

        #expect(form.durationSeconds == 600)
    }

    @Test func postNursingAndMetadataMapToSession() throws {
        let form = makeForm(unit: .milliliters)
        form.isPostNursing = true
        form.notes = "  Finished after nursing  "
        form.setStartTime(timestamp)
        form.updateAmount(.right, text: "42")

        let session = try form.makeSession(babyID: "baby", userID: "user", now: timestamp, id: "mapped")

        #expect(session.id == "mapped")
        #expect(session.babyID == "baby")
        #expect(session.createdByUserID == "user")
        #expect(session.isPostNursing)
        #expect(session.notes == "Finished after nursing")
        #expect(session.leftAmountMl == 0)
        #expect(session.rightAmountMl == 42)
        #expect(session.totalAmountMl == 42)
    }

    private func makeForm(unit: VolumeUnit = .ounces) -> PumpFormModel {
        PumpFormModel(
            volumeUnit: unit,
            rememberedDurationSeconds: 300,
            locale: locale,
            now: timestamp
        )
    }

    private func existingSession(left: Double?, right: Double?, total: Double) throws -> PumpSession {
        try PumpSession(
            id: "existing",
            babyID: "baby",
            startTime: timestamp,
            durationSeconds: 600,
            leftAmountMl: left,
            rightAmountMl: right,
            totalAmountMl: total,
            isPostNursing: false,
            notes: "Original",
            createdByUserID: "creator",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}
