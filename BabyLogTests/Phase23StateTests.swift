import Foundation
import Testing
@testable import BabyLog

struct Phase23StateTests {
    @Test func analyticsEmptyStateIsCategoryAware() {
        var feed = FeedAnalytics()
        let empty = AnalyticsSnapshot(
            interval: DateInterval(start: .now, duration: 86_400), dayCount: 1,
            feed: feed, sleep: SleepAnalytics(), diaper: DiaperAnalytics(),
            pump: PumpAnalytics(), other: OtherAnalytics()
        )
        #expect(!empty.hasData(for: nil))
        #expect(!empty.hasData(for: .feed))

        feed.nursingCount = 1
        let nursingOnly = AnalyticsSnapshot(
            interval: empty.interval, dayCount: 1, feed: feed,
            sleep: SleepAnalytics(), diaper: DiaperAnalytics(),
            pump: PumpAnalytics(), other: OtherAnalytics()
        )
        #expect(nursingOnly.hasData(for: nil))
        #expect(nursingOnly.hasData(for: .feed))
        #expect(!nursingOnly.hasData(for: .pump))
    }
}
