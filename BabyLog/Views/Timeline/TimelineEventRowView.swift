import SwiftUI

/// One Timeline event row (design section 39): 36pt icon tile, bold time +
/// category-colored primary summary, optional Brown 700 second line and
/// small tag, chevron. At most two lines; tapping opens the real editor.
struct TimelineEventRowView: View {
    let entry: TimelineEntry
    let preferences: UserPreferences
    let priorAwake: TimeInterval?
    let pumpRate: Double?
    let nursingEstimate: NursingEstimate?
    let now: Date
    let isLast: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                iconTile
                content
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(BabyLogTheme.timelineChevron)
            }
            .padding(.horizontal, BabyLogTheme.horizontalPadding)
            .padding(.vertical, 9)
            .frame(minHeight: 44)
            .background(BabyLogTheme.surface)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(BabyLogTheme.divider).frame(height: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var rowText: TimelineRowText {
        switch entry.kind {
        case .pump(let session):
            return TimelineRowFormatter.pump(session, unit: preferences.volumeUnit, showRate: preferences.showPumpRate, rate: pumpRate)
        case .bottle(let feed):
            return TimelineRowFormatter.bottle(feed, unit: preferences.volumeUnit)
        case .nursing(let session):
            return TimelineRowFormatter.nursing(session, estimate: nursingEstimate, unit: preferences.volumeUnit)
        case .sleep(let session):
            return TimelineRowFormatter.sleep(session, priorAwake: priorAwake, now: now)
        case .diaper(let event):
            return TimelineRowFormatter.diaper(event)
        case .checklist(let event, let item):
            return TimelineRowFormatter.checklist(event, item: item)
        case .growth(let measurement):
            return TimelineRowFormatter.growth(measurement, unitSystem: preferences.growthUnitSystem)
        }
    }

    private var iconTile: some View {
        Group {
            switch entry.kind {
            case .pump:
                ActivityIconView(icon: .pump, color: entry.category.style.main).frame(width: 21, height: 21)
            case .bottle:
                ActivityIconView(icon: .bottle, color: entry.category.style.main).frame(width: 21, height: 21)
            case .nursing:
                ActivityIconView(icon: .nursing, color: entry.category.style.main).frame(width: 21, height: 21)
            case .sleep:
                ActivityIconView(icon: .sleep, color: entry.category.style.main).frame(width: 21, height: 21)
            case .diaper:
                ActivityIconView(icon: .diaper, color: entry.category.style.main).frame(width: 21, height: 21)
            case .checklist(_, let item):
                Image(systemName: item?.symbol ?? "checklist")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(entry.category.style.main)
            case .growth:
                Image(systemName: "ruler")
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(entry.category.style.main)
            }
        }
        .frame(width: BabyLogTheme.timelineRowIconTileSize, height: BabyLogTheme.timelineRowIconTileSize)
        .background(entry.category.style.soft)
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusTiny))
        .accessibilityHidden(true)
    }

    private var content: some View {
        let text = rowText
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(text.time)
                    .font(AppFont.avenirNext(12, weight: .bold))
                    .foregroundStyle(BabyLogTheme.brown800)
                Text(text.primary)
                    .font(AppFont.avenirNext(13, weight: .demiBold))
                    .foregroundStyle(entry.category.style.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            if text.secondary != nil || text.tag != nil {
                HStack(spacing: 6) {
                    if let secondary = text.secondary {
                        Text(secondary)
                            .font(AppFont.avenirNext(12, weight: .medium))
                            .foregroundStyle(BabyLogTheme.brown700)
                            .lineLimit(1)
                    }
                    if let tag = text.tag {
                        tagView(tag)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tagView(_ text: String) -> some View {
        Text(text)
            .font(AppFont.avenirNext(9, weight: .bold))
            .tracking(0.54)
            .foregroundStyle(entry.category.style.text)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(entry.category.style.soft)
            .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusChip))
    }
}
