import Foundation
import Testing
@testable import BabyLog

@MainActor
struct Phase11NursingTests {
    private let timestamp = Date(timeIntervalSince1970: 5_000)

    @Test func sessionDerivesTotalAndRoundTrips() throws {
        let session = try makeSession(left: 120, right: 180)
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(NursingSession.self, from: data)

        #expect(decoded == session)
        #expect(decoded.totalDurationSeconds == 300)
    }

    @Test func leftOnlyAndRightOnlyAreValid() throws {
        #expect(try makeSession(left: 120, right: 0).totalDurationSeconds == 120)
        #expect(try makeSession(left: 0, right: 90).totalDurationSeconds == 90)
    }

    @Test func invalidTimeAndDurationAreRejected() {
        #expect(throws: NursingSessionError.invalidTimeRange) {
            try NursingSession(
                id: "n",
                babyID: "b",
                startTime: timestamp,
                endTime: timestamp.addingTimeInterval(-1),
                leftDurationSeconds: 0,
                rightDurationSeconds: 0,
                startingSide: .left,
                lastSide: .left,
                notes: "",
                createdByUserID: "u",
                createdAt: timestamp,
                updatedAt: timestamp
            )
        }
        #expect(throws: NursingSessionError.invalidDuration) {
            try makeSession(left: -1, right: 0)
        }
    }

    @Test func timerPersistsStartingSideAcrossSwitches() throws {
        let clock = NursingTestClock(now: timestamp)
        let store = NursingTimerStore()
        let engine = TimerEngine(store: store, now: clock.current)

        try engine.start(
            babyID: "baby",
            timerType: .nursing,
            nursingSide: .right
        )
        clock.advance(10)
        try engine.switchNursingSide(to: .left)
        clock.advance(20)

        #expect(engine.activeState?.startingNursingSide == .right)
        #expect(engine.activeState?.activeNursingSide == .left)
        #expect(engine.nursingDurations() == NursingDurations(
            leftSeconds: 20,
            rightSeconds: 10
        ))

        let restored = TimerEngine(store: store, now: clock.current)
        try restored.restore(babyID: "baby", timerType: .nursing)
        #expect(restored.activeState?.startingNursingSide == .right)
        #expect(restored.activeState?.activeNursingSide == .left)
    }

    @Test func timerPauseResumeAndMultipleSwitchesProduceSideDurations() throws {
        let clock = NursingTestClock(now: timestamp)
        let engine = TimerEngine(
            store: NursingTimerStore(),
            now: clock.current
        )
        try engine.start(
            babyID: "baby",
            timerType: .nursing,
            nursingSide: .left
        )
        clock.advance(15)
        try engine.pause()
        clock.advance(40)
        try engine.switchNursingSide(to: .right)
        try engine.resume()
        clock.advance(25)

        #expect(engine.nursingDurations() == NursingDurations(
            leftSeconds: 15,
            rightSeconds: 25
        ))
        #expect(engine.elapsedSeconds() == 40)
    }

    @Test func stoppedTimerMapsStartingLastAndDurations() throws {
        let form = NursingFormModel(now: timestamp)
        let state = ActiveTimerState(
            babyID: "baby",
            timerType: .nursing,
            startTime: timestamp,
            startingNursingSide: .right,
            activeNursingSide: .left,
            nursingSideStartedAt: timestamp,
            leftAccumulatedSeconds: 30,
            rightAccumulatedSeconds: 45
        )
        form.applyTimerStop(
            state: state,
            durations: NursingDurations(
                leftSeconds: 30,
                rightSeconds: 45
            ),
            endTime: timestamp.addingTimeInterval(90)
        )

        let session = try form.makeSession(
            babyID: "baby",
            userID: "user",
            now: timestamp,
            id: "nursing"
        )

        #expect(session.startingSide == .right)
        #expect(session.lastSide == .left)
        #expect(session.leftDurationSeconds == 60)
        #expect(session.rightDurationSeconds == 60)
        #expect(session.endTime == timestamp.addingTimeInterval(120))
    }

    @Test func stoppedTimerRoundsHalfUpToWholeMinutes() throws {
        let form = NursingFormModel(now: timestamp)
        let state = ActiveTimerState(
            babyID: "baby",
            timerType: .nursing,
            startTime: timestamp,
            startingNursingSide: .left,
            activeNursingSide: .right,
            nursingSideStartedAt: timestamp
        )
        form.applyTimerStop(
            state: state,
            durations: NursingDurations(leftSeconds: 29, rightSeconds: 30),
            endTime: timestamp.addingTimeInterval(59)
        )

        #expect(form.leftDurationSeconds == 0)
        #expect(form.rightDurationSeconds == 60)
    }

    @Test func stoppedRestoredTimerUsesRecordedHistoricalStart() throws {
        let historicalStart = timestamp.addingTimeInterval(-7_200)
        let form = NursingFormModel(now: timestamp.addingTimeInterval(75))
        let state = ActiveTimerState(
            babyID: "baby",
            timerType: .nursing,
            startTime: timestamp,
            recordedSessionStartTime: historicalStart,
            startingNursingSide: .left,
            activeNursingSide: .left,
            leftAccumulatedSeconds: 75
        )

        form.applyTimerStop(state: state, durations: NursingDurations(leftSeconds: 75, rightSeconds: 0))
        let session = try form.makeSession(babyID: "baby", userID: "user", now: timestamp, id: "historical")

        #expect(session.startTime == historicalStart)
        #expect(session.endTime == historicalStart.addingTimeInterval(60))
    }

    @Test func finalizedEditPreservesIdentityAndMetadata() throws {
        let original = try makeSession(left: 60, right: 90)
        let form = NursingFormModel(session: original)
        form.setLeftDuration(75)
        form.notes = " Updated "

        let edited = try form.makeSession(
            babyID: "other",
            userID: "other"
        )

        #expect(edited.id == original.id)
        #expect(edited.babyID == original.babyID)
        #expect(edited.createdByUserID == original.createdByUserID)
        #expect(edited.createdAt == original.createdAt)
        #expect(edited.updatedAt == original.updatedAt)
        #expect(edited.leftDurationSeconds == 75)
        #expect(edited.notes == "Updated")
    }

    @Test func manualDurationsDeriveEndTimeFromSessionStart() throws {
        let form = NursingFormModel(now: timestamp)
        form.setStartTime(timestamp.addingTimeInterval(-3_600))
        form.setLeftDuration(120)
        form.setRightDuration(180)

        let session = try form.makeSession(
            babyID: "baby",
            userID: "user",
            now: timestamp,
            id: "manual-nursing"
        )

        #expect(session.endTime == session.startTime.addingTimeInterval(300))
    }

    private func makeSession(
        left: TimeInterval,
        right: TimeInterval
    ) throws -> NursingSession {
        try NursingSession(
            id: "nursing-a",
            babyID: "baby-a",
            startTime: timestamp,
            endTime: timestamp.addingTimeInterval(300),
            leftDurationSeconds: left,
            rightDurationSeconds: right,
            startingSide: .left,
            lastSide: .right,
            notes: "Note",
            createdByUserID: "user-a",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}

@MainActor
private final class NursingTestClock {
    private var value: Date

    init(now: Date) {
        value = now
    }

    func current() -> Date {
        value
    }

    func advance(_ seconds: TimeInterval) {
        value = value.addingTimeInterval(seconds)
    }
}

@MainActor
private final class NursingTimerStore: DurableTimerStoring {
    private var values: [String: ActiveTimerState] = [:]

    func load(
        babyID: String,
        timerType: TimerType
    ) throws -> ActiveTimerState? {
        values["\(babyID)-\(timerType.rawValue)"]
    }

    func save(_ state: ActiveTimerState) throws {
        values["\(state.babyID)-\(state.timerType.rawValue)"] = state
    }

    func remove(babyID: String, timerType: TimerType) throws {
        values.removeValue(forKey: "\(babyID)-\(timerType.rawValue)")
    }
}
