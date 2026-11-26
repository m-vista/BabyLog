import Foundation
import Testing
@testable import BabyLog

@MainActor
struct Phase5TimerEngineTests {
    @Test func timerTypeSupportsExactlyPumpAndNursing() {
        #expect(TimerType.allCases == [.pump, .nursing])
    }

    @Test func backgroundAndForegroundReconstructElapsedTime() throws {
        let fixture = Fixture()
        try fixture.engine.start(babyID: "baby", timerType: .pump)

        fixture.clock.advance(by: 125)

        #expect(fixture.engine.elapsedSeconds() == 125)
    }

    @Test func tabSwitchDoesNotAffectElapsedTime() throws {
        let fixture = Fixture()
        try fixture.engine.start(babyID: "baby", timerType: .pump)

        fixture.clock.advance(by: 40)
        _ = fixture.engine.activeState
        fixture.clock.advance(by: 20)

        #expect(fixture.engine.elapsedSeconds() == 60)
    }

    @Test func sheetCloseAndReopenRestoresSameElapsedTime() throws {
        let clock = TestClock()
        let store = InMemoryTimerStore()
        let firstEngine = TimerEngine(store: store, now: clock.now)
        try firstEngine.start(babyID: "baby", timerType: .pump)
        clock.advance(by: 75)

        let reopenedEngine = TimerEngine(store: store, now: clock.now)
        try reopenedEngine.restore(babyID: "baby", timerType: .pump)

        #expect(reopenedEngine.elapsedSeconds() == 75)
    }

    @Test func nursingHistoricalSessionStartSurvivesSheetCloseAndReopen() throws {
        let clock = TestClock()
        let store = InMemoryTimerStore()
        let historicalStart = clock.now().addingTimeInterval(-7_200)
        let firstEngine = TimerEngine(store: store, now: clock.now)
        try firstEngine.start(
            babyID: "baby",
            timerType: .nursing,
            nursingSide: .left,
            recordedSessionStartTime: historicalStart
        )
        clock.advance(by: 75)

        let reopenedEngine = TimerEngine(store: store, now: clock.now)
        let restored = try reopenedEngine.restore(babyID: "baby", timerType: .nursing)

        #expect(restored?.recordedSessionStartTime == historicalStart)
        #expect(reopenedEngine.elapsedSeconds() == 75)
    }

    @Test func screenLockDoesNotStopElapsedTime() throws {
        let fixture = Fixture()
        try fixture.engine.start(babyID: "baby", timerType: .pump)

        fixture.clock.advance(by: 3_600)

        #expect(fixture.engine.elapsedSeconds() == 3_600)
    }

    @Test func relaunchFromDurableStoreReconstructsElapsedTime() throws {
        let suiteName = "Phase5TimerEngineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let clock = TestClock()
        let firstStore = DurableTimerStore(userDefaults: defaults)
        let firstEngine = TimerEngine(store: firstStore, now: clock.now)
        try firstEngine.start(babyID: "baby-a", timerType: .pump)
        clock.advance(by: 90)

        let relaunchedStore = DurableTimerStore(userDefaults: defaults)
        let relaunchedEngine = TimerEngine(store: relaunchedStore, now: clock.now)
        try relaunchedEngine.restore(babyID: "baby-a", timerType: .pump)

        #expect(relaunchedEngine.elapsedSeconds() == 90)
        #expect(relaunchedEngine.activeState?.babyID == "baby-a")
        #expect(relaunchedEngine.activeState?.timerType == .pump)
    }

    @Test func pauseAndResumeExcludePausedDuration() throws {
        let fixture = Fixture()
        try fixture.engine.start(babyID: "baby", timerType: .pump)

        fixture.clock.advance(by: 10)
        try fixture.engine.pause()
        fixture.clock.advance(by: 50)

        #expect(fixture.engine.elapsedSeconds() == 10)
        #expect(fixture.engine.activeState?.isPaused == true)
        #expect(fixture.engine.activeState?.accumulatedPausedSeconds == 0)

        try fixture.engine.resume()
        fixture.clock.advance(by: 5)

        #expect(fixture.engine.elapsedSeconds() == 15)
        #expect(fixture.engine.activeState?.isPaused == false)
        #expect(fixture.engine.activeState?.accumulatedPausedSeconds == 50)
    }

    @Test func pausedStateSurvivesRelaunchAndResume() throws {
        let clock = TestClock()
        let store = InMemoryTimerStore()
        let firstEngine = TimerEngine(store: store, now: clock.now)
        try firstEngine.start(babyID: "baby", timerType: .pump)
        clock.advance(by: 12)
        try firstEngine.pause()
        clock.advance(by: 100)

        let relaunchedEngine = TimerEngine(store: store, now: clock.now)
        try relaunchedEngine.restore(babyID: "baby", timerType: .pump)

        #expect(relaunchedEngine.elapsedSeconds() == 12)
        try relaunchedEngine.resume()
        clock.advance(by: 8)
        #expect(relaunchedEngine.elapsedSeconds() == 20)
        #expect(relaunchedEngine.activeState?.accumulatedPausedSeconds == 100)
    }

