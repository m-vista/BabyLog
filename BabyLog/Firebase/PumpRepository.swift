import Foundation
import FirebaseFirestore

struct PumpRepository {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func create(_ session: PumpSession) async throws {
        try session.validate()
        let data = try Firestore.Encoder().encode(session)
        try await sessions(babyID: session.babyID)
            .document(session.id)
            .setData(data)
    }

    func observe(
        babyID: String,
        interval: DateInterval
    ) -> AsyncThrowingStream<[PumpSession], Error> {
        AsyncThrowingStream { continuation in
            guard interval.start < interval.end else {
                continuation.finish(throwing: PumpRepositoryError.invalidInterval)
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
                        let values = try snapshot?.documents.map {
                            try $0.data(as: PumpSession.self)
                        } ?? []
                        continuation.yield(values)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }

            continuation.onTermination = { _ in
                registration.remove()
            }
        }
    }

    func observeLatest(babyID: String) -> AsyncThrowingStream<PumpSession?, Error> {
        AsyncThrowingStream { continuation in
            let registration = sessions(babyID: babyID).order(by: "startTime", descending: true).limit(to: 1).addSnapshotListener { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                do { continuation.yield(try snapshot?.documents.first.map { try $0.data(as: PumpSession.self) }) }
                catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func update(_ session: PumpSession, at date: Date = .now) async throws -> PumpSession {
        let updated = try session.updatingTimestamp(to: date)
        var data = try Firestore.Encoder().encode(updated)
        Self.removeImmutableFields(from: &data)
        try await sessions(babyID: updated.babyID)
            .document(updated.id)
            .updateData(data)
        return updated
    }

    func delete(id: String, babyID: String) async throws {
        try await sessions(babyID: babyID).document(id).delete()
    }

    /// The single most recent session strictly before `startTime`, for
    /// computing production rate anchored to the previous pump. Single-field
    /// range + order on `startTime` — no composite index required.
    func fetchSessionImmediatelyBefore(
        babyID: String,
        startTime: Date,
        excludingID: String? = nil
    ) async throws -> PumpSession? {
        let snapshot = try await sessions(babyID: babyID)
            .whereField("startTime", isLessThan: startTime)
            .order(by: "startTime", descending: true)
            .limit(to: excludingID == nil ? 1 : 2)
            .getDocuments()
        return try snapshot.documents
            .map { try $0.data(as: PumpSession.self) }
            .first { $0.id != excludingID }
    }

    /// The newest `limit` sessions, oldest first. Single-field order — no composite index.
    func fetchRecent(babyID: String, limit: Int) async throws -> [PumpSession] {
        let snapshot = try await sessions(babyID: babyID)
            .order(by: "startTime", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents
            .map { try $0.data(as: PumpSession.self) }
            .reversed()
    }

    private func sessions(babyID: String) -> CollectionReference {
        db.collection("babies").document(babyID).collection("pumpSessions")
    }

    private static func removeImmutableFields(from data: inout [String: Any]) {
        ["id", "babyID", "createdByUserID", "createdAt"].forEach { data.removeValue(forKey: $0) }
    }
}

enum PumpRepositoryError: Error, Equatable {
    case invalidInterval
}
