import Foundation

enum TimerEngineError: Error, Equatable {
    case timerAlreadyActive
    case noActiveTimer
    case invalidNursingSide
    case invalidPersistedState
}

@MainActor
@Observable
final class TimerEngine {
    private(set) var activeState: ActiveTimerState?

    @ObservationIgnored
    private let store: any DurableTimerStoring
    @ObservationIgnored
    private let now: () -> Date

    init(
        store: any DurableTimerStoring = DurableTimerStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.now = now
    }

    @discardableResult
    func restore(babyID: String, timerType: TimerType) throws -> ActiveTimerState? {
        let restored = try store.load(babyID: babyID, timerType: timerType)
        if let restored {
            try Self.validate(restored)
        }
        activeState = restored
        return restored
    }

    func start(
        babyID: String,
        timerType: TimerType,
        nursingSide: NursingSide? = nil,
        recordedSessionStartTime: Date? = nil
    ) throws {
        guard activeState == nil else { throw TimerEngineError.timerAlreadyActive }

        let timestamp = now()
        let side: NursingSide?
        switch timerType {
        case .pump:
            guard nursingSide == nil else { throw TimerEngineError.invalidNursingSide }
            side = nil
        case .nursing:
            guard let nursingSide else { throw TimerEngineError.invalidNursingSide }
            side = nursingSide
        }

        let state = ActiveTimerState(
            babyID: babyID,
            timerType: timerType,
            startTime: timestamp,
            recordedSessionStartTime: recordedSessionStartTime,
            startingNursingSide: side,
            activeNursingSide: side,
            nursingSideStartedAt: side == nil ? nil : timestamp
        )
        try store.save(state)
        activeState = state
    }

    func pause() throws {
        var state = try requireActiveState()
        guard !state.isPaused else { return }

        let timestamp = now()
        accrueNursingSegment(in: &state, through: timestamp)
        state.isPaused = true
        state.pauseStartedAt = timestamp
        state.nursingSideStartedAt = nil
        try persist(state)
    }

    func resume() throws {
        var state = try requireActiveState()
        guard state.isPaused, let pauseStartedAt = state.pauseStartedAt else { return }

        let timestamp = now()
        state.accumulatedPausedSeconds += max(0, timestamp.timeIntervalSince(pauseStartedAt))
        state.isPaused = false
        state.pauseStartedAt = nil
        if state.timerType == .nursing {
            state.nursingSideStartedAt = timestamp
        }
        try persist(state)
    }

    func switchNursingSide(to side: NursingSide) throws {
        var state = try requireActiveState()
        guard state.timerType == .nursing, state.activeNursingSide != nil else {
            throw TimerEngineError.invalidNursingSide
        }
        guard state.activeNursingSide != side else { return }

        let timestamp = now()
        if !state.isPaused {
            accrueNursingSegment(in: &state, through: timestamp)
            state.nursingSideStartedAt = timestamp
        }
        state.activeNursingSide = side
        try persist(state)
    }

    func elapsedSeconds(at date: Date? = nil) -> TimeInterval {
        guard let state = activeState else { return 0 }
        let reference = state.isPaused ? (state.pauseStartedAt ?? state.startTime) : (date ?? now())
        return max(
            0,
            reference.timeIntervalSince(state.startTime) - state.accumulatedPausedSeconds
        )
    }

    func nursingDurations(at date: Date? = nil) -> NursingDurations? {
        guard let state = activeState, state.timerType == .nursing else { return nil }

        var left = state.leftAccumulatedSeconds
        var right = state.rightAccumulatedSeconds
        if !state.isPaused,
           let side = state.activeNursingSide,
           let sideStartedAt = state.nursingSideStartedAt {
            let segment = max(0, (date ?? now()).timeIntervalSince(sideStartedAt))
            if side == .left {
                left += segment
            } else {
                right += segment
            }
        }
        return NursingDurations(leftSeconds: left, rightSeconds: right)
    }

    @discardableResult
    func finish() throws -> ActiveTimerState {
        var state = try requireActiveState()
        if !state.isPaused {
            accrueNursingSegment(in: &state, through: now())
        }
        try store.remove(babyID: state.babyID, timerType: state.timerType)
        activeState = nil
        return state
    }

    func discard() throws {
        let state = try requireActiveState()
        try store.remove(babyID: state.babyID, timerType: state.timerType)
        activeState = nil
    }

    private func requireActiveState() throws -> ActiveTimerState {
        guard let activeState else { throw TimerEngineError.noActiveTimer }
        return activeState
    }

    private func persist(_ state: ActiveTimerState) throws {
        try store.save(state)
        activeState = state
    }

    private func accrueNursingSegment(in state: inout ActiveTimerState, through date: Date) {
        guard state.timerType == .nursing,
              let side = state.activeNursingSide,
              let sideStartedAt = state.nursingSideStartedAt
        else {
            return
        }

        let seconds = max(0, date.timeIntervalSince(sideStartedAt))
        if side == .left {
            state.leftAccumulatedSeconds += seconds
        } else {
            state.rightAccumulatedSeconds += seconds
        }
    }

    private static func validate(_ state: ActiveTimerState) throws {
        guard state.accumulatedPausedSeconds >= 0,
              state.leftAccumulatedSeconds >= 0,
              state.rightAccumulatedSeconds >= 0,
              state.isPaused == (state.pauseStartedAt != nil)
        else {
            throw TimerEngineError.invalidPersistedState
        }

        switch state.timerType {
        case .pump:
            guard state.startingNursingSide == nil,
                  state.activeNursingSide == nil,
                  state.nursingSideStartedAt == nil,
                  state.leftAccumulatedSeconds == 0,
                  state.rightAccumulatedSeconds == 0
            else {
                throw TimerEngineError.invalidPersistedState
            }
        case .nursing:
            guard state.activeNursingSide != nil,
                  state.isPaused || state.nursingSideStartedAt != nil
            else {
                throw TimerEngineError.invalidPersistedState
            }
        }
    }
}
