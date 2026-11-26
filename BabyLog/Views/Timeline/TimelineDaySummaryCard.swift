import SwiftUI

/// Day summary card (design section 38): white date tile on the left, a
/// Feed/Pump/Diaper/Sleep/Other grid on the right. Shared by full-list and
/// summaries-only modes — only the surrounding container/tap affordance
/// differs between `TimelineView`'s two layouts.
struct TimelineDaySummaryCard: View {
    let section: TimelineDaySection
    let filter: TimelineFilter
    let preferences: UserPreferences
    let pumpRate: Double?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            dateTile
            if let category = filter.category {
                focusedRow(category)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(TrackingCategory.allCases.filter { filter.selectedCategories.contains($0) }) { category in
                        row(category)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(BabyLogTheme.brown100)
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall))
    }

    private var dateTile: some View {
        VStack(spacing: 4) {
            VStack(spacing: 0) {
                Text(TimelineSummaryFormatter.weekdayAbbreviation(for: section.id))
                    .font(AppFont.avenirNext(9, weight: .bold))
                    .tracking(0.72)
                    .foregroundStyle(BabyLogTheme.mutedText)
                Text(TimelineSummaryFormatter.dayNumber(for: section.id))
                    .font(AppFont.avenirNext(19, weight: .bold))
                    .foregroundStyle(BabyLogTheme.ink)
                Text(TimelineSummaryFormatter.monthAbbreviation(for: section.id))
                    .font(AppFont.avenirNext(9, weight: .demiBold))
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
            .padding(.vertical, 5)
            .frame(width: BabyLogTheme.timelineDateTileWidth)
            .background(BabyLogTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusTiny))

            if section.usesCustomDayStart {
                Text(TimelineSummaryFormatter.dayStartTimeText(dayStartMinutes: section.dayStartMinutes))
                    .font(AppFont.avenirNext(9, weight: .demiBold))
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
        }
        .frame(width: BabyLogTheme.timelineDateTileWidth)
    }

    @ViewBuilder
    private func row(_ category: TrackingCategory) -> some View {
        HStack(spacing: 6) {
            icon(for: category).frame(width: 16, alignment: .leading)
            Text(line(for: category))
                .font(AppFont.avenirNext(14, weight: .demiBold))
                .foregroundStyle(category.style.text)
                .lineLimit(2)
                .truncationMode(.tail)
        }
    }

    @ViewBuilder
    private func focusedRow(_ category: TrackingCategory) -> some View {
        HStack(spacing: 6) {
            icon(for: category).frame(width: 16)
            Text(line(for: category))
                .font(AppFont.avenirNext(15, weight: .demiBold))
                .lineLimit(2)
                .foregroundStyle(category.style.text)
        }
    }

    @ViewBuilder
    private func icon(for category: TrackingCategory) -> some View {
        switch category {
        case .feed: ActivityIconView(icon: .bottle, color: category.style.main).frame(width: BabyLogTheme.timelineSummaryIconSize, height: BabyLogTheme.timelineSummaryIconSize)
        case .pump: ActivityIconView(icon: .pump, color: category.style.main).frame(width: BabyLogTheme.timelineSummaryIconSize, height: BabyLogTheme.timelineSummaryIconSize)
        case .diaper: ActivityIconView(icon: .diaper, color: category.style.main).frame(width: BabyLogTheme.timelineSummaryIconSize, height: BabyLogTheme.timelineSummaryIconSize)
        case .sleep: ActivityIconView(icon: .sleep, color: category.style.main).frame(width: BabyLogTheme.timelineSummaryIconSize, height: BabyLogTheme.timelineSummaryIconSize)
        case .other:
            Image(systemName: "checklist")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(category.style.main)
                .frame(width: BabyLogTheme.timelineSummaryIconSize, height: BabyLogTheme.timelineSummaryIconSize)
        }
    }

    private func label(for category: TrackingCategory) -> String {
        switch category {
        case .feed: return "Feed"
        case .pump: return "Pump"
        case .diaper: return "Diaper"
        case .sleep: return "Sleep"
        case .other: return "Other"
        }
    }

    private func line(for category: TrackingCategory) -> String {
        switch category {
        case .feed: return TimelineSummaryFormatter.feedLine(section.summary.feed, unit: preferences.volumeUnit)
        case .pump:
            return TimelineSummaryFormatter.pumpLine(
                section.summary.pump,
                unit: preferences.volumeUnit,
                showRate: preferences.showPumpRate,
                rate: pumpRate
            )
        case .diaper: return TimelineSummaryFormatter.diaperLine(section.summary.diaper)
        case .sleep: return TimelineSummaryFormatter.sleepLine(section.summary.sleep)
        case .other: return TimelineSummaryFormatter.otherLine(section.summary.other)
        }
    }
}
