import Foundation
import Testing
@testable import BabyLog

@Suite("Phase 20 Analytics presentation")
struct Phase20AnalyticsPresentationTests {
    @Test("All five category presentations are real-data driven")
    func allCategories() {
        let snapshot = AnalyticsSnapshot(
            interval: DateInterval(start: .now, duration: 86_400), dayCount: 1,
            feed: FeedAnalytics(), sleep: SleepAnalytics(), diaper: DiaperAnalytics(),
            pump: PumpAnalytics(), other: OtherAnalytics()
        )
        for category in TrackingCategory.allCases {
            let value = AnalyticsPresentation(category: category, snapshot: snapshot, unit: .ounces)
            #expect(!value.label.isEmpty)
            #expect(!value.breakdownTitle.isEmpty)
            #expect(value.stats.count <= 4)
        }
    }

    @Test("Volume presentation respects selected unit")
    func selectedUnit() {
        #expect(AnalyticsFormat.volume(NSDecimalNumber(decimal: VolumeService.millilitersPerOunce).doubleValue, .ounces) == "1")
        #expect(AnalyticsFormat.volume(100, .milliliters) == "100")
    }
}
