import Foundation

struct ChecklistEvent: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let babyID: String
    let checklistItemID: String
    var timestamp: Date
    var notes: String
    let createdByUserID: String
    let createdAt: Date
    var updatedAt: Date

    init(id: String, babyID: String, checklistItemID: String, timestamp: Date, notes: String, createdByUserID: String, createdAt: Date, updatedAt: Date) throws {
        self.id = id
        self.babyID = babyID
        self.checklistItemID = checklistItemID
        self.timestamp = timestamp
        self.notes = notes
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        try validate()
    }

    static func new(babyID: String, checklistItemID: String, timestamp: Date, notes: String, createdByUserID: String, now: Date = .now, id: String = UUID().uuidString) throws -> ChecklistEvent {
        try ChecklistEvent(id: id, babyID: babyID, checklistItemID: checklistItemID, timestamp: timestamp, notes: notes, createdByUserID: createdByUserID, createdAt: now, updatedAt: now)
    }

    func updatingTimestamp(to date: Date) throws -> ChecklistEvent {
        try ChecklistEvent(id: id, babyID: babyID, checklistItemID: checklistItemID, timestamp: timestamp, notes: notes, createdByUserID: createdByUserID, createdAt: createdAt, updatedAt: date)
    }

    func validate() throws {
        guard !id.isEmpty, !babyID.isEmpty, !checklistItemID.isEmpty, !createdByUserID.isEmpty else { throw ChecklistError.missingIdentity }
    }
}
