import Foundation
import FirebaseFirestore

struct SleepRepository {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    func create(_ session: SleepSession) async throws {
        try session.validate()
        try await write(session)
    }

    func startIfNeeded(_ proposed: SleepSession, now: Date = .now) async throws -> SleepSession {
        let open = try await openSessions(babyID: proposed.babyID)
        let selected = SleepCalculator.sessionToStart(
            proposed: proposed,
            openSessions: open
        )
        guard selected.id == proposed.id else {
            return selected
        }

        let candidates = try await overlapCandidates(
            babyID: proposed.babyID,
            endingBefore: proposed.endTime ?? now
        )
        guard !SleepCalculator.overlaps(proposed, sessions: candidates, now: now) else {
            throw SleepRepositoryError.overlappingSession
        }
        try await write(proposed)
        return proposed
    }

    func observeOpenSessions(
        babyID: String
    ) -> AsyncThrowingStream<[SleepSession], Error> {
        stream(
            query: sessions(babyID: babyID)
                .whereField("endTime", isEqualTo: NSNull())
        )
    }

    func observeLatestCompleted(
        babyID: String
    ) -> AsyncThrowingStream<SleepSession?, Error> {
        AsyncThrowingStream { continuation in
            let registration = sessions(babyID: babyID)
                .whereField("endTime", isNotEqualTo: NSNull())
                .order(by: "endTime", descending: true)
                .limit(to: 1)
                .addSnapshotListener { snapshot, error in
                    if let error {
                        continuation.finish(throwing: error)
                        return
                    }
                    do {
                        let value = try snapshot?.documents.first.map {
                            try $0.data(as: SleepSession.self)
                        }
                        continuation.yield(value)
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    func observe(
        babyID: String,
        interval: DateInterval
    ) -> AsyncThrowingStream<[SleepSession], Error> {
        guard interval.start < interval.end else {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: SleepRepositoryError.invalidInterval)
            }
        }
        return stream(
            query: sessions(babyID: babyID)
                .whereField("startTime", isGreaterThanOrEqualTo: interval.start)
                .whereField("startTime", isLessThan: interval.end)
                .order(by: "startTime", descending: true)
        )
    }

    /// The sole session immediately preceding a bounded Calendar window.
    /// Sleep sessions cannot overlap, so this is sufficient to draw a sleep
    /// that begins before the window and continues into its first day.
    func fetchSessionImmediatelyBefore(
        babyID: String,
        startTime: Date
    ) async throws -> SleepSession? {
        let snapshot = try await sessions(babyID: babyID)
            .whereField("startTime", isLessThan: startTime)
            .order(by: "startTime", descending: true)
            .limit(to: 1)
            .getDocuments()
        return try snapshot.documents.first.map { try $0.data(as: SleepSession.self) }
    }

    func update(
        _ session: SleepSession,
        at date: Date = .now
    ) async throws -> SleepSession {
        let updated = try session.updatingTimestamp(to: date)
        let candidates = try await overlapCandidates(
            babyID: updated.babyID,
            endingBefore: updated.endTime ?? date
        )
        guard !SleepCalculator.overlaps(
            updated,
            sessions: candidates,
            now: date
        ) else {
            throw SleepRepositoryError.overlappingSession
        }
        try await updateMutableFields(updated)
        return updated
    }

    func delete(id: String, babyID: String) async throws {
        try await sessions(babyID: babyID).document(id).delete()
    }

    private func openSessions(babyID: String) async throws -> [SleepSession] {
        let snapshot = try await sessions(babyID: babyID)
            .whereField("endTime", isEqualTo: NSNull())
            .getDocuments()
        return try snapshot.documents.map {
            try $0.data(as: SleepSession.self)
        }
    }

    private func overlapCandidates(
        babyID: String,
        endingBefore end: Date
    ) async throws -> [SleepSession] {
        let snapshot = try await sessions(babyID: babyID)
            .whereField("startTime", isLessThan: end)
            .order(by: "startTime", descending: true)
            .limit(to: 100)
            .getDocuments()
        return try snapshot.documents.map {
            try $0.data(as: SleepSession.self)
        }
    }

    private func write(_ session: SleepSession) async throws {
        let data = try Firestore.Encoder().encode(session)
        try await sessions(babyID: session.babyID)
            .document(session.id)
            .setData(data)
    }

    private func updateMutableFields(_ session: SleepSession) async throws {
        let endTime: Any = session.endTime.map(Timestamp.init(date:)) ?? NSNull()
        try await sessions(babyID: session.babyID)
            .document(session.id)
            .updateData([
                "startTime": Timestamp(date: session.startTime),
                "endTime": endTime,
                "notes": session.notes,
                "nightWakings": session.soothingTimes.map(Timestamp.init(date:)),
                "updatedAt": Timestamp(date: session.updatedAt)
            ])
    }

    private func stream(
        query: Query
    ) -> AsyncThrowingStream<[SleepSession], Error> {
        AsyncThrowingStream { continuation in
            let registration = query.addSnapshotListener { snapshot, error in
                if let error {
                    continuation.finish(throwing: error)
                    return
                }
                do {
                    continuation.yield(try snapshot?.documents.map {
                        try $0.data(as: SleepSession.self)
                    } ?? [])
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }

    private func sessions(babyID: String) -> CollectionReference {
        db.collection("babies").document(babyID).collection("sleepSessions")
    }
}

enum SleepRepositoryError: Error, Equatable {
    case invalidInterval
    case overlappingSession
}
