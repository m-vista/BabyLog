import Foundation

struct PumpSession: Identifiable, Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id
        case babyID
        case startTime
        case durationSeconds
        case leftAmountMl
        case rightAmountMl
        case totalAmountMl
        case isPostNursing
        case notes
        case createdByUserID
        case createdAt
        case updatedAt
    }

    let id: String
    let babyID: String
    var startTime: Date
    var durationSeconds: TimeInterval
    var leftAmountMl: Double?
    var rightAmountMl: Double?
    var totalAmountMl: Double
    var isPostNursing: Bool
    var notes: String
    let createdByUserID: String
    let createdAt: Date
    var updatedAt: Date

    var sideAmountsAreSpecified: Bool {
        leftAmountMl != nil && rightAmountMl != nil
    }

    var endTime: Date {
        startTime.addingTimeInterval(durationSeconds)
    }

    init(
        id: String,
        babyID: String,
        startTime: Date,
        durationSeconds: TimeInterval,
        leftAmountMl: Double?,
        rightAmountMl: Double?,
        totalAmountMl: Double,
        isPostNursing: Bool,
        notes: String,
        createdByUserID: String,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        self.id = id
        self.babyID = babyID
        self.startTime = startTime
        self.durationSeconds = durationSeconds
        self.leftAmountMl = leftAmountMl
        self.rightAmountMl = rightAmountMl
        self.totalAmountMl = totalAmountMl
        self.isPostNursing = isPostNursing
        self.notes = notes
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        try validate()
    }

    static func new(
        babyID: String,
        startTime: Date,
        durationSeconds: TimeInterval,
        leftAmountMl: Double?,
        rightAmountMl: Double?,
        totalAmountMl: Double,
        isPostNursing: Bool,
        notes: String,
        createdByUserID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> PumpSession {
        try PumpSession(
            id: id,
            babyID: babyID,
            startTime: startTime,
            durationSeconds: durationSeconds,
            leftAmountMl: leftAmountMl,
            rightAmountMl: rightAmountMl,
            totalAmountMl: totalAmountMl,
            isPostNursing: isPostNursing,
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: now,
            updatedAt: now
        )
    }

    func updatingTimestamp(to date: Date) throws -> PumpSession {
        try PumpSession(
            id: id,
            babyID: babyID,
            startTime: startTime,
            durationSeconds: durationSeconds,
            leftAmountMl: leftAmountMl,
            rightAmountMl: rightAmountMl,
            totalAmountMl: totalAmountMl,
            isPostNursing: isPostNursing,
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: createdAt,
            updatedAt: date
        )
    }

    func validate() throws {
        guard !id.isEmpty else { throw PumpSessionError.missingID }
        guard !babyID.isEmpty else { throw PumpSessionError.missingBabyID }
        guard !createdByUserID.isEmpty else { throw PumpSessionError.missingCreatorID }
        guard durationSeconds.isFinite, durationSeconds >= 0 else {
            throw PumpSessionError.invalidDuration
        }
        guard totalAmountMl.isFinite, totalAmountMl >= 0 else {
            throw PumpSessionError.invalidAmount
        }
        guard (leftAmountMl == nil) == (rightAmountMl == nil) else {
            throw PumpSessionError.incompleteSideAmounts
        }
        if let leftAmountMl, let rightAmountMl {
            guard leftAmountMl.isFinite, leftAmountMl >= 0,
                  rightAmountMl.isFinite, rightAmountMl >= 0
            else {
                throw PumpSessionError.invalidAmount
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        babyID = try container.decode(String.self, forKey: .babyID)
        startTime = try container.decode(Date.self, forKey: .startTime)
        durationSeconds = try container.decode(TimeInterval.self, forKey: .durationSeconds)
        leftAmountMl = try container.decodeIfPresent(Double.self, forKey: .leftAmountMl)
        rightAmountMl = try container.decodeIfPresent(Double.self, forKey: .rightAmountMl)
        totalAmountMl = try container.decode(Double.self, forKey: .totalAmountMl)
        isPostNursing = try container.decode(Bool.self, forKey: .isPostNursing)
        notes = try container.decode(String.self, forKey: .notes)
        createdByUserID = try container.decode(String.self, forKey: .createdByUserID)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        try validate()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(babyID, forKey: .babyID)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        if let leftAmountMl {
            try container.encode(leftAmountMl, forKey: .leftAmountMl)
        } else {
            try container.encodeNil(forKey: .leftAmountMl)
        }
        if let rightAmountMl {
            try container.encode(rightAmountMl, forKey: .rightAmountMl)
        } else {
            try container.encodeNil(forKey: .rightAmountMl)
        }
        try container.encode(totalAmountMl, forKey: .totalAmountMl)
        try container.encode(isPostNursing, forKey: .isPostNursing)
        try container.encode(notes, forKey: .notes)
        try container.encode(createdByUserID, forKey: .createdByUserID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

enum PumpSessionError: Error, Equatable {
    case missingID
    case missingBabyID
    case missingCreatorID
    case invalidDuration
    case invalidAmount
    case incompleteSideAmounts
}
