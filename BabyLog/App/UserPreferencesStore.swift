import Foundation

@MainActor
@Observable
final class UserPreferencesStore {
    private(set) var values: UserPreferences = .defaults
    private(set) var loadedUserID: String?

    @ObservationIgnored
    private let repository: any UserPreferencesRepository

    init(repository: any UserPreferencesRepository) {
        self.repository = repository
    }

    func load(userID: String) async throws {
        values = try await repository.loadPreferences(userID: userID)
        loadedUserID = userID
    }

    func update(_ newValues: UserPreferences, userID: String) async throws {
        try await repository.updatePreferences(newValues, userID: userID)
        values = newValues
        loadedUserID = userID
    }

    func reset() {
        values = .defaults
        loadedUserID = nil
    }
}
