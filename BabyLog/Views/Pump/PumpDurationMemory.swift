import Foundation

struct PumpDurationMemory {
    private static let key = "pump.lastDurationSeconds"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(isEnabled: Bool) -> TimeInterval {
        guard isEnabled else { return 0 }
        return max(0, defaults.double(forKey: Self.key))
    }

    func save(_ duration: TimeInterval, isEnabled: Bool) {
        guard isEnabled, duration.isFinite, duration >= 0 else { return }
        defaults.set(duration, forKey: Self.key)
    }
}
