import Foundation
import FirebaseFirestore

struct ChecklistRepository {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) { self.db = db }

    func seedDefaultsIfNeeded(babyID: String, userID: String, now: Date = .now) async throws {
        let existing = try await items(babyID: babyID).limit(to: 1).getDocuments()
        guard existing.documents.isEmpty else { return }
        let batch = db.batch()
        for (index, template) in ChecklistItem.commonTemplates.enumerated() {
            let item = try ChecklistItem(id: template.id, babyID: babyID, title: template.title, symbol: template.symbol.rawValue, sortOrder: index, isActive: true, createdByUserID: userID, createdAt: now, updatedAt: now)
            batch.setData(try Firestore.Encoder().encode(item), forDocument: items(babyID: babyID).document(item.id))
        }
        try await batch.commit()
    }

    func createItem(_ item: ChecklistItem) async throws {
        try item.validate()
        try await items(babyID: item.babyID).document(item.id).setData(Firestore.Encoder().encode(item))
    }

    func observeItems(babyID: String, includeInactive: Bool = false) -> AsyncThrowingStream<[ChecklistItem], Error> {
        AsyncThrowingStream { continuation in
            let registration = items(babyID: babyID).order(by: "sortOrder").addSnapshotListener { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                do {
                    let values = try snapshot?.documents.map { try $0.data(as: ChecklistItem.self) } ?? []
                    continuation.yield(includeInactive ? values : values.filter(\.isActive))
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func updateItem(_ item: ChecklistItem, at date: Date = .now) async throws {
        var updated = item
        updated.updatedAt = date
        try updated.validate()
        var data = try Firestore.Encoder().encode(updated)
        Self.removeImmutableFields(from: &data)
        try await items(babyID: item.babyID).document(item.id).updateData(data)
    }

    func reorder(_ orderedItems: [ChecklistItem], at date: Date = .now) async throws {
        let batch = db.batch()
        for (index, item) in orderedItems.enumerated() {
            var updated = item
            updated.sortOrder = index
            updated.updatedAt = date
            try updated.validate()
            var data = try Firestore.Encoder().encode(updated)
            Self.removeImmutableFields(from: &data)
            batch.updateData(data, forDocument: items(babyID: item.babyID).document(item.id))
        }
        try await batch.commit()
    }

    func createEvent(_ event: ChecklistEvent) async throws {
        try event.validate()
        try await events(babyID: event.babyID).document(event.id).setData(Firestore.Encoder().encode(event))
    }

    func observeEvents(babyID: String, interval: DateInterval) -> AsyncThrowingStream<[ChecklistEvent], Error> {
        AsyncThrowingStream { continuation in
            guard interval.start < interval.end else { continuation.finish(throwing: ChecklistRepositoryError.invalidInterval); return }
            let registration = events(babyID: babyID)
                .whereField("timestamp", isGreaterThanOrEqualTo: interval.start)
                .whereField("timestamp", isLessThan: interval.end)
                .order(by: "timestamp", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error { continuation.finish(throwing: error); return }
                    do { continuation.yield(try snapshot?.documents.map { try $0.data(as: ChecklistEvent.self) } ?? []) }
                    catch { continuation.finish(throwing: error) }
                }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func updateEvent(_ event: ChecklistEvent, at date: Date = .now) async throws -> ChecklistEvent {
        let updated = try event.updatingTimestamp(to: date)
        var data = try Firestore.Encoder().encode(updated)
        Self.removeImmutableFields(from: &data)
        try await events(babyID: event.babyID).document(event.id).updateData(data)
        return updated
    }

    func deleteEvent(id: String, babyID: String) async throws { try await events(babyID: babyID).document(id).delete() }

    private func items(babyID: String) -> CollectionReference { db.collection("babies").document(babyID).collection("checklistItems") }
    private func events(babyID: String) -> CollectionReference { db.collection("babies").document(babyID).collection("checklistEvents") }

    private static func removeImmutableFields(from data: inout [String: Any]) {
        ["id", "babyID", "createdByUserID", "createdAt"].forEach { data.removeValue(forKey: $0) }
    }
}

enum ChecklistRepositoryError: Error, Equatable { case invalidInterval }
