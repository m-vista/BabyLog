import Foundation

struct NursingSession: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let babyID: String
    var startTime: Date
    var endTime: Date
    var leftDurationSeconds: TimeInterval
    var rightDurationSeconds: TimeInterval
    var startingSide: NursingSide
    var lastSide: NursingSide
    var notes: String
    let createdByUserID: String
    let createdAt: Date
    var updatedAt: Date

    var totalDurationSeconds: TimeInterval {
        leftDurationSeconds + rightDurationSeconds
    }

    init(
        id: String,
        babyID: String,
        startTime: Date,
        endTime: Date,
        leftDurationSeconds: TimeInterval,
        rightDurationSeconds: TimeInterval,
        startingSide: NursingSide,
        lastSide: NursingSide,
        notes: String,
        createdByUserID: String,
        createdAt: Date,
        updatedAt: Date
    ) throws {
        self.id = id
        self.babyID = babyID
        self.startTime = startTime
        self.endTime = endTime
        self.leftDurationSeconds = leftDurationSeconds
        self.rightDurationSeconds = rightDurationSeconds
        self.startingSide = startingSide
        self.lastSide = lastSide
        self.notes = notes
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        try validate()
    }

    static func new(
        babyID: String,
        startTime: Date,
        endTime: Date,
        leftDurationSeconds: TimeInterval,
        rightDurationSeconds: TimeInterval,
        startingSide: NursingSide,
        lastSide: NursingSide,
        notes: String,
        createdByUserID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> NursingSession {
        try NursingSession(
            id: id,
            babyID: babyID,
            startTime: startTime,
            endTime: endTime,
            leftDurationSeconds: leftDurationSeconds,
            rightDurationSeconds: rightDurationSeconds,
            startingSide: startingSide,
            lastSide: lastSide,
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: now,
            updatedAt: now
        )
    }

    func updatingTimestamp(to date: Date) throws -> NursingSession {
        try NursingSession(
            id: id,
            babyID: babyID,
            startTime: startTime,
            endTime: endTime,
            leftDurationSeconds: leftDurationSeconds,
            rightDurationSeconds: rightDurationSeconds,
            startingSide: startingSide,
            lastSide: lastSide,
            notes: notes,
            createdByUserID: createdByUserID,
            createdAt: createdAt,
            updatedAt: date
        )
    }

    func validate() throws {
        guard !id.isEmpty else { throw NursingSessionError.missingID }
        guard !babyID.isEmpty else { throw NursingSessionError.missingBabyID }
        guard !createdByUserID.isEmpty else { throw NursingSessionError.missingCreatorID }
        guard endTime >= startTime else { throw NursingSessionError.invalidTimeRange }
        guard leftDurationSeconds.isFinite, leftDurationSeconds >= 0,
              rightDurationSeconds.isFinite, rightDurationSeconds >= 0
        else {
            throw NursingSessionError.invalidDuration
        }
    }
}

enum NursingSessionError: Error, Equatable {
    case missingID
    case missingBabyID
    case missingCreatorID
    case invalidTimeRange
    case invalidDuration
}
