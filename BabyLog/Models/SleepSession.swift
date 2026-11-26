import Foundation

struct SleepSession: Identifiable, Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case id
        case babyID
        case startTime
        case endTime
        case notes
        case soothingTimes = "nightWakings"
        case createdByUserID
        case createdAt
        case updatedAt
    }

    let id: String
    let babyID: String
    var startTime: Date
    var endTime: Date?
    var notes: String
    var soothingTimes: [Date]
    let createdByUserID: String
    let createdAt: Date
    var updatedAt: Date

    var durationSeconds: TimeInterval? {
        endTime.map { max(0, $0.timeIntervalSince(startTime)) }
    }

    var isOpen: Bool { endTime == nil }

    init(
        id: String,
        babyID: String,
        startTime: Date,
        endTime: Date?,
        soothingTimes: [Date] = [],
        notes: String,
        createdByUserID: String,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        self.id = id
        self.babyID = babyID
        self.startTime = startTime
        self.endTime = endTime
        self.notes = notes
        self.soothingTimes = soothingTimes
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        try validate()
    }

    static func new(
        babyID: String,
        startTime: Date,
        endTime: Date?,
        soothingTimes: [Date] = [],
        notes: String,
        createdByUserID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> SleepSession {
        try SleepSession(
            id: id,
            babyID: babyID,
            startTime: startTime,
            endTime: endTime,
            soothingTimes: soothingTimes,
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: now,
            updatedAt: now
        )
    }

    func updatingTimestamp(to date: Date) throws -> SleepSession {
        try SleepSession(
            id: id,
            babyID: babyID,
            startTime: startTime,
            endTime: endTime,
            soothingTimes: soothingTimes,
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: createdAt,
            updatedAt: date
        )
    }

    func addingSoothing(at date: Date = .now) throws -> SleepSession {
        try SleepSession(
            id: id,
            babyID: babyID,
            startTime: startTime,
            endTime: endTime,
            soothingTimes: soothingTimes + [date],
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: createdAt,
            updatedAt: date
        )
    }

    func validate() throws {
        guard !id.isEmpty else { throw SleepSessionError.missingID }
        guard !babyID.isEmpty else { throw SleepSessionError.missingBabyID }
        guard !createdByUserID.isEmpty else { throw SleepSessionError.missingCreatorID }
        if let endTime {
            guard endTime > startTime else {
                throw SleepSessionError.invalidTimeRange
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        babyID = try container.decode(String.self, forKey: .babyID)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decodeIfPresent(Date.self, forKey: .endTime)
        notes = try container.decode(String.self, forKey: .notes)
        soothingTimes = try container.decodeIfPresent([Date].self, forKey: .soothingTimes) ?? []
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
        if let endTime {
            try container.encode(endTime, forKey: .endTime)
        } else {
            try container.encodeNil(forKey: .endTime)
        }
        try container.encode(notes, forKey: .notes)
        try container.encode(soothingTimes, forKey: .soothingTimes)
        try container.encode(createdByUserID, forKey: .createdByUserID)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

enum SleepSessionError: Error, Equatable {
    case missingID
    case missingBabyID
    case missingCreatorID
    case invalidTimeRange
}
