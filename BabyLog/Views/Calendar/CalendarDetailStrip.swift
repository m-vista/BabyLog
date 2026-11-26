import SwiftUI

struct CalendarDetailStrip: View {
    let mark: CalendarMark?
    let emptyMulti: Bool
    let growthUnitSystem: GrowthUnitSystem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                if let mark {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(mark.category.style.main)
                        .frame(width: 10, height: 10)
                    Text(CalendarText.detail(mark.entry, growthUnitSystem: growthUnitSystem))
                        .font(AppFont.secondary)
                        .foregroundStyle(BabyLogTheme.ink)
                        .lineLimit(1)
                } else {
                    Text(emptyMulti ? "Pick one or more categories above" : "Tap a bar to see what it is")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(BabyLogTheme.mutedText)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(BabyLogTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: BabyLogTheme.shadowColor, radius: 5, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(mark == nil)
    }
}

enum CalendarText {
    static func dayStart(_ preferences: UserPreferences) -> String {
        let start = Calendar.autoupdatingCurrent.startOfDay(for: .now)
            .addingTimeInterval(TimeInterval(preferences.dayStartMinutes * 60))
        return AppFormatters.time().string(from: start)
    }

    static func range(_ interval: DateInterval) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let last = interval.end.addingTimeInterval(-1)
        let startMonth = month(interval.start)
        if calendar.isDate(interval.start, equalTo: last, toGranularity: .month) {
            return "\(startMonth) \(day(interval.start)) – \(day(last))"
        }
        return "\(startMonth) \(day(interval.start)) – \(month(last)) \(day(last))"
    }

    static func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date)
    }

    static func day(_ date: Date) -> String {
        String(Calendar.autoupdatingCurrent.component(.day, from: date))
    }

    static func axisTime(_ date: Date) -> String {
        let full = AppFormatters.time().string(from: date)
        return full
            .replacingOccurrences(of: ":00", with: "")
            .replacingOccurrences(of: " AM", with: "a")
            .replacingOccurrences(of: " PM", with: "p")
    }

    static func detail(_ entry: TimelineEntry, growthUnitSystem: GrowthUnitSystem = .metric) -> String {
        switch entry.kind {
        case .sleep(let session):
            let end = session.endTime ?? .now
            return "Sleep · \(timeRange(session.startTime, end)) · \(duration(end.timeIntervalSince(session.startTime)))"
        case .pump(let session):
            return "Pump · \(AppFormatters.time().string(from: session.startTime)) · \(duration(TimeInterval(session.durationSeconds)))"
        case .bottle(let feed):
            return "Bottle · \(AppFormatters.time().string(from: feed.startTime))"
        case .nursing(let session):
            return "Nursing · \(AppFormatters.time().string(from: session.startTime)) · \(duration(TimeInterval(session.totalDurationSeconds)))"
        case .diaper(let event):
            return "Diaper · \(AppFormatters.time().string(from: event.startTime)) · \(event.type.detailTitle)"
        case .checklist(let event, let item):
            return "\(item?.title ?? "Other") · \(AppFormatters.time().string(from: event.timestamp))"
        case .growth(let measurement):
            return "Growth · \(AppFormatters.time().string(from: measurement.timestamp)) · \(GrowthFormat.summary(measurement, unitSystem: growthUnitSystem))"
        }
    }

    private static func month(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        return formatter.string(from: date)
    }
    private static func timeRange(_ start: Date, _ end: Date) -> String {
        "\(AppFormatters.time().string(from: start)) – \(AppFormatters.time().string(from: end))"
    }
    private static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds / 60))
        let hours = minutes / 60
        let remainder = minutes % 60
        return hours > 0 ? "\(hours)h \(remainder)m" : "\(remainder)m"
    }
}
