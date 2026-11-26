import Foundation

@MainActor
@Observable
final class NursingFormModel {
    private(set) var startTime: Date
    private(set) var endTime: Date
    private(set) var leftDurationSeconds: TimeInterval
    private(set) var rightDurationSeconds: TimeInterval
    private(set) var startingSide: NursingSide
    private(set) var lastSide: NursingSide
    var notes: String

    let originalSession: NursingSession?
    private(set) var hasFinishedTimer: Bool

    init(
        session: NursingSession? = nil,
        now: Date = .now
    ) {
        originalSession = session
        startTime = session?.startTime ?? now
        endTime = session?.endTime ?? now
        leftDurationSeconds = session?.leftDurationSeconds ?? 0
        rightDurationSeconds = session?.rightDurationSeconds ?? 0
        startingSide = session?.startingSide ?? .left
        lastSide = session?.lastSide ?? .left
        notes = session?.notes ?? ""
        hasFinishedTimer = session != nil
    }

    var isEditing: Bool { originalSession != nil }

    var totalDurationSeconds: TimeInterval {
        leftDurationSeconds + rightDurationSeconds
    }

    func setStartTime(_ value: Date) {
        startTime = value
        hasFinishedTimer = true
        if endTime < value {
            endTime = value.addingTimeInterval(totalDurationSeconds)
        }
    }

    func setEndTime(_ value: Date) {
        endTime = value
    }

    func setLeftDuration(_ value: TimeInterval) {
        leftDurationSeconds = max(0, value.rounded())
        endTime = startTime.addingTimeInterval(totalDurationSeconds)
        hasFinishedTimer = true
    }

    func setRightDuration(_ value: TimeInterval) {
        rightDurationSeconds = max(0, value.rounded())
        endTime = startTime.addingTimeInterval(totalDurationSeconds)
        hasFinishedTimer = true
    }

    func setStartingSide(_ side: NursingSide) {
        startingSide = side
    }

    func setLastSide(_ side: NursingSide) {
        lastSide = side
        hasFinishedTimer = true
    }

    func applyTimerStop(
        state: ActiveTimerState,
        durations: NursingDurations,
        endTime: Date = .now
    ) {
        if let recordedStart = state.recordedSessionStartTime {
            startTime = recordedStart
        }
        leftDurationSeconds = Self.roundedToWholeMinute(durations.leftSeconds)
        rightDurationSeconds = Self.roundedToWholeMinute(durations.rightSeconds)
        self.endTime = startTime.addingTimeInterval(leftDurationSeconds + rightDurationSeconds)
        startingSide = state.startingNursingSide ?? state.activeNursingSide ?? .left
        lastSide = state.activeNursingSide ?? startingSide
        hasFinishedTimer = true
    }

    private static func roundedToWholeMinute(_ seconds: TimeInterval) -> TimeInterval {
        max(0, (seconds / 60).rounded(.toNearestOrAwayFromZero) * 60)
    }

    func makeSession(
        babyID: String,
        userID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> NursingSession {
        if let originalSession {
            return try NursingSession(
                id: originalSession.id,
                babyID: originalSession.babyID,
                startTime: startTime,
                endTime: endTime,
                leftDurationSeconds: leftDurationSeconds,
                rightDurationSeconds: rightDurationSeconds,
                startingSide: startingSide,
                lastSide: lastSide,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                createdByUserID: originalSession.createdByUserID,
                createdAt: originalSession.createdAt,
                updatedAt: originalSession.updatedAt
            )
        }

        return try NursingSession.new(
            babyID: babyID,
            startTime: startTime,
            endTime: endTime,
            leftDurationSeconds: leftDurationSeconds,
            rightDurationSeconds: rightDurationSeconds,
            startingSide: startingSide,
            lastSide: lastSide,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdByUserID: userID,
            now: now,
            id: id
        )
    }
}
