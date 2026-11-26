import Foundation

/// One unified Timeline event. Associated values hold the real saved record
/// (never a Firestore snapshot) so rows can route back to the exact editor.
enum TimelineEntryKind: Sendable {
    case pump(PumpSession)
    case bottle(BottleFeed)
    case nursing(NursingSession)
    case sleep(SleepSession)
    case diaper(DiaperEvent)
    case checklist(ChecklistEvent, item: ChecklistItem?)
    case growth(GrowthMeasurement)
}

/// A Pump/Bottle/Nursing/Sleep/Diaper/Checklist event normalized for Timeline
/// display, sorting, and grouping. Bottle and Nursing map to `.feed`;
/// Checklist maps to `.other` (section 19, D-decisions).
struct TimelineEntry: Identifiable, Sendable {
    let id: String
    let kind: TimelineEntryKind
    let category: TrackingCategory
    /// Sort/group anchor: `startTime` for timed events, `timestamp` for checklist.
    let date: Date

    init(kind: TimelineEntryKind) {
        self.kind = kind
        switch kind {
        case .pump(let session):
            id = "pump-\(session.id)"
            category = .pump
            date = session.startTime
        case .bottle(let feed):
            id = "bottle-\(feed.id)"
            category = .feed
            date = feed.startTime
        case .nursing(let session):
            id = "nursing-\(session.id)"
            category = .feed
            date = session.startTime
        case .sleep(let session):
            id = "sleep-\(session.id)"
            category = .sleep
            date = session.startTime
        case .diaper(let event):
            id = "diaper-\(event.id)"
            category = .diaper
            date = event.startTime
        case .checklist(let event, _):
            id = "checklist-\(event.id)"
            category = .other
            date = event.timestamp
        case .growth(let measurement):
            id = "growth-\(measurement.id)"
            category = .other
            date = measurement.timestamp
        }
    }
}

extension TimelineEntry: Equatable {
    static func == (lhs: TimelineEntry, rhs: TimelineEntry) -> Bool { lhs.id == rhs.id }
}

extension TimelineEntry: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
