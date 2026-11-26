import Foundation

enum BottleFormError: Error, Equatable {
    case invalidAmount
    case negativeCalculatedAmount
    case missingIdentity
}

struct BottleResolvedAmounts: Equatable {
    let breastMilkAmountMl: Double
    let formulaAmountMl: Double
    let unspecifiedAmountMl: Double
    let calculatedField: AmountField?

    var totalAmountMl: Double {
        breastMilkAmountMl + formulaAmountMl + unspecifiedAmountMl
    }
}

@MainActor
@Observable
final class BottleFormModel {
    private(set) var startTime: Date
    var notes: String
    private(set) var breastMilkInput: String
    private(set) var formulaInput: String
    private(set) var totalInput: String
    private(set) var dirtyFields: Set<AmountField> = []
    private(set) var calculatedField: AmountField?
    private(set) var validationMessage: String?

    let volumeUnit: VolumeUnit
    let originalFeed: BottleFeed?

    @ObservationIgnored private let locale: Locale

    init(
        feed: BottleFeed? = nil,
        volumeUnit: VolumeUnit,
        locale: Locale = .autoupdatingCurrent,
        now: Date = .now
    ) {
        originalFeed = feed
        self.volumeUnit = volumeUnit
        self.locale = locale
        startTime = feed?.startTime ?? now
        notes = feed?.notes ?? ""

        if let feed, feed.unspecifiedAmountMl > 0,
           feed.breastMilkAmountMl == 0, feed.formulaAmountMl == 0 {
            breastMilkInput = ""
            formulaInput = ""
        } else {
            breastMilkInput = feed.map {
                VolumeService.displayString(
                    milliliters: $0.breastMilkAmountMl,
                    unit: volumeUnit,
                    locale: locale
                )
            } ?? ""
            formulaInput = feed.map {
                VolumeService.displayString(
                    milliliters: $0.formulaAmountMl,
                    unit: volumeUnit,
                    locale: locale
                )
            } ?? ""
        }

        totalInput = feed.map {
            VolumeService.displayString(
                milliliters: $0.totalAmountMl,
                unit: volumeUnit,
                locale: locale
            )
        } ?? ""
    }

    var isEditing: Bool { originalFeed != nil }

    func setStartTime(_ value: Date) {
        startTime = value
    }

    func applyAutofill(from feed: BottleFeed) {
        guard originalFeed == nil, dirtyFields.isEmpty else { return }

        if feed.unspecifiedAmountMl > 0,
           feed.breastMilkAmountMl == 0,
           feed.formulaAmountMl == 0 {
            breastMilkInput = ""
            formulaInput = ""
            totalInput = VolumeService.displayString(
                milliliters: feed.totalAmountMl,
                unit: volumeUnit,
                locale: locale
            )
            calculatedField = nil
            return
        }

        breastMilkInput = VolumeService.displayString(
            milliliters: feed.breastMilkAmountMl,
            unit: volumeUnit,
            locale: locale
        )
        formulaInput = VolumeService.displayString(
            milliliters: feed.formulaAmountMl,
            unit: volumeUnit,
            locale: locale
        )
        totalInput = VolumeService.displayString(
            milliliters: feed.totalAmountMl,
            unit: volumeUnit,
            locale: locale
        )
        calculatedField = .total
    }

    func updateAmount(_ field: AmountField, text: String) {
        if field == calculatedField {
            calculatedField = nil
        }
        setInput(text, for: field)
        dirtyFields.insert(field)
        validationMessage = nil
        recalculateIfPossible(lastEdited: field)
    }

