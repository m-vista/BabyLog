import Foundation

enum SleepCalculator {
    static func activeSession(in openSessions: [SleepSession]) -> SleepSession? {
        openSessions.min { $0.startTime < $1.startTime }
    }

    static func sessionToStart(
        proposed: SleepSession,
        openSessions: [SleepSession]
    ) -> SleepSession {
        activeSession(in: openSessions) ?? proposed
    }

    static func extraOpenSessions(in openSessions: [SleepSession]) -> [SleepSession] {
        guard let active = activeSession(in: openSessions) else { return [] }
        return openSessions
            .filter { $0.id != active.id }
            .sorted { $0.startTime < $1.startTime }
    }

    static func excludingLocallyCompleted(
        _ completedIDs: Set<String>,
        from openSessions: [SleepSession]
    ) -> [SleepSession] {
        openSessions.filter { !completedIDs.contains($0.id) }
    }

    static func latestCompleted(in sessions: [SleepSession]) -> SleepSession? {
        sessions
            .filter { $0.endTime != nil }
            .max { left, right in
                (left.endTime ?? .distantPast) < (right.endTime ?? .distantPast)
            }
    }

    static func duration(
        of session: SleepSession,
        now: Date = .now
    ) -> TimeInterval {
        max(0, (session.endTime ?? now).timeIntervalSince(session.startTime))
    }

    static func currentAwakeDuration(
        latestCompleted: SleepSession?,
        now: Date = .now
    ) -> TimeInterval {
        guard let endTime = latestCompleted?.endTime else { return 0 }
        return max(0, now.timeIntervalSince(endTime))
    }

    static func awakeWindowBefore(
        session: SleepSession,
        previousCompleted: SleepSession?
    ) -> TimeInterval? {
        guard let previousEnd = previousCompleted?.endTime,
              previousEnd <= session.startTime
        else {
            return nil
        }
        return session.startTime.timeIntervalSince(previousEnd)
    }

    static func overlaps(
        _ candidate: SleepSession,
        sessions: [SleepSession],
        now: Date = .now
    ) -> Bool {
        let candidateEnd = candidate.endTime ?? now
        return sessions.contains { existing in
            guard existing.id != candidate.id else { return false }
            let existingEnd = existing.endTime ?? now
            return candidate.startTime < existingEnd
                && existing.startTime < candidateEnd
        }
    }
}
