//
//  AppEnvironment.swift
//  BabyLog
//

import Foundation

/// Holds shared service instances for injection into the view hierarchy.
///
/// Must only be constructed after `FirebaseApp.configure()` has run, since
/// Firebase-backed services touch their default instances at initialization.
@MainActor
@Observable
final class AppEnvironment {
    let userRepository: UserRepository
    let babyRepository: BabyRepository
    let pumpRepository: PumpRepository
    let bottleRepository: BottleRepository
    let diaperRepository: DiaperRepository
    let nursingRepository: NursingRepository
    let sleepRepository: SleepRepository
    let checklistRepository: ChecklistRepository
    let growthRepository: GrowthRepository
    let authService: AuthService
    let preferences: UserPreferencesStore
    let babyPhotoStore: BabyPhotoStore
    let timerEngine: TimerEngine

    init() {
        let userRepository = UserRepository()
        self.userRepository = userRepository
        self.babyRepository = BabyRepository()
        self.pumpRepository = PumpRepository()
        self.bottleRepository = BottleRepository()
        self.diaperRepository = DiaperRepository()
        self.nursingRepository = NursingRepository()
        self.sleepRepository = SleepRepository()
        self.checklistRepository = ChecklistRepository()
        self.growthRepository = GrowthRepository()
        self.authService = AuthService(userRepository: userRepository)
        self.preferences = UserPreferencesStore(repository: userRepository)
        self.babyPhotoStore = BabyPhotoStore()
        self.timerEngine = TimerEngine()
    }
}