    @Test func nursingSideSwitchingAccumulatesEachSide() throws {
        let fixture = Fixture()
        try fixture.engine.start(
            babyID: "baby",
            timerType: .nursing,
            nursingSide: .left
        )

        fixture.clock.advance(by: 10)
        try fixture.engine.switchNursingSide(to: .right)
        fixture.clock.advance(by: 20)
        try fixture.engine.switchNursingSide(to: .left)
        fixture.clock.advance(by: 5)

        #expect(fixture.engine.elapsedSeconds() == 35)
        #expect(fixture.engine.nursingDurations() == NursingDurations(
            leftSeconds: 15,
            rightSeconds: 20
        ))
        #expect(fixture.engine.activeState?.activeNursingSide == .left)
    }

    @Test func switchingNursingSideWhilePausedStartsNewSideOnResume() throws {
        let fixture = Fixture()
        try fixture.engine.start(
            babyID: "baby",
            timerType: .nursing,
            nursingSide: .left
        )
        fixture.clock.advance(by: 10)
        try fixture.engine.pause()
        fixture.clock.advance(by: 30)
        try fixture.engine.switchNursingSide(to: .right)
        fixture.clock.advance(by: 20)
        try fixture.engine.resume()
        fixture.clock.advance(by: 5)

        #expect(fixture.engine.elapsedSeconds() == 15)
        #expect(fixture.engine.nursingDurations() == NursingDurations(
            leftSeconds: 10,
            rightSeconds: 5
        ))
        #expect(fixture.engine.activeState?.accumulatedPausedSeconds == 50)
    }

    @Test func durableStoreSeparatesBabiesAndTimerTypes() throws {
        let suiteName = "Phase5TimerStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DurableTimerStore(userDefaults: defaults)
        let start = Date(timeIntervalSince1970: 1_000)

        let babyAPump = ActiveTimerState(
            babyID: "baby-a",
            timerType: .pump,
            startTime: start
        )
        let babyANursing = ActiveTimerState(
            babyID: "baby-a",
            timerType: .nursing,
            startTime: start,
            activeNursingSide: .left,
            nursingSideStartedAt: start
        )
        let babyBPump = ActiveTimerState(
            babyID: "baby-b",
            timerType: .pump,
            startTime: start
        )

        try store.save(babyAPump)
        try store.save(babyANursing)
        try store.save(babyBPump)

        #expect(try store.load(babyID: "baby-a", timerType: .pump) == babyAPump)
        #expect(try store.load(babyID: "baby-a", timerType: .nursing) == babyANursing)
        #expect(try store.load(babyID: "baby-b", timerType: .pump) == babyBPump)

        try store.remove(babyID: "baby-a", timerType: .pump)
        #expect(try store.load(babyID: "baby-a", timerType: .pump) == nil)
        #expect(try store.load(babyID: "baby-a", timerType: .nursing) == babyANursing)
    }

    @Test func finishAndDiscardRemovePersistedState() throws {
        let clock = TestClock()
        let store = InMemoryTimerStore()
        let engine = TimerEngine(store: store, now: clock.now)
        try engine.start(babyID: "baby", timerType: .pump)
        clock.advance(by: 15)

        let finished = try engine.finish()

        #expect(finished.babyID == "baby")
        #expect(engine.activeState == nil)
        #expect(try store.load(babyID: "baby", timerType: .pump) == nil)

        try engine.start(babyID: "baby", timerType: .pump)
        try engine.discard()
        #expect(engine.activeState == nil)
        #expect(try store.load(babyID: "baby", timerType: .pump) == nil)
    }

    @Test func timerTypeEnforcesNursingSideRules() throws {
        let fixture = Fixture()

        #expect(throws: TimerEngineError.invalidNursingSide) {
            try fixture.engine.start(babyID: "baby", timerType: .nursing)
        }
        #expect(throws: TimerEngineError.invalidNursingSide) {
            try fixture.engine.start(
                babyID: "baby",
                timerType: .pump,
                nursingSide: .left
            )
        }

        try fixture.engine.start(babyID: "baby", timerType: .pump)
        #expect(throws: TimerEngineError.invalidNursingSide) {
            try fixture.engine.switchNursingSide(to: .right)
        }
    }
}

@MainActor
private struct Fixture {
    let clock: TestClock
    let store: InMemoryTimerStore
    let engine: TimerEngine

    init() {
        let clock = TestClock()
        let store = InMemoryTimerStore()
        self.clock = clock
        self.store = store
        self.engine = TimerEngine(store: store, now: clock.now)
    }
}

@MainActor
private final class TestClock {
    private var current = Date(timeIntervalSince1970: 1_000)

    func now() -> Date {
        current
    }

    func advance(by seconds: TimeInterval) {
        current = current.addingTimeInterval(seconds)
    }
}

@MainActor
private final class InMemoryTimerStore: DurableTimerStoring {
    private var states: [String: ActiveTimerState] = [:]

    func load(babyID: String, timerType: TimerType) throws -> ActiveTimerState? {
        states[key(babyID: babyID, timerType: timerType)]
    }

    func save(_ state: ActiveTimerState) throws {
        states[key(babyID: state.babyID, timerType: state.timerType)] = state
    }

    func remove(babyID: String, timerType: TimerType) throws {
        states.removeValue(forKey: key(babyID: babyID, timerType: timerType))
    }

    private func key(babyID: String, timerType: TimerType) -> String {
        "\(timerType.rawValue):\(babyID)"
    }
}
