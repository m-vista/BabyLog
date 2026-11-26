import Foundation

enum PumpFormError: Error, Equatable {
    case invalidAmount
    case negativeCalculatedAmount
    case invalidDuration
    case missingIdentity
}

struct PumpResolvedAmounts: Equatable {
    let leftAmountMl: Double?
    let rightAmountMl: Double?
    let totalAmountMl: Double
    let calculatedField: AmountField?
}

@MainActor
@Observable
final class PumpFormModel {
    private(set) var startTime: Date
    private(set) var durationSeconds: TimeInterval
    var isPostNursing: Bool
    var notes: String

    private(set) var leftInput: String
    private(set) var rightInput: String
    private(set) var totalInput: String
    private(set) var dirtyFields: Set<AmountField> = []
    private(set) var calculatedField: AmountField?
    private(set) var validationMessage: String?

    let volumeUnit: VolumeUnit
    let originalSession: PumpSession?

    @ObservationIgnored private let locale: Locale

    init(
        session: PumpSession? = nil,
        volumeUnit: VolumeUnit,
        rememberedDurationSeconds: TimeInterval = 0,
        locale: Locale = .autoupdatingCurrent,
        now: Date = .now
    ) {
        self.originalSession = session
        self.volumeUnit = volumeUnit
        self.locale = locale
        self.startTime = session?.startTime ?? now
        self.durationSeconds = session?.durationSeconds ?? max(0, rememberedDurationSeconds)
        self.isPostNursing = session?.isPostNursing ?? false
        self.notes = session?.notes ?? ""
        self.leftInput = session?.leftAmountMl.map {
            VolumeService.displayString(milliliters: $0, unit: volumeUnit, locale: locale)
        } ?? ""
        self.rightInput = session?.rightAmountMl.map {
            VolumeService.displayString(milliliters: $0, unit: volumeUnit, locale: locale)
        } ?? ""
        self.totalInput = session.map {
            VolumeService.displayString(milliliters: $0.totalAmountMl, unit: volumeUnit, locale: locale)
        } ?? ""
    }

    var isEditing: Bool { originalSession != nil }

    func setStartTime(_ value: Date) {
        startTime = value
    }

    func setDuration(seconds: TimeInterval) {
        durationSeconds = max(0, seconds.rounded())
        validationMessage = nil
    }

    func applyTimerStop(startTime: Date, measuredDuration: TimeInterval) {
        self.startTime = startTime
        setDuration(seconds: measuredDuration)
    }

    func updateAmount(_ field: AmountField, text: String) {
        guard field != calculatedField else { return }
        setInput(text, for: field)
        dirtyFields.insert(field)
        validationMessage = nil
        recalculateIfPossible(lastEdited: field)
    }

    func resolvedAmounts() throws -> PumpResolvedAmounts {
        if let originalSession, dirtyFields.isEmpty {
            return PumpResolvedAmounts(
                leftAmountMl: originalSession.leftAmountMl,
                rightAmountMl: originalSession.rightAmountMl,
                totalAmountMl: originalSession.totalAmountMl,
                calculatedField: nil
            )
        }

        let left = try parsedValue(for: .left)
        let right = try parsedValue(for: .right)
        let total = try parsedValue(for: .total)
        let supplied = [AmountField.left: left, .right: right, .total: total].compactMapValues { $0 }

        switch supplied.count {
        case 0:
            return PumpResolvedAmounts(
                leftAmountMl: nil,
                rightAmountMl: nil,
                totalAmountMl: 0,
                calculatedField: nil
            )
        case 1:
            if let total {
                return PumpResolvedAmounts(
                    leftAmountMl: nil,
                    rightAmountMl: nil,
                    totalAmountMl: try VolumeService.milliliters(from: total, unit: volumeUnit),
                    calculatedField: nil
                )
            }
            if let left {
                let value = try VolumeService.milliliters(from: left, unit: volumeUnit)
                return PumpResolvedAmounts(
                    leftAmountMl: value,
                    rightAmountMl: 0,
                    totalAmountMl: value,
                    calculatedField: .total
                )
            }
            let value = try VolumeService.milliliters(from: right ?? 0, unit: volumeUnit)
            return PumpResolvedAmounts(
                leftAmountMl: 0,
                rightAmountMl: value,
                totalAmountMl: value,
                calculatedField: .total
            )
        default:
            let fieldToCalculate = calculationTarget(left: left, right: right, total: total)
            let calculation: AmountCalculation
            do {
                switch fieldToCalculate {
                case .left:
                    calculation = try AmountCalculator.calculate(left: nil, right: right, total: total, unit: volumeUnit)
                case .right:
                    calculation = try AmountCalculator.calculate(left: left, right: nil, total: total, unit: volumeUnit)
                case .total:
                    calculation = try AmountCalculator.calculate(left: left, right: right, total: nil, unit: volumeUnit)
                }
            } catch AmountCalculatorError.negativeResult {
                throw PumpFormError.negativeCalculatedAmount
            } catch {
                throw PumpFormError.invalidAmount
            }

            return PumpResolvedAmounts(
                leftAmountMl: preservedValue(for: .left, calculated: calculation.leftMilliliters),
                rightAmountMl: preservedValue(for: .right, calculated: calculation.rightMilliliters),
                totalAmountMl: preservedValue(for: .total, calculated: calculation.totalMilliliters) ?? calculation.totalMilliliters,
                calculatedField: calculation.calculatedField
            )
        }
    }

