//
//  UserProfile.swift
//  BabyLog
//

import FirebaseFirestore

/// `users/{uid}` profile document. See BabyLog_Technical_Requirements_Fresh.md section 6.
/// `preferences` is written as an empty map on signup; Phase 4 introduces the typed
/// `UserPreferences` model that reads/writes that field.
struct UserProfile: Identifiable, Codable {
    @DocumentID var id: String?
    var displayName: String
    var email: String
    var createdAt: Date
    var updatedAt: Date
}
