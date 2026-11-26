import Foundation
import FirebaseFirestore

struct NursingRepository {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func create(_ session: NursingSession) async throws {
        try session.validate()
        let data = try Firestore.Encoder().encode(session)
        try await sessions(babyID: session.babyID).document(session.id).setData(data)
    }

    func observe(
        babyID: String,
        interval: DateInterval
    ) -> AsyncThrowingStream<[NursingSession], Error> {
        AsyncThrowingStream { continuation in
            guard interval.start < interval.end else {
                continuation.finish(throwing: NursingRepositoryError.invalidInterval)
                return
            }

            let registration = sessions(babyID: babyID)
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
                            try $0.data(as: NursingSession.self)
                        } ?? [])
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }

            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func observeLatest(babyID: String) -> AsyncThrowingStream<NursingSession?, Error> {
        AsyncThrowingStream { continuation in
            let registration = sessions(babyID: babyID).order(by: "startTime", descending: true).limit(to: 1).addSnapshotListener { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                do { continuation.yield(try snapshot?.documents.first.map { try $0.data(as: NursingSession.self) }) }
                catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func update(
        _ session: NursingSession,
        at date: Date = .now
    ) async throws -> NursingSession {
        let updated = try session.updatingTimestamp(to: date)
        var data = try Firestore.Encoder().encode(updated)
        Self.removeImmutableFields(from: &data)
        try await sessions(babyID: updated.babyID).document(updated.id).updateData(data)
        return updated
    }

    func delete(id: String, babyID: String) async throws {
        try await sessions(babyID: babyID).document(id).delete()
    }

    private func sessions(babyID: String) -> CollectionReference {
        db.collection("babies").document(babyID).collection("nursingSessions")
    }

    private static func removeImmutableFields(from data: inout [String: Any]) {
        ["id", "babyID", "createdByUserID", "createdAt"].forEach { data.removeValue(forKey: $0) }
    }
}

enum NursingRepositoryError: Error, Equatable {
    case invalidInterval
}
