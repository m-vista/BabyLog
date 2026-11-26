import Foundation

enum GrowthFormat {
    nonisolated static func summary(
        _ measurement: GrowthMeasurement,
        unitSystem: GrowthUnitSystem = .metric
    ) -> String {
        var parts: [String] = []
        if let value = measurement.weightKilograms {
            if unitSystem == .metric {
                parts.append("\(number(value)) kg")
            } else {
                let totalPounds = value * 2.204_622_6218
                let pounds = Int(totalPounds)
                let ounces = (totalPounds - Double(pounds)) * 16
                parts.append("\(pounds) lb \(number(ounces)) oz")
            }
        }
        if let value = measurement.heightCentimeters {
            let displayed = unitSystem == .metric ? value : value / 2.54
            parts.append("\(number(displayed)) \(unitSystem == .metric ? "cm" : "in")")
        }
        if let value = measurement.headCircumferenceCentimeters {
            let displayed = unitSystem == .metric ? value : value / 2.54
            parts.append("Head \(number(displayed)) \(unitSystem == .metric ? "cm" : "in")")
        }
        return parts.joined(separator: " · ")
    }

    nonisolated static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