    func resolvedAmounts() throws -> BottleResolvedAmounts {
        if let originalFeed, dirtyFields.isEmpty {
            return BottleResolvedAmounts(
                breastMilkAmountMl: originalFeed.breastMilkAmountMl,
                formulaAmountMl: originalFeed.formulaAmountMl,
                unspecifiedAmountMl: originalFeed.unspecifiedAmountMl,
                calculatedField: nil
            )
        }

        let breastMilk = try parsedValue(for: .left)
        let formula = try parsedValue(for: .right)
        let total = try parsedValue(for: .total)
        let count = [breastMilk, formula, total].compactMap { $0 }.count

        switch count {
        case 0:
            return BottleResolvedAmounts(
                breastMilkAmountMl: 0,
                formulaAmountMl: 0,
                unspecifiedAmountMl: 0,
                calculatedField: nil
            )
        case 1:
            if let total {
                return BottleResolvedAmounts(
                    breastMilkAmountMl: 0,
                    formulaAmountMl: 0,
                    unspecifiedAmountMl: try VolumeService.milliliters(from: total, unit: volumeUnit),
                    calculatedField: nil
                )
            }
            if let breastMilk {
                return BottleResolvedAmounts(
                    breastMilkAmountMl: try VolumeService.milliliters(from: breastMilk, unit: volumeUnit),
                    formulaAmountMl: 0,
                    unspecifiedAmountMl: 0,
                    calculatedField: .total
                )
            }
            return BottleResolvedAmounts(
                breastMilkAmountMl: 0,
                formulaAmountMl: try VolumeService.milliliters(from: formula ?? 0, unit: volumeUnit),
                unspecifiedAmountMl: 0,
                calculatedField: .total
            )
        default:
            let target = calculationTarget(
                breastMilk: breastMilk,
                formula: formula,
                total: total
            )
            let calculation: AmountCalculation
            do {
                calculation = try AmountCalculator.calculate(
                    left: target == .left ? nil : breastMilk,
                    right: target == .right ? nil : formula,
                    total: target == .total ? nil : total,
                    unit: volumeUnit
                )
            } catch AmountCalculatorError.negativeResult {
                throw BottleFormError.negativeCalculatedAmount
            } catch {
                throw BottleFormError.invalidAmount
            }

            return BottleResolvedAmounts(
                breastMilkAmountMl: preservedValue(
                    for: .left,
                    calculated: calculation.leftMilliliters
                ),
                formulaAmountMl: preservedValue(
                    for: .right,
                    calculated: calculation.rightMilliliters
                ),
                unspecifiedAmountMl: 0,
                calculatedField: calculation.calculatedField
            )
        }
    }

