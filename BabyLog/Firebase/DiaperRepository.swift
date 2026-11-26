import Foundation
import FirebaseFirestore

struct DiaperRepository {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func create(_ event: DiaperEvent) async throws {
        try event.validate()
        let data = try Firestore.Encoder().encode(event)
        try await events(babyID: event.babyID).document(event.id).setData(data)
    }

    func observe(
        babyID: String,
        interval: DateInterval
    ) -> AsyncThrowingStream<[DiaperEvent], Error> {
        AsyncThrowingStream { continuation in
            guard interval.start < interval.end else {
                continuation.finish(throwing: DiaperRepositoryError.invalidInterval)
                return
            }

            let registration = events(babyID: babyID)
                .whereField("startTime", isGreaterThanOrEqualTo: interval.start)
                .whereField("startTime", isLessThan: interval.end)
                .order(by: "startTime", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }

                    do {
                        continuation.yield(try snapshot?.documents.map {
                            try $0.data(as: DiaperEvent.self)
                        } ?? [])
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }

            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func observeLatest(babyID: String) -> AsyncThrowingStream<DiaperEvent?, Error> {
        AsyncThrowingStream { continuation in
            let registration = events(babyID: babyID).order(by: "startTime", descending: true).limit(to: 1).addSnapshotListener { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                do { continuation.yield(try snapshot?.documents.first.map { try $0.data(as: DiaperEvent.self) }) }
                catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func update(_ event: DiaperEvent, at date: Date = .now) async throws -> DiaperEvent {
        let updated = try event.updatingTimestamp(to: date)
        var data = try Firestore.Encoder().encode(updated)
        Self.removeImmutableFields(from: &data)
        try await events(babyID: updated.babyID).document(updated.id).updateData(data)
        return updated
    }

    func delete(id: String, babyID: String) async throws {
        try await events(babyID: babyID).document(id).delete()
    }

    private func events(babyID: String) -> CollectionReference {
        db.collection("babies").document(babyID).collection("diaperEvents")
    }

    private static func removeImmutableFields(from data: inout [String: Any]) {
        ["id", "babyID", "createdByUserID", "createdAt"].forEach { data.removeValue(forKey: $0) }
    }
}

enum DiaperRepositoryError: Error, Equatable {
    case invalidInterval
}
