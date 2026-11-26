import Foundation
import FirebaseFirestore

struct BottleRepository {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func create(_ feed: BottleFeed) async throws {
        try feed.validate()
        let data = try Firestore.Encoder().encode(feed)
        try await feeds(babyID: feed.babyID).document(feed.id).setData(data)
    }

    func observe(
        babyID: String,
        interval: DateInterval
    ) -> AsyncThrowingStream<[BottleFeed], Error> {
        AsyncThrowingStream { continuation in
            guard interval.start < interval.end else {
                continuation.finish(throwing: BottleRepositoryError.invalidInterval)
                return
            }

            let registration = feeds(babyID: babyID)
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
                            try $0.data(as: BottleFeed.self)
                        } ?? [])
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }

            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func observeLatest(babyID: String) -> AsyncThrowingStream<BottleFeed?, Error> {
        AsyncThrowingStream { continuation in
            let registration = feeds(babyID: babyID).order(by: "startTime", descending: true).limit(to: 1).addSnapshotListener { snapshot, error in
                if let error { continuation.finish(throwing: error); return }
                do { continuation.yield(try snapshot?.documents.first.map { try $0.data(as: BottleFeed.self) }) }
                catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func update(_ feed: BottleFeed, at date: Date = .now) async throws -> BottleFeed {
        let updated = try feed.updatingTimestamp(to: date)
        var data = try Firestore.Encoder().encode(updated)
        Self.removeImmutableFields(from: &data)
        try await feeds(babyID: updated.babyID).document(updated.id).updateData(data)
        return updated
    }

    func delete(id: String, babyID: String) async throws {
        try await feeds(babyID: babyID).document(id).delete()
    }

    private func feeds(babyID: String) -> CollectionReference {
        db.collection("babies").document(babyID).collection("bottleFeeds")
    }

    private static func removeImmutableFields(from data: inout [String: Any]) {
        ["id", "babyID", "createdByUserID", "createdAt"].forEach { data.removeValue(forKey: $0) }
    }
}

enum BottleRepositoryError: Error, Equatable {
    case invalidInterval
}
