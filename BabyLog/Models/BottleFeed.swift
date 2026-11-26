import Foundation

struct BottleFeed: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let babyID: String
    var startTime: Date
    var breastMilkAmountMl: Double
    var formulaAmountMl: Double
    var unspecifiedAmountMl: Double
    var notes: String
    let createdByUserID: String
    let createdAt: Date
    var updatedAt: Date

    var totalAmountMl: Double {
        breastMilkAmountMl + formulaAmountMl + unspecifiedAmountMl
    }

    init(
        id: String,
        babyID: String,
        startTime: Date,
        breastMilkAmountMl: Double,
        formulaAmountMl: Double,
        unspecifiedAmountMl: Double,
        notes: String,
        createdByUserID: String,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        self.id = id
        self.babyID = babyID
        self.startTime = startTime
        self.breastMilkAmountMl = breastMilkAmountMl
        self.formulaAmountMl = formulaAmountMl
        self.unspecifiedAmountMl = unspecifiedAmountMl
        self.notes = notes
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        try validate()
    }

    static func new(
        babyID: String,
        startTime: Date,
        breastMilkAmountMl: Double,
        formulaAmountMl: Double,
        unspecifiedAmountMl: Double,
        notes: String,
        createdByUserID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> BottleFeed {
        try BottleFeed(
            id: id,
            babyID: babyID,
            startTime: startTime,
            breastMilkAmountMl: breastMilkAmountMl,
            formulaAmountMl: formulaAmountMl,
            unspecifiedAmountMl: unspecifiedAmountMl,
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: now,
            updatedAt: now
        )
    }

    func updatingTimestamp(to date: Date) throws -> BottleFeed {
        try BottleFeed(
            id: id,
            babyID: babyID,
            startTime: startTime,
            breastMilkAmountMl: breastMilkAmountMl,
            formulaAmountMl: formulaAmountMl,
            unspecifiedAmountMl: unspecifiedAmountMl,
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: createdAt,
            updatedAt: date
        )
    }

    func validate() throws {
        guard !id.isEmpty else { throw BottleFeedError.missingID }
        guard !babyID.isEmpty else { throw BottleFeedError.missingBabyID }
        guard !createdByUserID.isEmpty else { throw BottleFeedError.missingCreatorID }
        guard breastMilkAmountMl.isFinite, breastMilkAmountMl >= 0,
              formulaAmountMl.isFinite, formulaAmountMl >= 0,
              unspecifiedAmountMl.isFinite, unspecifiedAmountMl >= 0
        else {
            throw BottleFeedError.invalidAmount
        }
    }
}

enum BottleFeedError: Error, Equatable {
    case missingID
    case missingBabyID
    case missingCreatorID
    case invalidAmount
}
