#if DEBUG
import Testing
@testable import BabyLog

struct Phase6DeveloperLauncherTests {
    @Test func launcherContainsExactlyTheSixPlannedDestinations() {
        #expect(DeveloperLoggerDestination.allCases.map(\.title) == [
            "Pump",
            "Bottle",
            "Nursing",
            "Sleep",
            "Diaper",
            "Checklist confirmation"
        ])
    }

    @Test func launcherHasAnExplicitDebugVerificationRoute() {
        #expect(DeveloperLoggerDestination.launchArgument == "-Phase6DebugLauncher")
    }
}
#endif
