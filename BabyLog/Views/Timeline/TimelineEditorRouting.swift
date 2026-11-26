import SwiftUI

/// Routes a tapped Timeline row to the exact existing editor for its saved
/// record. Never a new or duplicated editor — reuses the same logging
/// sheets Home uses, so saves/deletes flow back through the same
/// repositories Timeline already observes.
enum TimelineEditorDestination: Identifiable {
    case pump(PumpSession)
    case bottle(BottleFeed)
    case nursing(NursingSession)
    case sleep(SleepSession)
    case diaper(DiaperEvent)
    case checklist(ChecklistEvent, ChecklistItem)
    case growth(GrowthMeasurement)

    var id: String {
        switch self {
        case .pump(let session): return "pump-\(session.id)"
        case .bottle(let feed): return "bottle-\(feed.id)"
        case .nursing(let session): return "nursing-\(session.id)"
        case .sleep(let session): return "sleep-\(session.id)"
        case .diaper(let event): return "diaper-\(event.id)"
        case .checklist(let event, _): return "checklist-\(event.id)"
        case .growth(let measurement): return "growth-\(measurement.id)"
        }
    }

    /// `nil` if the entry's checklist item no longer resolves (nothing to edit).
    init?(entry: TimelineEntry) {
        switch entry.kind {
        case .pump(let session): self = .pump(session)
        case .bottle(let feed): self = .bottle(feed)
        case .nursing(let session): self = .nursing(session)
        case .sleep(let session): self = .sleep(session)
        case .diaper(let event): self = .diaper(event)
        case .checklist(let event, let item):
            guard let item else { return nil }
            self = .checklist(event, item)
        case .growth(let measurement):
            self = .growth(measurement)
        }
    }
}

/// Deletes a Timeline entry's saved record directly through the same
/// repository its row observation already uses — mirrors what each
/// editor's own Delete button does, just without opening the sheet first
/// (used by swipe-to-delete).
enum TimelineEntryDeletion {
    static func delete(_ entry: TimelineEntry, environment: AppEnvironment) async throws {
        switch entry.kind {
        case .pump(let session):
            try await environment.pumpRepository.delete(id: session.id, babyID: session.babyID)
        case .bottle(let feed):
            try await environment.bottleRepository.delete(id: feed.id, babyID: feed.babyID)
        case .nursing(let session):
            try await environment.nursingRepository.delete(id: session.id, babyID: session.babyID)
        case .sleep(let session):
            try await environment.sleepRepository.delete(id: session.id, babyID: session.babyID)
        case .diaper(let event):
            try await environment.diaperRepository.delete(id: event.id, babyID: event.babyID)
        case .checklist(let event, _):
            try await environment.checklistRepository.deleteEvent(id: event.id, babyID: event.babyID)
        case .growth(let measurement):
            try await environment.growthRepository.delete(id: measurement.id, babyID: measurement.babyID)
        }
    }
}

struct TimelineEditorSheet: View {
    let destination: TimelineEditorDestination
    let access: BabyAccess?

    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        switch destination {
        case .pump(let session):
            PumpLoggingSheet(
                access: access,
                existingSession: session,
                volumeUnit: environment.preferences.values.volumeUnit,
                rememberDuration: environment.preferences.values.rememberPumpDuration,
                showPumpRate: environment.preferences.values.showPumpRate
            )
        case .bottle(let feed):
            BottleLoggingSheet(access: access, existingFeed: feed, volumeUnit: environment.preferences.values.volumeUnit)
        case .nursing(let session):
            NursingLoggingSheet(access: access, existingSession: session)
        case .sleep(let session):
            // An open sleep opens the live sheet, which picks up the running session.
            SleepLoggingSheet(access: access, existingSession: session.endTime == nil ? nil : session)
        case .diaper(let event):
            DiaperLoggingSheet(access: access, existingEvent: event, rememberSize: environment.preferences.values.rememberDiaperSize)
        case .checklist(let event, let item):
            if let access {
                ChecklistConfirmationSheet(
                    item: item,
                    userID: access.membership.userID,
                    event: event,
                    onSaved: { updated in _ = try await environment.checklistRepository.updateEvent(updated) },
                    onDelete: { completed in try await environment.checklistRepository.deleteEvent(id: completed.id, babyID: completed.babyID) }
                )
            }
        case .growth(let measurement):
            GrowthLoggingSheet(access: access, existingMeasurement: measurement)
        }
    }
}
