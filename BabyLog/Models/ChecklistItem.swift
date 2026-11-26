import Foundation

enum ChecklistSymbol: String, Codable, CaseIterable, Sendable {
    case bath = "bathtub.fill"
    case outside = "sun.max.fill"
    case vitamin = "pills.fill"
    case tummy = "figure.child"
    case story = "book.fill"
    case heart = "heart.fill"
    case star = "star.fill"
    case walk = "figure.walk"

    var title: String {
        switch self {
        case .bath: "Bath"
        case .outside: "Outside"
        case .vitamin: "Vitamin"
        case .tummy: "Tummy"
        case .story: "Story"
        case .heart: "Heart"
        case .star: "Star"
        case .walk: "Walk"
        }
    }
}

struct ChecklistItem: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let babyID: String
    var title: String
    var symbol: String
    var sortOrder: Int
    var isActive: Bool
    let createdByUserID: String
    let createdAt: Date
    var updatedAt: Date

    static let commonTemplates: [(id: String, title: String, symbol: ChecklistSymbol)] = [
        ("common-bath", "Bath", .bath),
        ("common-outside", "Outside", .outside),
        ("common-vit-d", "Vit D", .vitamin),
        ("common-tummy", "Tummy", .tummy),
        ("common-story", "Story", .story)
    ]

    init(id: String, babyID: String, title: String, symbol: String, sortOrder: Int, isActive: Bool, createdByUserID: String, createdAt: Date, updatedAt: Date) throws {
        self.id = id
        self.babyID = babyID
        self.title = title
        self.symbol = symbol
        self.sortOrder = sortOrder
        self.isActive = isActive
        self.createdByUserID = createdByUserID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        try validate()
    }

    func validate() throws {
        guard !id.isEmpty, !babyID.isEmpty, !createdByUserID.isEmpty else { throw ChecklistError.missingIdentity }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw ChecklistError.missingTitle }
        guard ChecklistSymbol(rawValue: symbol) != nil else { throw ChecklistError.unsupportedSymbol }
        guard sortOrder >= 0 else { throw ChecklistError.invalidSortOrder }
    }
}

enum ChecklistError: Error, Equatable {
    case missingIdentity
    case missingTitle
    case titleMustBeOneWord
    case unsupportedSymbol
    case invalidSortOrder
}
