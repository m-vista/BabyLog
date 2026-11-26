import Foundation

@MainActor
@Observable
final class SleepFormModel {
    struct SoothingTime: Identifiable, Equatable {
        let id: UUID
        var date: Date

        init(id: UUID = UUID(), date: Date) {
            self.id = id
            self.date = date
        }
    }

    private(set) var startTime: Date
    private(set) var endTime: Date?
    var notes: String
    var soothingTimes: [SoothingTime]

    let originalSession: SleepSession?

    init(
        session: SleepSession? = nil,
        now: Date = .now
    ) {
        originalSession = session
        startTime = session?.startTime ?? now
        endTime = session?.endTime
        notes = session?.notes ?? ""
        soothingTimes = (session?.soothingTimes ?? [])
            .sorted()
            .map { SoothingTime(date: $0) }
    }

    var isEditing: Bool { originalSession != nil }

    func setStartTime(_ value: Date) {
        startTime = value
    }

    func setEndTime(_ value: Date?) {
        endTime = value
    }

    func addSoothingTime(at date: Date = .now) {
        soothingTimes.append(SoothingTime(date: date))
        soothingTimes.sort { $0.date < $1.date }
    }

    func setSoothingTimes(_ dates: [Date]) {
        soothingTimes = dates.sorted().map { SoothingTime(date: $0) }
    }

    var durationSeconds: TimeInterval? {
        endTime.map { max(0, $0.timeIntervalSince(startTime)) }
    }

    func setDuration(seconds: TimeInterval) {
        let rounded = max(0, (seconds / 60).rounded(.toNearestOrAwayFromZero) * 60)
        endTime = startTime.addingTimeInterval(max(0.001, rounded))
    }

    func finishTimer(at date: Date) {
        let elapsed = max(0, date.timeIntervalSince(startTime))
        setDuration(seconds: elapsed)
    }

    func makeSession(
        babyID: String,
        userID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> SleepSession {
        let recordedSoothingTimes = soothingTimes.map(\.date).sorted()

        if let originalSession {
            return try SleepSession(
                id: originalSession.id,
                babyID: originalSession.babyID,
                startTime: startTime,
                endTime: endTime,
                soothingTimes: recordedSoothingTimes,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                createdByUserID: originalSession.createdByUserID,
                createdAt: originalSession.createdAt,
                updatedAt: originalSession.updatedAt
            )
        }

        return try SleepSession.new(
            babyID: babyID,
            startTime: startTime,
            endTime: endTime,
            soothingTimes: recordedSoothingTimes,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdByUserID: userID,
            now: now,
            id: id
        )
    }
}
