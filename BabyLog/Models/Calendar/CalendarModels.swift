import Foundation

enum CalendarRange: Int, CaseIterable, Identifiable, Sendable {
    case seven = 7
    case fourteen = 14
    case thirty = 30

    var id: Int { rawValue }
    var title: String { "\(rawValue)D" }

    /// Pinching in (scale < 1) shows more days; pinching out shows fewer. Small pinches are ignored.
    func afterPinch(scale: Double) -> CalendarRange {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        if scale < 0.8 { return all[min(all.count - 1, index + 1)] }
        if scale > 1.25 { return all[max(0, index - 1)] }
        return self
    }
}

enum CalendarDataSource: String, Hashable, Sendable {
    case pumps, bottles, nursing, sleep, diapers, checklistEvents, checklistItems, growth
}

enum CalendarSubscriptionPlan {
    static func sources(for filter: CalendarFilter) -> Set<CalendarDataSource> {
        var result: Set<CalendarDataSource> = []
        for category in filter.selectedCategories {
            switch category {
            case .feed: result.formUnion([.bottles, .nursing])
            case .sleep: result.insert(.sleep)
            case .diaper: result.insert(.diapers)
            case .pump: result.insert(.pumps)
            case .other: result.formUnion([.checklistEvents, .checklistItems, .growth])
            }
        }
        return result
    }
}

enum CalendarFilter: Equatable, Sendable {
    case all
    case single(TrackingCategory)
    case multi(Set<TrackingCategory>)

    var selectedCategories: Set<TrackingCategory> {
        switch self {
        case .all: Set(TrackingCategory.allCases)
        case .single(let category): [category]
        case .multi(let categories): categories
        }
    }

    var isEmptyMulti: Bool {
        if case .multi(let categories) = self { return categories.isEmpty }
        return false
    }

    mutating func select(_ category: TrackingCategory) {
        switch self {
        case .multi(var categories):
            if categories.contains(category) { categories.remove(category) }
            else { categories.insert(category) }
            self = .multi(categories)
        default:
            self = .single(category)
        }
    }
}

struct CalendarDayColumn: Identifiable, Equatable, Sendable {
    let id: Date
    let interval: DateInterval
    let isToday: Bool
}

enum CalendarMarkKind: Int, Sendable {
    case sleep = 1
    case pump = 2
    case feed = 3
    case diaper = 4
    case other = 5

    init(category: TrackingCategory) {
        switch category {
        case .sleep: self = .sleep
        case .pump: self = .pump
        case .feed: self = .feed
        case .diaper: self = .diaper
        case .other: self = .other
        }
    }
}

struct CalendarMark: Identifiable, Equatable, Sendable {
    let id: String
    let entry: TimelineEntry
    let dayID: Date
    let segmentStart: Date
    let segmentEnd: Date
    let startFraction: Double
    let durationFraction: Double
    let kind: CalendarMarkKind
    let isContinuation: Bool
    let isInProgress: Bool
    let soothingTimes: [Date]

    var category: TrackingCategory { entry.category }
    var zIndex: Double { Double(kind.rawValue) }
}

struct CalendarLayout: Equatable, Sendable {
    let interval: DateInterval
    let days: [CalendarDayColumn]
    let marks: [CalendarMark]
}

struct CalendarMarkFrame: Equatable, Sendable {
    let y: Double
    let height: Double
}
