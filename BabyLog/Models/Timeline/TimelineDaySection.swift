import Foundation

/// Timeline filter bar segments (design section 36). `all.category` is nil;
/// every other case maps 1:1 onto `TrackingCategory`.
enum TimelineFilter: Equatable, Sendable {
    case all
    case single(TrackingCategory)
    case multi(Set<TrackingCategory>)

    static let feed = TimelineFilter.single(.feed)
    static let diaper = TimelineFilter.single(.diaper)
    static let sleep = TimelineFilter.single(.sleep)
    static let pump = TimelineFilter.single(.pump)
    static let other = TimelineFilter.single(.other)

    var category: TrackingCategory? {
        switch self {
        case .all: return nil
        case .single(let category): return category
        case .multi(let categories): return categories.count == 1 ? categories.first : nil
        }
    }

    var selectedCategories: Set<TrackingCategory> {
        switch self {
        case .all: Set(TrackingCategory.allCases)
        case .single(let category): [category]
        case .multi(let categories): categories
        }
    }

    var isMulti: Bool {
        if case .multi = self { return true }
        return false
    }

    mutating func select(_ category: TrackingCategory) {
        if case .multi(var categories) = self {
            if categories.contains(category) { categories.remove(category) }
            else { categories.insert(category) }
            self = .multi(categories)
        } else {
            self = .single(category)
        }
    }
}

enum TimelineDisplayMode: Sendable {
    case fullList
    case summariesOnly
}

/// Raw numeric aggregates for one day's Feed row. Display strings are built
/// by `TimelineSummaryFormatter`, not here (keep formatting out of semantics).
struct TimelineFeedSummary: Equatable, Sendable {
    var count = 0
    var bottleCount = 0
    var bottleTotalMl: Double = 0
    var nursingCount = 0
    var nursingTotalSeconds: TimeInterval = 0
}

struct TimelinePumpSummary: Equatable, Sendable {
    var count = 0
    var totalMl: Double = 0
    var leftMl: Double?
    var rightMl: Double?
    /// Earliest/latest boundaries of this group's pumps — used to anchor the
    /// group production rate to the session immediately before `firstStartTime`.
    var firstStartTime: Date?
    var lastEndTime: Date?
    var cleanSessions: [PumpSession] = []
}

struct TimelineDiaperSummary: Equatable, Sendable {
    var count = 0
    var wetCount = 0
    var dirtyCount = 0
}

struct TimelineSleepSummary: Equatable, Sendable {
    var totalSeconds: TimeInterval = 0
    var napCount = 0
    var napTotalSeconds: TimeInterval = 0
    var nightTotalSeconds: TimeInterval = 0
}

struct TimelineOtherSummary: Equatable, Sendable {
    var completedCount = 0
    var totalItemCount = 0
    /// Resolved titles of items completed that day, oldest completion first.
    var completedTitlesInOrder: [String] = []
}

struct TimelineDaySummary: Equatable, Sendable {
    var feed = TimelineFeedSummary()
    var pump = TimelinePumpSummary()
    var diaper = TimelineDiaperSummary()
    var sleep = TimelineSleepSummary()
    var other = TimelineOtherSummary()
}

/// One continuous-scroll day section: a summary card plus (in full-list mode)
/// its event rows, newest first.
struct TimelineDaySection: Identifiable, Sendable {
    /// Start of the effective tracking day — stable across reloads, used as
    /// both dictionary key and SwiftUI row/scroll-position identity.
    let id: Date
    let interval: DateInterval
    let dayStartMinutes: Int
    let usesCustomDayStart: Bool
    var entries: [TimelineEntry]
    var summary: TimelineDaySummary
}

extension TimelineDaySection: Equatable {
    static func == (lhs: TimelineDaySection, rhs: TimelineDaySection) -> Bool {
        lhs.id == rhs.id && lhs.entries == rhs.entries && lhs.summary == rhs.summary
    }
}
