import Foundation
import Testing
@testable import BabyLog

@MainActor
struct Phase12SleepTests {
    private let timestamp = Date(timeIntervalSince1970: 10_000)

    @Test func openSessionEncodesEndTimeAsExplicitNull() throws {
        let session = try makeSession(id: "open", start: timestamp, end: nil)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(session)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(object["endTime"] is NSNull)
        #expect(session.isOpen)
    }

    @Test func completedSessionRequiresEndAfterStart() throws {
        let completed = try makeSession(
            id: "done",
            start: timestamp,
            end: timestamp.addingTimeInterval(600)
        )
        #expect(completed.durationSeconds == 600)

        #expect(throws: SleepSessionError.invalidTimeRange) {
            try makeSession(
                id: "bad",
                start: timestamp,
                end: timestamp
            )
        }
    }

    @Test func soothingEventsAccumulateForTheSameSleep() throws {
        let first = timestamp.addingTimeInterval(120)
        let second = timestamp.addingTimeInterval(240)
        let session = try makeSession(id: "soothing", start: timestamp, end: nil)
            .addingSoothing(at: first)
            .addingSoothing(at: second)

        #expect(session.soothingTimes == [first, second])
    }

    @Test func earliestOpenSessionIsActiveAndOthersAreExtras() throws {
        let later = try makeSession(
            id: "later",
            start: timestamp.addingTimeInterval(20),
            end: nil
        )
        let earliest = try makeSession(
            id: "earliest",
            start: timestamp,
            end: nil
        )

        #expect(SleepCalculator.activeSession(in: [later, earliest])?.id == "earliest")
        #expect(SleepCalculator.extraOpenSessions(in: [later, earliest]).map(\.id) == ["later"])
    }

    @Test func locallyCompletedSessionIsImmediatelyExcludedFromOpenState() throws {
        let completed = try makeSession(
            id: "completed",
            start: timestamp,
            end: nil
        )
        let stillOpen = try makeSession(
            id: "open",
            start: timestamp.addingTimeInterval(20),
            end: nil
        )

        let visible = SleepCalculator.excludingLocallyCompleted(
            [completed.id],
            from: [completed, stillOpen]
        )

        #expect(visible.map(\.id) == [stillOpen.id])
        #expect(SleepCalculator.activeSession(in: visible)?.id == stillOpen.id)
    }

    @Test func startWhenOpenExistsReturnsExistingSession() throws {
        let existing = try makeSession(
            id: "existing",
            start: timestamp,
            end: nil
        )
        let proposed = try makeSession(
            id: "proposed",
            start: timestamp.addingTimeInterval(30),
            end: nil
        )

        #expect(SleepCalculator.sessionToStart(
            proposed: proposed,
            openSessions: [existing]
        ) == existing)
        #expect(SleepCalculator.sessionToStart(
            proposed: proposed,
            openSessions: []
        ) == proposed)
    }

    @Test func overlapDetectionHandlesCompletedAndOpenSessions() throws {
        let existing = try makeSession(
            id: "existing",
            start: timestamp,
            end: timestamp.addingTimeInterval(600)
        )
        let overlap = try makeSession(
            id: "overlap",
            start: timestamp.addingTimeInterval(300),
            end: timestamp.addingTimeInterval(900)
        )
        let adjacent = try makeSession(
            id: "adjacent",
            start: timestamp.addingTimeInterval(600),
            end: timestamp.addingTimeInterval(900)
        )
        let open = try makeSession(
            id: "open",
            start: timestamp.addingTimeInterval(700),
            end: nil
        )

        #expect(SleepCalculator.overlaps(
            overlap,
            sessions: [existing],
            now: timestamp.addingTimeInterval(1_000)
        ))
        #expect(!SleepCalculator.overlaps(
            adjacent,
            sessions: [existing],
            now: timestamp.addingTimeInterval(1_000)
        ))
        #expect(SleepCalculator.overlaps(
            open,
            sessions: [adjacent],
            now: timestamp.addingTimeInterval(1_000)
        ))
    }

    @Test func awakeWindowAndCurrentAwakeDurationUsePreviousEnd() throws {
        let previous = try makeSession(
            id: "previous",
            start: timestamp,
            end: timestamp.addingTimeInterval(600)
        )
        let next = try makeSession(
            id: "next",
            start: timestamp.addingTimeInterval(1_500),
            end: timestamp.addingTimeInterval(2_100)
        )

        #expect(SleepCalculator.awakeWindowBefore(
            session: next,
            previousCompleted: previous
        ) == 900)
        #expect(SleepCalculator.currentAwakeDuration(
            latestCompleted: previous,
            now: timestamp.addingTimeInterval(1_200)
        ) == 600)
    }

    @Test func latestCompletedUsesLatestEndTime() throws {
        let first = try makeSession(
            id: "first",
            start: timestamp,
            end: timestamp.addingTimeInterval(300)
        )
        let second = try makeSession(
            id: "second",
            start: timestamp.addingTimeInterval(500),
            end: timestamp.addingTimeInterval(900)
        )
        let open = try makeSession(
            id: "open",
            start: timestamp.addingTimeInterval(1_000),
            end: nil
        )

        #expect(SleepCalculator.latestCompleted(in: [first, open, second])?.id == "second")
    }

    @Test func formEditPreservesIdentityAndMetadata() throws {
        let original = try makeSession(
            id: "original",
            start: timestamp,
            end: timestamp.addingTimeInterval(600)
        )
        let form = SleepFormModel(session: original)
        form.setEndTime(timestamp.addingTimeInterval(700))
        form.notes = " Updated "

        let edited = try form.makeSession(
            babyID: "other",
            userID: "other"
        )

        #expect(edited.id == original.id)
        #expect(edited.babyID == original.babyID)
        #expect(edited.createdByUserID == original.createdByUserID)
        #expect(edited.createdAt == original.createdAt)
        #expect(edited.updatedAt == original.updatedAt)
        #expect(edited.endTime == timestamp.addingTimeInterval(700))
        #expect(edited.notes == "Updated")
    }

    @Test func formEditsAndSortsSoothingTimes() throws {
        let original = try makeSession(
            id: "soothing",
            start: timestamp,
            end: timestamp.addingTimeInterval(900)
        )
        let form = SleepFormModel(session: original)
        let later = timestamp.addingTimeInterval(600)
        let earlier = timestamp.addingTimeInterval(300)

        form.addSoothingTime(at: later)
        form.addSoothingTime(at: earlier)

        let edited = try form.makeSession(babyID: "baby", userID: "user")
        #expect(edited.soothingTimes == [earlier, later])
    }

    @Test func durationUpdatesEndTimeAndTimerStopRoundsHalfUp() {
        let form = SleepFormModel(now: timestamp)
        #expect(form.endTime == nil)
        #expect(form.durationSeconds == nil)

        form.setDuration(seconds: 125)
        #expect(form.durationSeconds == 120)
        #expect(form.endTime == timestamp.addingTimeInterval(120))

        let roundsDown = SleepFormModel(now: timestamp)
        roundsDown.finishTimer(at: timestamp.addingTimeInterval(29))
        #expect(Int((roundsDown.durationSeconds ?? -1).rounded()) == 0)

        let roundsUp = SleepFormModel(now: timestamp)
        roundsUp.finishTimer(at: timestamp.addingTimeInterval(30))
        #expect(roundsUp.durationSeconds == 60)
    }

    private func makeSession(
        id: String,
        start: Date,
        end: Date?
    ) throws -> SleepSession {
        try SleepSession(
            id: id,
            babyID: "baby",
            startTime: start,
            endTime: end,
            notes: "",
            createdByUserID: "user",
            createdAt: timestamp,
            updatedAt: timestamp
        )
    }
}
