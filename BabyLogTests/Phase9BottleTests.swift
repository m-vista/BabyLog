import Foundation
import Testing
@testable import BabyLog

@MainActor
struct Phase9BottleTests {
    private let locale = Locale(identifier: "en_US")
    private let timestamp = Date(timeIntervalSince1970: 3_000)

    @Test func bottleModelRoundTripsAndDerivesTotal() throws {
        let feed = try makeFeed(breastMilk: 10, formula: 20, unspecified: 5)
        let data = try JSONEncoder().encode(feed)
        let decoded = try JSONDecoder().decode(BottleFeed.self, from: data)

        #expect(decoded == feed)
        #expect(decoded.totalAmountMl == 35)
    }

    @Test func breastMilkAndFormulaCalculateTotal() throws {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.left, text: "20")
        #expect(form.totalInput == "20")
        form.updateAmount(.right, text: "30")

        let amounts = try form.resolvedAmounts()

        #expect(amounts.breastMilkAmountMl == 20)
        #expect(amounts.formulaAmountMl == 30)
        #expect(amounts.unspecifiedAmountMl == 0)
        #expect(amounts.totalAmountMl == 50)
        #expect(form.calculatedField == .total)
    }

    @Test func autofillPreservesPreviousSplitOrTotalOnlyShape() throws {
        let split = makeForm(unit: .milliliters)
        split.applyAutofill(from: try makeFeed(breastMilk: 20, formula: 30, unspecified: 0))
        #expect(split.breastMilkInput == "20")
        #expect(split.formulaInput == "30")
        #expect(split.totalInput == "50")
        #expect(split.calculatedField == .total)

        let totalOnly = makeForm(unit: .milliliters)
        totalOnly.applyAutofill(from: try makeFeed(breastMilk: 0, formula: 0, unspecified: 75))
        #expect(totalOnly.breastMilkInput.isEmpty)
        #expect(totalOnly.formulaInput.isEmpty)
        #expect(totalOnly.totalInput == "75")
        #expect(totalOnly.calculatedField == nil)
    }

    @Test func breastMilkAndTotalCalculateFormula() throws {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.left, text: "20")
        form.updateAmount(.total, text: "50")

        let amounts = try form.resolvedAmounts()

        #expect(amounts.breastMilkAmountMl == 20)
        #expect(amounts.formulaAmountMl == 30)
        #expect(amounts.unspecifiedAmountMl == 0)
    }

    @Test func formulaAndTotalCalculateBreastMilk() throws {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.right, text: "30")
        form.updateAmount(.total, text: "50")

        let amounts = try form.resolvedAmounts()

        #expect(amounts.breastMilkAmountMl == 20)
        #expect(amounts.formulaAmountMl == 30)
        #expect(amounts.unspecifiedAmountMl == 0)
    }

    @Test func totalOnlyMapsToUnspecifiedWithoutInventingSplit() throws {
        let form = makeForm(unit: .milliliters)
        form.updateAmount(.total, text: "75")

        let amounts = try form.resolvedAmounts()

        #expect(amounts.breastMilkAmountMl == 0)
        #expect(amounts.formulaAmountMl == 0)
        #expect(amounts.unspecifiedAmountMl == 75)
    }

    @Test func zeroValuesAreValidAndNegativeCalculationIsRejected() throws {
        let zero = makeForm(unit: .milliliters)
        zero.updateAmount(.left, text: "0")
        zero.updateAmount(.right, text: "0")
        #expect(try zero.resolvedAmounts().totalAmountMl == 0)

        let invalid = makeForm(unit: .milliliters)
        invalid.updateAmount(.left, text: "20")
        invalid.updateAmount(.total, text: "10")
        #expect(!invalid.validate())
        #expect(invalid.validationMessage == "The calculated amount can’t be negative.")
    }

    @Test func ounceInputRoundTripsAtDisplayPrecision() throws {
        let form = makeForm(unit: .ounces)
        form.updateAmount(.total, text: "3.25")
        let amounts = try form.resolvedAmounts()

        #expect(VolumeService.displayString(
            milliliters: amounts.unspecifiedAmountMl,
            unit: .ounces,
            locale: locale
        ) == "3.25")
    }

    @Test func untouchedEditValuesRemainBitIdentical() throws {
        let original = try makeFeed(
            breastMilk: 12.345678901,
            formula: 23.456789012,
            unspecified: 0
        )
        let form = BottleFormModel(
            feed: original,
            volumeUnit: .ounces,
            locale: locale
        )
        form.notes = "Changed"

        let edited = try form.makeFeed(babyID: "ignored", userID: "ignored")

        #expect(edited.breastMilkAmountMl.bitPattern == original.breastMilkAmountMl.bitPattern)
        #expect(edited.formulaAmountMl.bitPattern == original.formulaAmountMl.bitPattern)
        #expect(edited.unspecifiedAmountMl.bitPattern == original.unspecifiedAmountMl.bitPattern)
    }

    @Test func totalOnlyEditPreservesUnspecifiedBitsWhenUntouched() throws {
        let original = try makeFeed(
            breastMilk: 0,
            formula: 0,
            unspecified: 72.345678901
        )
        let form = BottleFormModel(
            feed: original,
            volumeUnit: .ounces,
            locale: locale
        )
        form.setStartTime(timestamp.addingTimeInterval(60))

        let edited = try form.makeFeed(babyID: "ignored", userID: "ignored")

        #expect(edited.unspecifiedAmountMl.bitPattern == original.unspecifiedAmountMl.bitPattern)
        #expect(edited.breastMilkAmountMl == 0)
        #expect(edited.formulaAmountMl == 0)
    }

    @Test func formMappingPreservesEditIdentityAndMetadata() throws {
        let original = try makeFeed(breastMilk: 10, formula: 20, unspecified: 0)
        let form = BottleFormModel(
            feed: original,
            volumeUnit: .milliliters,
            locale: locale
        )
        form.notes = " Updated "

        let edited = try form.makeFeed(babyID: "other", userID: "other")

        #expect(edited.id == original.id)
        #expect(edited.babyID == original.babyID)
        #expect(edited.createdByUserID == original.createdByUserID)
        #expect(edited.createdAt == original.createdAt)
        #expect(edited.updatedAt == original.updatedAt)
        #expect(edited.notes == "Updated")
    }

    @Test func clearingFormulaAfterAutofillThenEditingBreastMilkRecalculatesCorrectly() throws {
        // Reproduces the "total becomes 6" bug: autofill 2/2/4, clear Formula, then set Breast milk to 4.
        let form = makeForm(unit: .milliliters)
        form.applyAutofill(from: try makeFeed(breastMilk: 2, formula: 2, unspecified: 0))
        form.updateAmount(.right, text: "")
        form.updateAmount(.left, text: "4")

        #expect(form.breastMilkInput == "4")
        #expect(form.formulaInput.isEmpty)
        #expect(form.totalInput == "4")
        #expect(form.calculatedField == .total)
    }

    @Test func editingBreastMilkThenClearingFormulaRecalculatesCorrectly() throws {
        // Same scenario, opposite order: edit first, then clear.
        let form = makeForm(unit: .milliliters)
        form.applyAutofill(from: try makeFeed(breastMilk: 2, formula: 2, unspecified: 0))
        form.updateAmount(.left, text: "4")
        form.updateAmount(.right, text: "")

        #expect(form.breastMilkInput == "4")
        #expect(form.formulaInput.isEmpty)
        #expect(form.totalInput == "4")
        #expect(form.calculatedField == .total)
    }

    @Test func clearingFormulaDoesNotLeaveStaleTotalCausingFalseNegativeError() throws {
        // Clearing Formula first must not freeze Total at the old autofilled value,
        // which previously caused a bogus "can't be negative" error on a later edit.
        let form = makeForm(unit: .milliliters)
        form.applyAutofill(from: try makeFeed(breastMilk: 2, formula: 2, unspecified: 0))
        form.updateAmount(.right, text: "")
        form.updateAmount(.left, text: "6")

        let amounts = try form.resolvedAmounts()
        #expect(amounts.breastMilkAmountMl == 6)
        #expect(amounts.formulaAmountMl == 0)
        #expect(form.validationMessage == nil)
    }

    @Test func autofillSelectorPicksClosestCandidateToAnchor() throws {
        let anchor = timestamp
        let near = try makeFeed(id: "near", offset: 300, breastMilk: 1, formula: 0, unspecified: 0)
        let far = try makeFeed(id: "far", offset: 3_000, breastMilk: 2, formula: 0, unspecified: 0)
        #expect(BottleAutofillSelector.closest(to: anchor, among: [far, near])?.id == "near")
    }

    @Test func autofillSelectorReturnsNilForEmptyCandidates() {
        #expect(BottleAutofillSelector.closest(to: timestamp, among: []) == nil)
    }

    @Test func autofillSelectorAcceptsOneHourBoundaryAndRejectsMoreDistantFeeds() throws {
        let boundary = try makeFeed(id: "boundary", offset: 3_600, breastMilk: 1, formula: 0, unspecified: 0)
        let outside = try makeFeed(id: "outside", offset: 3_601, breastMilk: 2, formula: 0, unspecified: 0)
        #expect(BottleAutofillSelector.closest(to: timestamp, among: [outside, boundary])?.id == "boundary")
        #expect(BottleAutofillSelector.closest(to: timestamp, among: [outside]) == nil)
    }

    private func makeForm(unit: VolumeUnit) -> BottleFormModel {
        BottleFormModel(
            volumeUnit: unit,
            locale: locale,
            now: timestamp
        )
    }

    private func makeFeed(
        breastMilk: Double,
        formula: Double,
        unspecified: Double
    ) throws -> BottleFeed {
        try makeFeed(id: "bottle-a", offset: 0, breastMilk: breastMilk, formula: formula, unspecified: unspecified)
    }

    private func makeFeed(
        id: String,
        offset: TimeInterval,
        breastMilk: Double,
        formula: Double,
        unspecified: Double
    ) throws -> BottleFeed {
        try BottleFeed(
            id: id,
            babyID: "baby-a",
            startTime: timestamp.addingTimeInterval(offset),
            breastMilkAmountMl: breastMilk,
            formulaAmountMl: formula,
            unspecifiedAmountMl: unspecified,
            notes: "Note",
            createdByUserID: "user-a",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}
