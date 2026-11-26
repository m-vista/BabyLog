import Foundation

struct BabyMembership: Identifiable, Codable, Equatable, Sendable {
    enum Role: String, Codable, CaseIterable, Sendable {
        case owner
        case admin
        case caregiver
    }

    enum Status: String, Codable, Sendable {
        case active
        case removed
    }

    let id: String
    let babyID: String
    let userID: String
    var role: Role
    var status: Status
    let createdAt: Date
    var updatedAt: Date
}

struct BabyAccess: Equatable, Sendable {
    let baby: Baby
    let membership: BabyMembership
}
