import Foundation

struct GrowthFormModel: Equatable {
    var timestamp: Date
    var weightText: String
    var weightOuncesText: String
    var heightText: String
    var headCircumferenceText: String
    var notes: String

    init(measurement: GrowthMeasurement? = nil, unitSystem: GrowthUnitSystem = .metric, now: Date = .now) {
        timestamp = measurement?.timestamp ?? now
        if let kilograms = measurement?.weightKilograms, unitSystem == .imperial {
            let totalPounds = kilograms * 2.204_622_6218
            let pounds = floor(totalPounds)
            weightText = Self.text(pounds)
            weightOuncesText = Self.text((totalPounds - pounds) * 16)
        } else {
            weightText = Self.text(measurement?.weightKilograms)
            weightOuncesText = ""
        }
        heightText = Self.text(measurement?.heightCentimeters.map { unitSystem == .metric ? $0 : $0 / 2.54 })
        headCircumferenceText = Self.text(measurement?.headCircumferenceCentimeters.map { unitSystem == .metric ? $0 : $0 / 2.54 })
        notes = measurement?.notes ?? ""
    }

    var canSave: Bool {
        parsedWeight != nil || parsedHeight != nil || parsedHeadCircumference != nil
    }

    var parsedWeight: Double? { Self.parse(weightText) }
    var parsedHeight: Double? { Self.parse(heightText) }
    var parsedHeadCircumference: Double? { Self.parse(headCircumferenceText) }

    func measurement(access: BabyAccess, existing: GrowthMeasurement?, unitSystem: GrowthUnitSystem = .metric) throws -> GrowthMeasurement {
        let enteredWeight = parsedWeight.map { $0 + (unitSystem == .imperial ? (Self.parse(weightOuncesText) ?? 0) / 16 : 0) }
        let weight = enteredWeight.map { unitSystem == .metric ? $0 : $0 / 2.204_622_6218 }
        let height = parsedHeight.map { unitSystem == .metric ? $0 : $0 * 2.54 }
        let head = parsedHeadCircumference.map { unitSystem == .metric ? $0 : $0 * 2.54 }
        if var existing {
            existing.timestamp = timestamp
            existing.weightKilograms = weight
            existing.heightCentimeters = height
            existing.headCircumferenceCentimeters = head
            existing.notes = notes
            try existing.validate()
            return existing
        }
        return try GrowthMeasurement.new(
            babyID: access.baby.id,
            timestamp: timestamp,
            weightKilograms: weight,
            heightCentimeters: height,
            headCircumferenceCentimeters: head,
            notes: notes,
            createdByUserID: access.membership.userID
        )
    }

    private static func parse(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: "."))
    }

    private static func text(_ value: Double?) -> String {
        guard let value else { return "" }
        return value.formatted(.number.precision(.fractionLength(0...2)))
    }
}
