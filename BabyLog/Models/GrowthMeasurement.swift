import Foundation

struct GrowthMeasurement: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let babyID: String
    var timestamp: Date
    var weightKilograms: Double?
    var heightCentimeters: Double?
    var headCircumferenceCentimeters: Double?
    var notes: String
    let createdByUserID: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        babyID: String,
        timestamp: Date,
        weightKilograms: Double?,
        heightCentimeters: Double?,
        headCircumferenceCentimeters: Double?,
        notes: String,
        createdByUserID: String,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        self.id = id
        self.babyID = babyID
        self.timestamp = timestamp
        self.weightKilograms = weightKilograms
        self.heightCentimeters = heightCentimeters
        self.headCircumferenceCentimeters = headCircumferenceCentimeters
        self.notes = notes
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        try validate()
    }

    static func new(
        babyID: String,
        timestamp: Date,
        weightKilograms: Double?,
        heightCentimeters: Double?,
        headCircumferenceCentimeters: Double?,
        notes: String,
        createdByUserID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> GrowthMeasurement {
        try GrowthMeasurement(
            id: id,
            babyID: babyID,
            timestamp: timestamp,
            weightKilograms: weightKilograms,
            heightCentimeters: heightCentimeters,
            headCircumferenceCentimeters: headCircumferenceCentimeters,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdByUserID: createdByUserID,
            createdAt: now,
            updatedAt: now
        )
    }

    func updating(at date: Date = .now) throws -> GrowthMeasurement {
        try GrowthMeasurement(
            id: id,
            babyID: babyID,
            timestamp: timestamp,
            weightKilograms: weightKilograms,
            heightCentimeters: heightCentimeters,
            headCircumferenceCentimeters: headCircumferenceCentimeters,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdByUserID: createdByUserID,
            createdAt: createdAt,
            updatedAt: date
        )
    }

    func validate() throws {
        guard !id.isEmpty, !babyID.isEmpty, !createdByUserID.isEmpty else {
            throw GrowthMeasurementError.missingIdentity
        }
        guard weightKilograms != nil || heightCentimeters != nil || headCircumferenceCentimeters != nil else {
            throw GrowthMeasurementError.missingMeasurement
        }
        if let weightKilograms, !(0.1...100).contains(weightKilograms) {
            throw GrowthMeasurementError.invalidWeight
        }
        if let heightCentimeters, !(10...250).contains(heightCentimeters) {
            throw GrowthMeasurementError.invalidHeight
        }
        if let headCircumferenceCentimeters, !(10...100).contains(headCircumferenceCentimeters) {
            throw GrowthMeasurementError.invalidHeadCircumference
        }
    }
}

enum GrowthMeasurementError: Error, Equatable {
    case missingIdentity
    case missingMeasurement
    case invalidWeight
    case invalidHeight
    case invalidHeadCircumference
}
