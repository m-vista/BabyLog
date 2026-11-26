import Foundation

enum ChecklistLogic {
    static func completionByItem(_ events: [ChecklistEvent]) -> [String: ChecklistEvent] {
        Dictionary(grouping: events, by: \.checklistItemID).compactMapValues { values in
            values.max { $0.timestamp < $1.timestamp }
        }
    }

    static func validateCustomTitle(_ title: String) throws -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ChecklistError.missingTitle }
        guard trimmed.split(whereSeparator: \.isWhitespace).count == 1 else { throw ChecklistError.titleMustBeOneWord }
        return trimmed
    }
}

@MainActor
@Observable
final class ChecklistEventFormModel {
    private(set) var timestamp: Date
    var notes: String
    let originalEvent: ChecklistEvent?

    init(event: ChecklistEvent? = nil, now: Date = .now) {
        originalEvent = event
        timestamp = event?.timestamp ?? now
        notes = event?.notes ?? ""
    }

    func setTimestamp(_ date: Date) { timestamp = date }

    func makeEvent(item: ChecklistItem, userID: String, now: Date = .now, id: String = UUID().uuidString) throws -> ChecklistEvent {
        if let originalEvent {
            return try ChecklistEvent(id: originalEvent.id, babyID: originalEvent.babyID, checklistItemID: originalEvent.checklistItemID, timestamp: timestamp, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), createdByUserID: originalEvent.createdByUserID, createdAt: originalEvent.createdAt, updatedAt: originalEvent.updatedAt)
        }
        return try ChecklistEvent.new(babyID: item.babyID, checklistItemID: item.id, timestamp: timestamp, notes: notes.trimmingCharacters(in: .whitespacesAndNewlines), createdByUserID: userID, now: now, id: id)
    }
}

@MainActor
@Observable
final class ChecklistItemFormModel {
    var title: String
    var symbol: ChecklistSymbol
    let originalItem: ChecklistItem?

    init(item: ChecklistItem? = nil) {
        originalItem = item
        title = item?.title ?? ""
        symbol = item.flatMap { ChecklistSymbol(rawValue: $0.symbol) } ?? .star
    }

    func makeItem(babyID: String, userID: String, sortOrder: Int, now: Date = .now, id: String = UUID().uuidString) throws -> ChecklistItem {
        let validTitle = try ChecklistLogic.validateCustomTitle(title)
        if let originalItem {
            return try ChecklistItem(id: originalItem.id, babyID: originalItem.babyID, title: validTitle, symbol: symbol.rawValue, sortOrder: originalItem.sortOrder, isActive: originalItem.isActive, createdByUserID: originalItem.createdByUserID, createdAt: originalItem.createdAt, updatedAt: originalItem.updatedAt)
        }
        return try ChecklistItem(id: id, babyID: babyID, title: validTitle, symbol: symbol.rawValue, sortOrder: sortOrder, isActive: true, createdByUserID: userID, createdAt: now, updatedAt: now)
    }
}
