//
//  UserRepository.swift
//  BabyLog
//

import Foundation
import FirebaseFirestore

protocol UserPreferencesRepository {
    func loadPreferences(userID: String) async throws -> UserPreferences
    func updatePreferences(_ preferences: UserPreferences, userID: String) async throws
}

/// Owns all Firestore access for `users/{uid}` (global rule 7).
struct UserRepository: UserPreferencesRepository {
    private let db: Firestore

    init(db: Firestore = Firestore.firestore()) {
        self.db = db
    }

    private func document(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    /// Creates the profile document on signup if it doesn't already exist.
    func createProfileIfNeeded(uid: String, displayName: String, email: String) async throws {
        let ref = document(uid)
        let snapshot = try await ref.getDocument()
        guard !snapshot.exists else { return }

        let now = Date()
        try await ref.setData([
            "displayName": displayName,
            "email": email,
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now),
            "preferences": [String: Any](),
        ])
    }

    func profile(userID: String) async throws -> UserProfile {
        try await document(userID).getDocument().data(as: UserProfile.self)
    }

    func updateDisplayName(_ displayName: String, userID: String, at date: Date = .now) async throws {
        let value = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw UserRepositoryError.invalidDisplayName }
        try await document(userID).updateData(["displayName": value, "updatedAt": Timestamp(date: date)])
    }

    func loadPreferences(userID: String) async throws -> UserPreferences {
        let data = try await document(userID).getDocument().data()
        guard let preferences = data?["preferences"] as? [String: Any] else {
            return .defaults
        }
        return try Self.decodePreferences(preferences)
    }

    func updatePreferences(_ preferences: UserPreferences, userID: String) async throws {
        try await document(userID).updateData(
            Self.preferenceUpdateData(preferences, updatedAt: .now)
        )
    }

    static func preferenceUpdateData(
        _ preferences: UserPreferences,
        updatedAt: Date
    ) throws -> [String: Any] {
        [
            "preferences": try encodePreferences(preferences),
            "updatedAt": Timestamp(date: updatedAt),
        ]
    }

    static func decodePreferences(_ data: [String: Any]) throws -> UserPreferences {
        let json = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(UserPreferences.self, from: json)
    }

    static func encodePreferences(_ preferences: UserPreferences) throws -> [String: Any] {
        let data = try JSONEncoder().encode(preferences)
        guard let result = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UserRepositoryError.invalidPreferences
        }
        return result
    }
}

enum UserRepositoryError: Error, Equatable {
    case invalidPreferences
    case invalidDisplayName
}
