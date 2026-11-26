import Foundation

enum DiaperType: String, Codable, CaseIterable, Sendable {
    case wet
    case dirty
    case both

    var loggingTitle: String {
        switch self {
        case .wet: "Wet"
        case .dirty: "Dirty"
        case .both: "Both"
        }
    }

    var detailTitle: String {
        self == .both ? "Wet & Dirty" : loggingTitle
    }

    var wetCount: Int {
        self == .wet || self == .both ? 1 : 0
    }

    var dirtyCount: Int {
        self == .dirty || self == .both ? 1 : 0
    }
}

enum DiaperFullness: String, Codable, CaseIterable, Sendable {
    case light
    case medium
    case heavy

    var title: String { rawValue.capitalized }
}

enum DiaperSize: String, Codable, CaseIterable, Sendable {
    case newborn = "NB"
    case one = "1"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
}

struct DiaperEvent: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let babyID: String
    var startTime: Date
    var type: DiaperType
    var fullness: DiaperFullness?
    var size: DiaperSize?
    var notes: String
    let createdByUserID: String
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        babyID: String,
        startTime: Date,
        type: DiaperType,
        fullness: DiaperFullness?,
        size: DiaperSize?,
        notes: String,
        createdByUserID: String,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        self.id = id
        self.babyID = babyID
        self.startTime = startTime
        self.type = type
        self.fullness = fullness
        self.size = size
        self.notes = notes
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        try validate()
    }

    static func new(
        babyID: String,
        startTime: Date,
        type: DiaperType,
        fullness: DiaperFullness?,
        size: DiaperSize?,
        notes: String,
        createdByUserID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> DiaperEvent {
        try DiaperEvent(
            id: id,
            babyID: babyID,
            startTime: startTime,
            type: type,
            fullness: fullness,
            size: size,
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: now,
            updatedAt: now
        )
    }

    func updatingTimestamp(to date: Date) throws -> DiaperEvent {
        try DiaperEvent(
            id: id,
            babyID: babyID,
            startTime: startTime,
            type: type,
            fullness: fullness,
            size: size,
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: createdAt,
            updatedAt: date
        )
    }

    func validate() throws {
        guard !id.isEmpty else { throw DiaperEventError.missingID }
        guard !babyID.isEmpty else { throw DiaperEventError.missingBabyID }
        guard !createdByUserID.isEmpty else { throw DiaperEventError.missingCreatorID }
    }
}

enum DiaperEventError: Error, Equatable {
    case missingID
    case missingBabyID
    case missingCreatorID
}
