import Foundation
import Testing
@testable import BabyLog

@MainActor
struct Phase10DiaperTests {
    private let timestamp = Date(timeIntervalSince1970: 4_000)

    @Test func bothCountsAsWetAndDirtyAndUsesContextualTitles() {
        #expect(DiaperType.both.wetCount == 1)
        #expect(DiaperType.both.dirtyCount == 1)
        #expect(DiaperType.both.loggingTitle == "Both")
        #expect(DiaperType.both.detailTitle == "Wet & Dirty")
        #expect(DiaperType.wet.wetCount == 1)
        #expect(DiaperType.wet.dirtyCount == 0)
    }

    @Test func optionalFullnessAndSizeRoundTrip() throws {
        let event = try makeEvent(
            type: .both,
            fullness: .heavy,
            size: .newborn
        )
        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(DiaperEvent.self, from: data)

        #expect(decoded == event)
        #expect(decoded.fullness == .heavy)
        #expect(decoded.size == .newborn)
    }

    @Test func nilFullnessAndSizeAreValid() throws {
        let event = try makeEvent(type: .wet, fullness: nil, size: nil)

        #expect(event.fullness == nil)
        #expect(event.size == nil)
    }

    @Test func newFormUsesRememberedSizeWhenEnabled() {
        let form = DiaperFormModel(
            rememberedSize: .three,
            now: timestamp
        )

        #expect(form.size == .three)
        #expect(form.rememberedSize == .three)
        #expect(form.type == nil)
        #expect(form.fullness == nil)
    }

    @Test func newFormRequiresExplicitTypeSelection() {
        let form = DiaperFormModel(now: timestamp)
        #expect(!form.hasSelectedType)
        #expect(throws: DiaperFormError.missingType) {
            try form.makeEvent(babyID: "baby", userID: "user")
        }
    }

    @Test func editFormUsesStoredSizeInsteadOfRememberedSize() throws {
        let event = try makeEvent(
            type: .dirty,
            fullness: .medium,
            size: .one
        )
        let form = DiaperFormModel(
            event: event,
            rememberedSize: .seven,
            now: timestamp
        )

        #expect(form.size == .one)
        #expect(form.rememberedSize == nil)
    }

    @Test func sizeMemoryHonorsPreference() {
        let suite = "Phase10DiaperTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let memory = DiaperSizeMemory(defaults: defaults)

        memory.save(.four, isEnabled: false)
        #expect(memory.load(isEnabled: true) == nil)

        memory.save(.four, isEnabled: true)
        #expect(memory.load(isEnabled: false) == nil)
        #expect(memory.load(isEnabled: true) == .four)
    }

    @Test func formMapsAllFieldsAndTrimsNote() throws {
        let form = DiaperFormModel(now: timestamp)
        form.type = .both
        form.fullness = .light
        form.size = .two
        form.notes = "  Changed quickly  "

        let event = try form.makeEvent(
            babyID: "baby",
            userID: "user",
            now: timestamp,
            id: "diaper"
        )

        #expect(event.id == "diaper")
        #expect(event.type == .both)
        #expect(event.fullness == .light)
        #expect(event.size == .two)
        #expect(event.notes == "Changed quickly")
    }

    @Test func editPreservesIdentityAndCreationMetadata() throws {
        let original = try makeEvent(
            type: .wet,
            fullness: nil,
            size: nil
        )
        let form = DiaperFormModel(event: original)
        form.type = .dirty
        form.setStartTime(timestamp.addingTimeInterval(30))

        let edited = try form.makeEvent(
            babyID: "other",
            userID: "other"
        )

        #expect(edited.id == original.id)
        #expect(edited.babyID == original.babyID)
        #expect(edited.createdByUserID == original.createdByUserID)
        #expect(edited.createdAt == original.createdAt)
        #expect(edited.updatedAt == original.updatedAt)
        #expect(edited.type == .dirty)
    }

    private func makeEvent(
        type: DiaperType,
        fullness: DiaperFullness?,
        size: DiaperSize?
    ) throws -> DiaperEvent {
        try DiaperEvent(
            id: "diaper-a",
            babyID: "baby-a",
            startTime: timestamp,
            type: type,
            fullness: fullness,
            size: size,
            notes: "Note",
            createdByUserID: "user-a",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}
