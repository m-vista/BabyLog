import Foundation

@MainActor
@Observable
final class AnalyticsViewModel {
    var category: TrackingCategory?
    var range: AnalyticsRange = .sevenDays
    private(set) var isLoading = true
    private(set) var errorMessage: String?

    private var pumps: [PumpSession] = []
    private var previousPump: PumpSession?
    private var bottles: [BottleFeed] = []
    private var nursing: [NursingSession] = []
    private var sleep: [SleepSession] = []
    private var openSleep: [SleepSession] = []
    private var previousSleep: SleepSession?
    private var diapers: [DiaperEvent] = []
    private var checklistEvents: [ChecklistEvent] = []
    private var checklistItems: [ChecklistItem] = []
    private(set) var growthMeasurements: [GrowthMeasurement] = []
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var ready: Set<String> = []
    @ObservationIgnored private let expected: Set<String> = ["pump", "bottle", "nursing", "sleep", "diaper", "events", "items"]

    func start(access: BabyAccess, environment: AppEnvironment, preferences: UserPreferences, now: Date = .now) {
        task?.cancel(); ready = []; isLoading = true; errorMessage = nil
        let interval = AnalyticsService.interval(range: range, now: now, preferences: preferences)
        let babyID = access.baby.id
        task = Task { [weak self] in
            guard let self else { return }
            do {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        let value = try? await environment.pumpRepository.fetchSessionImmediatelyBefore(babyID: babyID, startTime: interval.start)
                        await self.setPreviousPump(value)
                    }
                    group.addTask {
                        let value = try? await environment.sleepRepository.fetchSessionImmediatelyBefore(babyID: babyID, startTime: interval.start)
                        await self.setPreviousSleep(value)
                    }
                    group.addTask { for try await value in environment.pumpRepository.observe(babyID: babyID, interval: interval) { await self.receive(value, key: "pump") } }
                    group.addTask { for try await value in environment.bottleRepository.observe(babyID: babyID, interval: interval) { await self.receive(value, key: "bottle") } }
                    group.addTask { for try await value in environment.nursingRepository.observe(babyID: babyID, interval: interval) { await self.receive(value, key: "nursing") } }
                    group.addTask { for try await value in environment.sleepRepository.observe(babyID: babyID, interval: interval) { await self.receiveSleep(value) } }
                    group.addTask { for try await value in environment.sleepRepository.observeOpenSessions(babyID: babyID) { await self.receiveOpenSleep(value) } }
                    group.addTask { for try await value in environment.diaperRepository.observe(babyID: babyID, interval: interval) { await self.receive(value, key: "diaper") } }
                    group.addTask { for try await value in environment.checklistRepository.observeEvents(babyID: babyID, interval: interval) { await self.receive(value, key: "events") } }
                    group.addTask { for try await value in environment.checklistRepository.observeItems(babyID: babyID, includeInactive: true) { await self.receive(value, key: "items") } }
                    group.addTask {
                        do {
                            for try await value in environment.growthRepository.observe(babyID: babyID, interval: interval) {
                                await self.receiveGrowth(value)
                            }
                        } catch {
                            // Growth permissions may lag an app update. Core Analytics
                            // must remain usable while the new rules are deployed.
                        }
                    }
                    try await group.waitForAll()
                }
            } catch is CancellationError {
            } catch { await self.fail() }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        isLoading = false
    }

    func snapshot(access: BabyAccess, preferences: UserPreferences, now: Date) -> AnalyticsSnapshot {
        var sleepByID = Dictionary(uniqueKeysWithValues: sleep.map { ($0.id, $0) })
        for value in openSleep { sleepByID[value.id] = value }
        if let previousSleep { sleepByID[previousSleep.id] = previousSleep }
        return AnalyticsService.calculate(AnalyticsInput(
            baby: access.baby, range: range, preferences: preferences, now: now,
            pumps: pumps, pumpImmediatelyBeforeRange: previousPump, bottles: bottles,
            nursing: nursing, sleep: Array(sleepByID.values), diapers: diapers,
            checklistEvents: checklistEvents, checklistItems: checklistItems
        ))
    }

    private func mark(_ key: String) { ready.insert(key); isLoading = !ready.isSuperset(of: expected) }
    private func receive(_ value: [PumpSession], key: String) { pumps = value; mark(key) }
    private func receive(_ value: [BottleFeed], key: String) { bottles = value; mark(key) }
    private func receive(_ value: [NursingSession], key: String) { nursing = value; mark(key) }
    private func receive(_ value: [DiaperEvent], key: String) { diapers = value; mark(key) }
    private func receive(_ value: [ChecklistEvent], key: String) { checklistEvents = value; mark(key) }
    private func receive(_ value: [ChecklistItem], key: String) { checklistItems = value; mark(key) }
    private func receiveGrowth(_ value: [GrowthMeasurement]) { growthMeasurements = value }
    private func receiveSleep(_ value: [SleepSession]) { sleep = value; mark("sleep") }
    private func receiveOpenSleep(_ value: [SleepSession]) { openSleep = value }
    private func setPreviousPump(_ value: PumpSession?) { previousPump = value }
    private func setPreviousSleep(_ value: SleepSession?) { previousSleep = value }
    private func fail() { errorMessage = "Analytics couldn’t refresh. Check your connection and try again."; isLoading = false }
}
