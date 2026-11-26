import Foundation

enum AnalyticsRange: Int, CaseIterable, Identifiable, Sendable {
    case day = 1
    case sevenDays = 7
    case thirtyDays = 30

    var id: Int { rawValue }
    var title: String { switch self { case .day: "Day"; case .sevenDays: "7 days"; case .thirtyDays: "30 days" } }
}

struct AnalyticsInput: Sendable {
    let baby: Baby
    let range: AnalyticsRange
    let preferences: UserPreferences
    let now: Date
    let pumps: [PumpSession]
    let pumpImmediatelyBeforeRange: PumpSession?
    let bottles: [BottleFeed]
    let nursing: [NursingSession]
    let sleep: [SleepSession]
    let diapers: [DiaperEvent]
    let checklistEvents: [ChecklistEvent]
    let checklistItems: [ChecklistItem]
}

struct AnalyticsPoint: Identifiable, Equatable, Sendable {
    let id: Date
    let value: Double
}

struct FeedAnalytics: Equatable, Sendable {
    var bottleAmountMl = 0.0
    var breastMilkMl = 0.0
    var formulaMl = 0.0
    var unspecifiedMl = 0.0
    var bottleCount = 0
    var nursingCount = 0
    var nursingSeconds: TimeInterval = 0
    var longestGapSeconds: TimeInterval = 0
    var dailyBottleMl: [AnalyticsPoint] = []
}

struct SleepAnalytics: Equatable, Sendable {
    var totalSeconds: TimeInterval = 0
    var napSeconds: TimeInterval = 0
    var nightSeconds: TimeInterval = 0
    var napCount = 0
    var longestStretchSeconds: TimeInterval = 0
    var averageAwakeSeconds: TimeInterval = 0
    var dailySeconds: [AnalyticsPoint] = []
}

struct DiaperAnalytics: Equatable, Sendable {
    var changes = 0
    var wet = 0
    var dirty = 0
    var both = 0
    var fullness: [DiaperFullness: Int] = [:]
    var mostUsedSize: DiaperSize?
    var latestChange: Date?
    var dailyChanges: [AnalyticsPoint] = []
}

struct PumpAnalytics: Equatable, Sendable {
    var totalMl = 0.0
    var cleanMl = 0.0
    var sessionCount = 0
    var cleanCount = 0
    var postNursingCount = 0
    var totalSeconds: TimeInterval = 0
    var leftMl = 0.0
    var rightMl = 0.0
    var cleanRateMlPerHour: Double?
    var dailyMl: [AnalyticsPoint] = []
}

struct ChecklistItemAnalytics: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let completedDays: Int
    let possibleDays: Int
    var completion: Double { possibleDays == 0 ? 0 : Double(completedDays) / Double(possibleDays) }
}

struct OtherAnalytics: Equatable, Sendable {
    var completedCount = 0
    var possibleCount = 0
    var completion: Double { possibleCount == 0 ? 0 : Double(completedCount) / Double(possibleCount) }
    var dailyCompletion: [AnalyticsPoint] = []
    var items: [ChecklistItemAnalytics] = []
}

struct AnalyticsSnapshot: Equatable, Sendable {
    let interval: DateInterval
    let dayCount: Int
    let feed: FeedAnalytics
    let sleep: SleepAnalytics
    let diaper: DiaperAnalytics
    let pump: PumpAnalytics
    let other: OtherAnalytics

    func hasData(for category: TrackingCategory?) -> Bool {
        switch category {
        case nil:
            feed.bottleCount > 0 || feed.nursingCount > 0 || sleep.totalSeconds > 0
                || diaper.changes > 0 || pump.sessionCount > 0 || other.completedCount > 0
        case .feed: feed.bottleCount > 0 || feed.nursingCount > 0
        case .sleep: sleep.totalSeconds > 0
        case .diaper: diaper.changes > 0
        case .pump: pump.sessionCount > 0
        case .other: other.completedCount > 0
        }
    }
}
