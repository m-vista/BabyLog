import Foundation

enum VolumeServiceError: Error, Equatable {
    case invalidInput
    case tooManyFractionDigits
    case negativeAmount
}

enum VolumeService {
    static let millilitersPerOunce = Decimal(string: "29.5735295625")!

    static func parse(
        _ text: String,
        unit: VolumeUnit,
        locale: Locale = .autoupdatingCurrent
    ) throws -> Decimal {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VolumeServiceError.invalidInput }

        let separator = locale.decimalSeparator ?? "."
        let normalized = separator == "." ? trimmed : trimmed.replacingOccurrences(of: separator, with: ".")
        let pieces = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= 2,
              pieces.allSatisfy({ !$0.isEmpty }),
              normalized.enumerated().allSatisfy({ index, character in
                  character.isNumber || character == "." || (index == 0 && character == "-")
              }),
              let value = Decimal(string: normalized, locale: Locale(identifier: "en_US_POSIX"))
        else {
            throw VolumeServiceError.invalidInput
        }

        let allowedFractionDigits = unit == .ounces ? 2 : 1
        if pieces.count == 2, pieces[1].count > allowedFractionDigits {
            throw VolumeServiceError.tooManyFractionDigits
        }
        guard value >= 0 else { throw VolumeServiceError.negativeAmount }
        return value
    }

    static func milliliters(from amount: Decimal, unit: VolumeUnit) throws -> Double {
        guard amount >= 0 else { throw VolumeServiceError.negativeAmount }
        let milliliters = unit == .ounces ? amount * millilitersPerOunce : amount
        return NSDecimalNumber(decimal: milliliters).doubleValue
    }

    static func decimalAmount(fromMilliliters milliliters: Double, unit: VolumeUnit) -> Decimal {
        let value = Decimal(milliliters)
        return unit == .ounces ? value / millilitersPerOunce : value
    }

    static func displayString(
        milliliters: Double,
        unit: VolumeUnit,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = unit == .ounces ? 2 : 1
        formatter.roundingMode = .halfUp

        let amount = decimalAmount(fromMilliliters: milliliters, unit: unit)
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? ""
    }

    static func storedValue(
        existingMilliliters: Double,
        isDirty: Bool,
        input: String,
        unit: VolumeUnit,
        locale: Locale = .autoupdatingCurrent
    ) throws -> Double {
        guard isDirty else { return existingMilliliters }
        return try milliliters(from: parse(input, unit: unit, locale: locale), unit: unit)
    }
}
