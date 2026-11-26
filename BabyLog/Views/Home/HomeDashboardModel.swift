import Foundation

@MainActor
@Observable
final class HomeDashboardModel {
    var bottles: [BottleFeed] = []
    var diapers: [DiaperEvent] = []
    var nursing: [NursingSession] = []
    var pumps: [PumpSession] = []
    var checklistItems: [ChecklistItem] = []
    var checklistEvents: [ChecklistEvent] = []
    var openSleeps: [SleepSession] = []
    var sleeps: [SleepSession] = []
    var latestSleep: SleepSession?
    var latestBottleRecord: BottleFeed?
    var latestDiaperRecord: DiaperEvent?
    var latestNursingRecord: NursingSession?
    var latestPumpRecord: PumpSession?
    var previousPumpRecord: PumpSession?
    var latestGrowth: GrowthMeasurement?
    var pumpBeforeTrackingDay: PumpSession?
    var errorMessage: String?

    var latestBottle: BottleFeed? { latestBottleRecord }
    var latestDiaper: DiaperEvent? { latestDiaperRecord }
    var latestNursing: NursingSession? { latestNursingRecord }
    var latestPump: PumpSession? { latestPumpRecord }
    var activeSleep: SleepSession? { SleepCalculator.activeSession(in: openSleeps) }
    var checklistCompletion: [String: ChecklistEvent] { ChecklistLogic.completionByItem(checklistEvents) }

    func observe(access: BabyAccess, environment: AppEnvironment, preferences: UserPreferences, now: Date = .now) async {
        let babyID = access.baby.id
        let interval = TrackingDayService.interval(containing: now, surface: .home, preferences: preferences)
        do {
            pumpBeforeTrackingDay = try? await environment.pumpRepository.fetchSessionImmediatelyBefore(
                babyID: babyID,
                startTime: interval.start
            )
            try await environment.checklistRepository.seedDefaultsIfNeeded(babyID: babyID, userID: access.membership.userID)
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { for try await values in environment.bottleRepository.observe(babyID: babyID, interval: interval) { await MainActor.run { self.bottles = values } } }
                group.addTask { for try await values in environment.diaperRepository.observe(babyID: babyID, interval: interval) { await MainActor.run { self.diapers = values } } }
                group.addTask { for try await values in environment.nursingRepository.observe(babyID: babyID, interval: interval) { await MainActor.run { self.nursing = values } } }
                group.addTask { for try await values in environment.pumpRepository.observe(babyID: babyID, interval: interval) { await MainActor.run { self.pumps = values } } }
                group.addTask { for try await values in environment.checklistRepository.observeItems(babyID: babyID) { await MainActor.run { self.checklistItems = values } } }
                group.addTask { for try await values in environment.checklistRepository.observeEvents(babyID: babyID, interval: interval) { await MainActor.run { self.checklistEvents = values } } }
                group.addTask { for try await values in environment.sleepRepository.observeOpenSessions(babyID: babyID) { await MainActor.run { self.openSleeps = values } } }
                group.addTask { for try await values in environment.sleepRepository.observe(babyID: babyID, interval: interval) { await MainActor.run { self.sleeps = values } } }
                group.addTask { for try await value in environment.sleepRepository.observeLatestCompleted(babyID: babyID) { await MainActor.run { self.latestSleep = value } } }
                group.addTask { for try await value in environment.bottleRepository.observeLatest(babyID: babyID) { await MainActor.run { self.latestBottleRecord = value } } }
                group.addTask { for try await value in environment.diaperRepository.observeLatest(babyID: babyID) { await MainActor.run { self.latestDiaperRecord = value } } }
                group.addTask { for try await value in environment.nursingRepository.observeLatest(babyID: babyID) { await MainActor.run { self.latestNursingRecord = value } } }
                group.addTask { for try await value in environment.growthRepository.observeLatest(babyID: babyID) { await MainActor.run { self.latestGrowth = value } } }
                group.addTask {
                    for try await value in environment.pumpRepository.observeLatest(babyID: babyID) {
                        let previous: PumpSession? = if let value {
                            try? await environment.pumpRepository.fetchSessionImmediatelyBefore(
                                babyID: babyID,
                                startTime: value.startTime,
                                excludingID: value.id
                            )
                        } else {
                            nil
                        }
                        await MainActor.run {
                            self.latestPumpRecord = value
                            self.previousPumpRecord = previous
                        }
                    }
                }
                try await group.waitForAll()
            }
        } catch is CancellationError {
        } catch {
            errorMessage = "Some Home data is unavailable. New entries can still be logged."
        }
    }
}
