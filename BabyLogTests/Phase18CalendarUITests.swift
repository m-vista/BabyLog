import Testing
@testable import BabyLog

@Suite("Phase 18 Calendar UI support")
struct Phase18CalendarUITests {
    @Test("All subscribes to every bounded data source")
    func allSources() {
        let sources = CalendarSubscriptionPlan.sources(for: .all)
        #expect(sources == Set(CalendarDataSource.allCasesForTesting))
    }

    @Test("Single filters subscribe only to relevant repositories")
    func singleSources() {
        #expect(CalendarSubscriptionPlan.sources(for: .single(.feed)) == [.bottles, .nursing])
        #expect(CalendarSubscriptionPlan.sources(for: .single(.sleep)) == [.sleep])
        #expect(CalendarSubscriptionPlan.sources(for: .single(.diaper)) == [.diapers])
        #expect(CalendarSubscriptionPlan.sources(for: .single(.pump)) == [.pumps])
        #expect(CalendarSubscriptionPlan.sources(for: .single(.other)) == [.checklistEvents, .checklistItems, .growth])
    }

    @Test("Multi subscribes to the union and supports empty selection")
    func multiSources() {
        #expect(CalendarSubscriptionPlan.sources(for: .multi([.sleep, .pump])) == [.sleep, .pumps])
        #expect(CalendarSubscriptionPlan.sources(for: .multi([])).isEmpty)
    }
}

private extension CalendarDataSource {
    static var allCasesForTesting: [Self] {
        [.pumps, .bottles, .nursing, .sleep, .diapers, .checklistEvents, .checklistItems, .growth]
    }
}
