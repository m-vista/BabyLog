import Foundation
import Testing
@testable import BabyLog

@MainActor
struct Phase13ChecklistTests {
    private let now = Date(timeIntervalSince1970: 20_000)

    @Test func commonTemplatesAreStableAndComplete() {
        #expect(ChecklistItem.commonTemplates.map(\.id) == ["common-bath", "common-outside", "common-vit-d", "common-tummy", "common-story"])
        #expect(ChecklistItem.commonTemplates.map(\.title) == ["Bath", "Outside", "Vit D", "Tummy", "Story"])
    }

    @Test func customTitleRequiresOneWord() throws {
        #expect(try ChecklistLogic.validateCustomTitle("  Bath ") == "Bath")
        #expect(throws: ChecklistError.titleMustBeOneWord) { try ChecklistLogic.validateCustomTitle("Fresh air") }
        #expect(throws: ChecklistError.missingTitle) { try ChecklistLogic.validateCustomTitle("  ") }
    }

    @Test func itemRequiresSupportedSymbolAndMetadata() throws {
        let item = try makeItem()
        #expect(item.createdByUserID == "user")
        #expect(throws: ChecklistError.unsupportedSymbol) {
            try ChecklistItem(id: "bad", babyID: "baby", title: "Bad", symbol: "not.allowed", sortOrder: 0, isActive: true, createdByUserID: "user", createdAt: now, updatedAt: now)
        }
    }

    @Test func eventFormCreatesTrimmedCompletion() throws {
        let item = try makeItem()
        let form = ChecklistEventFormModel(now: now)
        form.notes = " Done after lunch "
        let event = try form.makeEvent(item: item, userID: "caregiver", now: now, id: "event")
        #expect(event.checklistItemID == item.id)
        #expect(event.timestamp == now)
        #expect(event.notes == "Done after lunch")
        #expect(event.createdByUserID == "caregiver")
    }

    @Test func editPreservesEventIdentityAndCreationMetadata() throws {
        let item = try makeItem()
        let original = try ChecklistEvent.new(babyID: "baby", checklistItemID: item.id, timestamp: now, notes: "", createdByUserID: "first", now: now, id: "event")
        let form = ChecklistEventFormModel(event: original)
        form.setTimestamp(now.addingTimeInterval(60))
        let edited = try form.makeEvent(item: item, userID: "second")
        #expect(edited.id == original.id)
        #expect(edited.createdByUserID == "first")
        #expect(edited.createdAt == original.createdAt)
        #expect(edited.timestamp == now.addingTimeInterval(60))
    }

    @Test func completionUsesLatestEventPerItem() throws {
        let item = try makeItem()
        let early = try ChecklistEvent.new(babyID: "baby", checklistItemID: item.id, timestamp: now, notes: "", createdByUserID: "user", now: now, id: "early")
        let late = try ChecklistEvent.new(babyID: "baby", checklistItemID: item.id, timestamp: now.addingTimeInterval(30), notes: "", createdByUserID: "user", now: now, id: "late")
        #expect(ChecklistLogic.completionByItem([early, late])[item.id]?.id == "late")
    }

    @Test func itemEditPreservesIdentityAndSortOrder() throws {
        let original = try makeItem()
        let form = ChecklistItemFormModel(item: original)
        form.title = "Walk"
        form.symbol = .walk
        let edited = try form.makeItem(babyID: "other", userID: "other", sortOrder: 99)
        #expect(edited.id == original.id)
        #expect(edited.babyID == original.babyID)
        #expect(edited.createdByUserID == original.createdByUserID)
        #expect(edited.sortOrder == original.sortOrder)
    }

    @Test func inactiveItemRemainsValid() throws {
        var item = try makeItem()
        item.isActive = false
        try item.validate()
        #expect(!item.isActive)
    }

    private func makeItem() throws -> ChecklistItem {
        try ChecklistItem(id: "item", babyID: "baby", title: "Bath", symbol: ChecklistSymbol.bath.rawValue, sortOrder: 0, isActive: true, createdByUserID: "user", createdAt: now, updatedAt: now)
    }
}