    func makeSession(
        babyID: String,
        userID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> PumpSession {
        guard !babyID.isEmpty, !userID.isEmpty else { throw PumpFormError.missingIdentity }
        guard durationSeconds.isFinite, durationSeconds >= 0 else { throw PumpFormError.invalidDuration }
        let amounts = try resolvedAmounts()

        if let originalSession {
            return try PumpSession(
                id: originalSession.id,
                babyID: originalSession.babyID,
                startTime: startTime,
                durationSeconds: durationSeconds,
                leftAmountMl: amounts.leftAmountMl,
                rightAmountMl: amounts.rightAmountMl,
                totalAmountMl: amounts.totalAmountMl,
                isPostNursing: isPostNursing,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                createdByUserID: originalSession.createdByUserID,
                createdAt: originalSession.createdAt,
                updatedAt: originalSession.updatedAt
            )
        }

        return try PumpSession.new(
            babyID: babyID,
            startTime: startTime,
            durationSeconds: durationSeconds,
            leftAmountMl: amounts.leftAmountMl,
            rightAmountMl: amounts.rightAmountMl,
            totalAmountMl: amounts.totalAmountMl,
            isPostNursing: isPostNursing,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdByUserID: userID,
            now: now,
            id: id
        )
    }

    func validate() -> Bool {
        do {
            _ = try resolvedAmounts()
            guard durationSeconds.isFinite, durationSeconds >= 0 else {
                validationMessage = "Enter a valid duration."
                return false
            }
            validationMessage = nil
            return true
        } catch PumpFormError.negativeCalculatedAmount {
            validationMessage = "The calculated amount can’t be negative."
            return false
        } catch {
            validationMessage = "Check the amounts and their decimal precision."
            return false
        }
    }

    private func recalculateIfPossible(lastEdited: AmountField) {
        let values = AmountField.allCases.reduce(into: [AmountField: Decimal]()) { result, field in
            if field != calculatedField, let value = try? parsedValue(for: field) {
                result[field] = value
            }
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
            let result = try AmountCalculator.calculate(
                left: target == .left ? nil : values[.left],
                right: target == .right ? nil : values[.right],
                total: target == .total ? nil : values[.total],
                unit: volumeUnit
            )
            calculatedField = target
            let milliliters: Double = switch target {
            case .left: result.leftMilliliters
            case .right: result.rightMilliliters
            case .total: result.totalMilliliters
            }
            setInput(
                VolumeService.displayString(milliliters: milliliters, unit: volumeUnit, locale: locale),
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

    private func calculationTarget(left: Decimal?, right: Decimal?, total: Decimal?) -> AmountField {
        if let calculatedField { return calculatedField }
        if left == nil { return .left }
        if right == nil { return .right }
        if total == nil { return .total }
        if dirtyFields == [.total] { return .right }
        return .total
    }

    private func parsedValue(for field: AmountField) throws -> Decimal? {
        let text = input(for: field).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let originalSession, !dirtyFields.contains(field) {
            let milliliters: Double? = switch field {
            case .left: originalSession.leftAmountMl
            case .right: originalSession.rightAmountMl
            case .total: originalSession.totalAmountMl
            }
            if let milliliters {
                return VolumeService.decimalAmount(fromMilliliters: milliliters, unit: volumeUnit)
            }
        }

        do {
            return try VolumeService.parse(text, unit: volumeUnit, locale: locale)
        } catch {
            throw PumpFormError.invalidAmount
        }
    }

    private func preservedValue(for field: AmountField, calculated: Double) -> Double? {
        guard let originalSession, !dirtyFields.contains(field), field != calculatedField else {
            return calculated
        }
        switch field {
        case .left: return originalSession.leftAmountMl
        case .right: return originalSession.rightAmountMl
        case .total: return originalSession.totalAmountMl
        }
    }

    private func input(for field: AmountField) -> String {
        switch field {
        case .left: leftInput
        case .right: rightInput
        case .total: totalInput
        }
    }

    private func setInput(_ text: String, for field: AmountField) {
        switch field {
        case .left: leftInput = text
        case .right: rightInput = text
        case .total: totalInput = text
        }
    }
}
