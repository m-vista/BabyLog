import Foundation

enum TimerType: String, Codable, CaseIterable, Sendable {
    case pump
    case nursing
}

enum NursingSide: String, Codable, CaseIterable, Sendable {
    case left
    case right
}

struct ActiveTimerState: Codable, Equatable, Sendable {
    let babyID: String
    let timerType: TimerType
    let startTime: Date
    var recordedSessionStartTime: Date?
    var isPaused: Bool
    var pauseStartedAt: Date?
    var accumulatedPausedSeconds: TimeInterval
    var startingNursingSide: NursingSide?
    var activeNursingSide: NursingSide?
    var nursingSideStartedAt: Date?
    var leftAccumulatedSeconds: TimeInterval
    var rightAccumulatedSeconds: TimeInterval

    init(
        babyID: String,
        timerType: TimerType,
        startTime: Date,
        recordedSessionStartTime: Date? = nil,
        isPaused: Bool = false,
        pauseStartedAt: Date? = nil,
        accumulatedPausedSeconds: TimeInterval = 0,
        startingNursingSide: NursingSide? = nil,
        activeNursingSide: NursingSide? = nil,
        nursingSideStartedAt: Date? = nil,
        leftAccumulatedSeconds: TimeInterval = 0,
        rightAccumulatedSeconds: TimeInterval = 0
    ) {
        self.babyID = babyID
        self.timerType = timerType
        self.startTime = startTime
        self.recordedSessionStartTime = recordedSessionStartTime
        self.isPaused = isPaused
        self.pauseStartedAt = pauseStartedAt
        self.accumulatedPausedSeconds = accumulatedPausedSeconds
        self.startingNursingSide = startingNursingSide
        self.activeNursingSide = activeNursingSide
        self.nursingSideStartedAt = nursingSideStartedAt
        self.leftAccumulatedSeconds = leftAccumulatedSeconds
        self.rightAccumulatedSeconds = rightAccumulatedSeconds
    }
}

struct NursingDurations: Equatable, Sendable {
    let leftSeconds: TimeInterval
    let rightSeconds: TimeInterval
}
