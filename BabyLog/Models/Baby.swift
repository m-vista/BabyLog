import Foundation

enum BabyGender: String, CaseIterable, Codable, Identifiable, Sendable {
    case boy
    case girl
    case preferNotToSay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .boy: "Boy"
        case .girl: "Girl"
        case .preferNotToSay: "Prefer not to say"
        }
    }
}

struct Baby: Identifiable, Codable, Equatable, Sendable {
    static let defaultNightStartMinutes = 1_140
    static let defaultNightEndMinutes = 420

    let id: String
    var name: String
    var birthDate: Date
    var gender: BabyGender?
    var usesCorrectedDate: Bool?
    var dueDate: Date?
    let createdByUserID: String
    var nightStartMinutes: Int
    var nightEndMinutes: Int
    let createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        name: String,
        birthDate: Date,
        gender: BabyGender = .preferNotToSay,
        usesCorrectedDate: Bool = false,
        dueDate: Date? = nil,
        createdByUserID: String,
        nightStartMinutes: Int = Self.defaultNightStartMinutes,
        nightEndMinutes: Int = Self.defaultNightEndMinutes,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.usesCorrectedDate = usesCorrectedDate
        self.dueDate = dueDate
        self.createdByUserID = createdByUserID
        self.nightStartMinutes = nightStartMinutes
        self.nightEndMinutes = nightEndMinutes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
