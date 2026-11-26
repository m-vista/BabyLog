import Foundation
import FirebaseFirestore

struct GrowthRepository {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func create(_ measurement: GrowthMeasurement) async throws {
        try measurement.validate()
        try await collection(babyID: measurement.babyID)
            .document(measurement.id)
            .setData(Firestore.Encoder().encode(measurement))
    }

    func observe(babyID: String, interval: DateInterval) -> AsyncThrowingStream<[GrowthMeasurement], Error> {
        AsyncThrowingStream { continuation in
            guard interval.start < interval.end else {
                continuation.finish(throwing: GrowthRepositoryError.invalidInterval)
                return
            }
            let registration = collection(babyID: babyID)
                .whereField("timestamp", isGreaterThanOrEqualTo: interval.start)
                .whereField("timestamp", isLessThan: interval.end)
                .order(by: "timestamp", descending: true)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    do {
                        continuation.yield(try snapshot?.documents.map { try $0.data(as: GrowthMeasurement.self) } ?? [])
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func observeAll(babyID: String) -> AsyncThrowingStream<[GrowthMeasurement], Error> {
        AsyncThrowingStream { continuation in
            let registration = collection(babyID: babyID)
                .order(by: "timestamp")
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    do {
                        continuation.yield(try snapshot?.documents.map { try $0.data(as: GrowthMeasurement.self) } ?? [])
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func observeLatest(babyID: String) -> AsyncThrowingStream<GrowthMeasurement?, Error> {
        AsyncThrowingStream { continuation in
            let registration = collection(babyID: babyID)
                .order(by: "timestamp", descending: true)
                .limit(to: 1)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    do {
                        continuation.yield(try snapshot?.documents.first?.data(as: GrowthMeasurement.self))
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func update(_ measurement: GrowthMeasurement, at date: Date = .now) async throws -> GrowthMeasurement {
        let updated = try measurement.updating(at: date)
        var data = try Firestore.Encoder().encode(updated)
        Self.removeImmutableFields(from: &data)
        try await collection(babyID: updated.babyID)
            .document(updated.id)
            .updateData(data)
        return updated
    }

    func delete(id: String, babyID: String) async throws {
        try await collection(babyID: babyID).document(id).delete()
    }

    private func collection(babyID: String) -> CollectionReference {
        db.collection("babies").document(babyID).collection("growthMeasurements")
    }

    private static func removeImmutableFields(from data: inout [String: Any]) {
        ["id", "babyID", "createdByUserID", "createdAt"].forEach { data.removeValue(forKey: $0) }
    }
}

enum GrowthRepositoryError: Error, Equatable {
    case invalidInterval
}
