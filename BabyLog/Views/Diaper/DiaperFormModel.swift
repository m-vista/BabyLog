import Foundation

struct DiaperSizeMemory {
    private static let key = "diaper.lastSize"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(isEnabled: Bool) -> DiaperSize? {
        guard isEnabled,
              let rawValue = defaults.string(forKey: Self.key)
        else {
            return nil
        }
        return DiaperSize(rawValue: rawValue)
    }

    func save(_ size: DiaperSize?, isEnabled: Bool) {
        guard isEnabled, let size else { return }
        defaults.set(size.rawValue, forKey: Self.key)
    }
}

@MainActor
@Observable
final class DiaperFormModel {
    private(set) var startTime: Date
    var type: DiaperType?
    var fullness: DiaperFullness?
    var size: DiaperSize?
    var notes: String

    let originalEvent: DiaperEvent?
    let rememberedSize: DiaperSize?

    init(
        event: DiaperEvent? = nil,
        rememberedSize: DiaperSize? = nil,
        now: Date = .now
    ) {
        originalEvent = event
        self.rememberedSize = event == nil ? rememberedSize : nil
        startTime = event?.startTime ?? now
        type = event?.type
        fullness = event?.fullness
        size = event?.size ?? rememberedSize
        notes = event?.notes ?? ""
    }

    var isEditing: Bool { originalEvent != nil }
    var hasSelectedType: Bool { type != nil }

    func setStartTime(_ value: Date) {
        startTime = value
    }

    func makeEvent(
        babyID: String,
        userID: String,
        now: Date = .now,
        id: String = UUID().uuidString
    ) throws -> DiaperEvent {
        guard let type else { throw DiaperFormError.missingType }
        if let originalEvent {
            return try DiaperEvent(
                id: originalEvent.id,
                babyID: originalEvent.babyID,
                startTime: startTime,
                type: type,
                fullness: fullness,
                size: size,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                createdByUserID: originalEvent.createdByUserID,
                createdAt: originalEvent.createdAt,
                updatedAt: originalEvent.updatedAt
            )
        }

        return try DiaperEvent.new(
            babyID: babyID,
            startTime: startTime,
            type: type,
            fullness: fullness,
            size: size,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            createdByUserID: userID,
            now: now,
            id: id
        )
    }
}

enum DiaperFormError: Error, Equatable {
    case missingType
}
