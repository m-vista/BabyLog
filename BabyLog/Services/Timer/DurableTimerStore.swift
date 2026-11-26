import Foundation

protocol DurableTimerStoring {
    func load(babyID: String, timerType: TimerType) throws -> ActiveTimerState?
    func save(_ state: ActiveTimerState) throws
    func remove(babyID: String, timerType: TimerType) throws
}

enum DurableTimerStoreError: Error, Equatable {
    case encodingFailed
    case decodingFailed
}

final class DurableTimerStore: DurableTimerStoring {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "BabyLog.activeTimers"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func load(babyID: String, timerType: TimerType) throws -> ActiveTimerState? {
        let states = try loadAll()
        return states[Self.key(babyID: babyID, timerType: timerType)]
    }

    func save(_ state: ActiveTimerState) throws {
        var states = try loadAll()
        states[Self.key(babyID: state.babyID, timerType: state.timerType)] = state
        try persist(states)
    }

    func remove(babyID: String, timerType: TimerType) throws {
        var states = try loadAll()
        states.removeValue(forKey: Self.key(babyID: babyID, timerType: timerType))
        try persist(states)
    }

    private func loadAll() throws -> [String: ActiveTimerState] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [:] }
        do {
            return try decoder.decode([String: ActiveTimerState].self, from: data)
        } catch {
            throw DurableTimerStoreError.decodingFailed
        }
    }

    private func persist(_ states: [String: ActiveTimerState]) throws {
        do {
            userDefaults.set(try encoder.encode(states), forKey: storageKey)
        } catch {
            throw DurableTimerStoreError.encodingFailed
        }
    }

    private static func key(babyID: String, timerType: TimerType) -> String {
        "\(timerType.rawValue):\(babyID)"
    }
}