    func makeFeed(
        babyID: String,
        userID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> BottleFeed {
        guard !babyID.isEmpty, !userID.isEmpty else {
            throw BottleFormError.missingIdentity
        }
        let amounts = try resolvedAmounts()

        if let originalFeed {
            return try BottleFeed(
                id: originalFeed.id,
                babyID: originalFeed.babyID,
                startTime: startTime,
                breastMilkAmountMl: amounts.breastMilkAmountMl,
                formulaAmountMl: amounts.formulaAmountMl,
                unspecifiedAmountMl: amounts.unspecifiedAmountMl,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                createdByUserID: originalFeed.createdByUserID,
                createdAt: originalFeed.createdAt,
                updatedAt: originalFeed.updatedAt
            )
        }

        return try BottleFeed.new(
            babyID: babyID,
            startTime: startTime,
            breastMilkAmountMl: amounts.breastMilkAmountMl,
            formulaAmountMl: amounts.formulaAmountMl,
            unspecifiedAmountMl: amounts.unspecifiedAmountMl,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdByUserID: userID,
            now: now,
            id: id
        )
    }

    func validate() -> Bool {
        do {
            _ = try resolvedAmounts()
            validationMessage = nil
            return true
        } catch BottleFormError.negativeCalculatedAmount {
            validationMessage = "The calculated amount can’t be negative."
            return false
        } catch {
            validationMessage = "Check the amounts and their decimal precision."
            return false
        }
    }

    private func recalculateIfPossible(lastEdited: AmountField) {
        let values = AmountField.allCases.reduce(into: [AmountField: Decimal]()) {
            result, field in
            if field != calculatedField, let value = try? parsedValue(for: field) {
                result[field] = value
            }
        }

        if values.count == 1, let (remainingField, remainingValue) = values.first {
            if remainingField != .total {
                calculatedField = .total
                if let milliliters = try? VolumeService.milliliters(
                    from: remainingValue,
                    unit: volumeUnit
                ) {
                    setInput(
                        VolumeService.displayString(
                            milliliters: milliliters,
                            unit: volumeUnit,
                            locale: locale
                        ),
                        for: .total
                    )
                }
            } else {
                calculatedField = nil
            }
            return
        }

        guard values.count >= 2 else {
            if let calculatedField {
                setInput("", for: calculatedField)
            }
            calculatedField = nil
            return
        }

        let target: AmountField
        if values.count == 3 {
            target = lastEdited == .total ? .right : .total
        } else if values[.left] != nil, values[.right] != nil {
            target = .total
        } else if values[.left] != nil, values[.total] != nil {
            target = .right
        } else {
            target = .left
        }

        do {
            let calculation = try AmountCalculator.calculate(
                left: target == .left ? nil : values[.left],
                right: target == .right ? nil : values[.right],
                total: target == .total ? nil : values[.total],
                unit: volumeUnit
            )
            calculatedField = target
            let milliliters = switch target {
            case .left: calculation.leftMilliliters
            case .right: calculation.rightMilliliters
            case .total: calculation.totalMilliliters
            }
            setInput(
                VolumeService.displayString(
                    milliliters: milliliters,
                    unit: volumeUnit,
                    locale: locale
                ),
                for: target
            )
        } catch AmountCalculatorError.negativeResult {
            calculatedField = nil
            validationMessage = "The calculated amount can’t be negative."
        } catch {
            calculatedField = nil
            validationMessage = "Check the amounts."
        }
    }

    private func calculationTarget(
        breastMilk: Decimal?,
        formula: Decimal?,
        total: Decimal?
    ) -> AmountField {
        // Only one of the three can be genuinely missing for `AmountCalculator`
        // to accept (it requires exactly two non-nil inputs) — trust that over
        // `calculatedField`, which can be stale after the single-value shortcut
        // above leaves Total populated while a different field is now blank.
        if breastMilk == nil { return .left }
        if formula == nil { return .right }
        if total == nil { return .total }
        if let calculatedField { return calculatedField }
        if dirtyFields == [.total] { return .right }
        return .total
    }

    private func parsedValue(for field: AmountField) throws -> Decimal? {
        let text = input(for: field).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let originalFeed, !dirtyFields.contains(field) {
            let milliliters = switch field {
            case .left: originalFeed.breastMilkAmountMl
            case .right: originalFeed.formulaAmountMl
            case .total: originalFeed.totalAmountMl
            }
            return VolumeService.decimalAmount(
                fromMilliliters: milliliters,
                unit: volumeUnit
            )
        }

        do {
            return try VolumeService.parse(text, unit: volumeUnit, locale: locale)
        } catch {
            throw BottleFormError.invalidAmount
        }
    }

    private func preservedValue(for field: AmountField, calculated: Double) -> Double {
        guard let originalFeed,
              !dirtyFields.contains(field),
              field != calculatedField
        else {
            return calculated
        }

        switch field {
        case .left: return originalFeed.breastMilkAmountMl
        case .right: return originalFeed.formulaAmountMl
        case .total: return calculated
        }
    }

    private func input(for field: AmountField) -> String {
        switch field {
        case .left: breastMilkInput
        case .right: formulaInput
        case .total: totalInput
        }
    }

    private func setInput(_ text: String, for field: AmountField) {
        switch field {
        case .left: breastMilkInput = text
        case .right: formulaInput = text
        case .total: totalInput = text
        }
    }
}

/// Picks the best autofill source from a candidate list (e.g. yesterday's
/// feeds near the same time of day) by proximity to an anchor time.
enum BottleAutofillSelector {
    static func closest(
        to anchor: Date,
        among feeds: [BottleFeed],
        maximumDistance: TimeInterval = 3_600
    ) -> BottleFeed? {
        feeds
            .filter { abs($0.startTime.timeIntervalSince(anchor)) <= maximumDistance }
            .min { lhs, rhs in
                let lhsDistance = abs(lhs.startTime.timeIntervalSince(anchor))
                let rhsDistance = abs(rhs.startTime.timeIntervalSince(anchor))
                if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
                if lhs.startTime != rhs.startTime { return lhs.startTime > rhs.startTime }
                return lhs.id < rhs.id
            }
    }
}
