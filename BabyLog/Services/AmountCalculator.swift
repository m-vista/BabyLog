import Foundation

enum AmountField: CaseIterable, Sendable {
    case left
    case right
    case total
}

struct AmountCalculation: Equatable, Sendable {
    let leftMilliliters: Double
    let rightMilliliters: Double
    let totalMilliliters: Double
    let calculatedField: AmountField
}

enum AmountCalculatorError: Error, Equatable {
    case requiresExactlyTwoInputs
    case negativeResult
}

enum AmountCalculator {
    private static let zeroTolerance = Decimal(string: "0.000000001")!

    static func calculate(
        left: Decimal?,
        right: Decimal?,
        total: Decimal?,
        unit: VolumeUnit
    ) throws -> AmountCalculation {
        let suppliedCount = [left, right, total].compactMap { $0 }.count
        guard suppliedCount == 2 else {
            throw AmountCalculatorError.requiresExactlyTwoInputs
        }

        var resolvedLeft = left
        var resolvedRight = right
        var resolvedTotal = total
        let calculatedField: AmountField

        if resolvedLeft == nil {
            resolvedLeft = try nonNegative((resolvedTotal ?? 0) - (resolvedRight ?? 0))
            calculatedField = .left
        } else if resolvedRight == nil {
            resolvedRight = try nonNegative((resolvedTotal ?? 0) - (resolvedLeft ?? 0))
            calculatedField = .right
        } else {
            resolvedTotal = (resolvedLeft ?? 0) + (resolvedRight ?? 0)
            calculatedField = .total
        }

        return AmountCalculation(
            leftMilliliters: try VolumeService.milliliters(from: resolvedLeft ?? 0, unit: unit),
            rightMilliliters: try VolumeService.milliliters(from: resolvedRight ?? 0, unit: unit),
            totalMilliliters: try VolumeService.milliliters(from: resolvedTotal ?? 0, unit: unit),
            calculatedField: calculatedField
        )
    }

    private static func nonNegative(_ value: Decimal) throws -> Decimal {
        if value < 0 {
            if abs(value) <= zeroTolerance {
                return 0
            }
            throw AmountCalculatorError.negativeResult
        }
        return value <= zeroTolerance ? 0 : value
    }
}
