import Charts
import SwiftUI

struct AnalyticsOverview: View {
    let snapshot: AnalyticsSnapshot
    let unit: VolumeUnit
    let onSelect: (TrackingCategory) -> Void
    var body: some View {
        VStack(spacing: 8) {
            overview(.feed, value: AnalyticsFormat.volume(snapshot.feed.bottleAmountMl / Double(snapshot.dayCount), unit), unitText: unit.rawValue, subtitle: "\(AnalyticsFormat.decimal(Double(snapshot.feed.bottleCount) / Double(snapshot.dayCount))) feeds a day", points: snapshot.feed.dailyBottleMl)
            overview(.sleep, value: AnalyticsFormat.duration(snapshot.sleep.totalSeconds / Double(snapshot.dayCount)), unitText: "", subtitle: "Naps \(AnalyticsFormat.duration(snapshot.sleep.napSeconds)) · Night \(AnalyticsFormat.duration(snapshot.sleep.nightSeconds))", points: snapshot.sleep.dailySeconds)
            overview(.diaper, value: AnalyticsFormat.decimal(Double(snapshot.diaper.changes) / Double(snapshot.dayCount)), unitText: "changes", subtitle: "Wet \(snapshot.diaper.wet) · Dirty \(snapshot.diaper.dirty)", points: snapshot.diaper.dailyChanges)
            overview(.pump, value: AnalyticsFormat.volume(snapshot.pump.totalMl / Double(snapshot.dayCount), unit), unitText: unit.rawValue, subtitle: "\(AnalyticsFormat.decimal(Double(snapshot.pump.sessionCount) / Double(snapshot.dayCount))) sessions a day", points: snapshot.pump.dailyMl)
            overview(.other, value: AnalyticsFormat.percent(snapshot.other.completion), unitText: "", subtitle: "\(snapshot.other.completedCount) of \(snapshot.other.possibleCount) items", points: snapshot.other.dailyCompletion)
            Text("Tap a category for its full stats").font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText).padding(.top, 2)
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
    }

    private func overview(_ category: TrackingCategory, value: String, unitText: String, subtitle: String, points: [AnalyticsPoint]) -> some View {
        Button { onSelect(category) } label: {
            HStack(spacing: 12) {
                AnalyticsIcon(category: category).frame(width: 21, height: 21).frame(width: 40, height: 40).background(category.style.soft).clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 1) {
                    Text(AnalyticsFormat.featureLabel(category)).font(AppFont.eyebrow).tracking(1).foregroundStyle(BabyLogTheme.mutedText)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(value).font(.headline).foregroundStyle(category.style.text)
                        Text(unitText).font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText)
                    }
                    Text(subtitle).font(AppFont.secondary).foregroundStyle(BabyLogTheme.brown700).lineLimit(2)
                }
                Spacer(minLength: 2)
                AnalyticsSparkline(points: points, color: category.style.main).frame(width: 64, height: 34)
            }
            .padding(.horizontal, 14).padding(.vertical, 12).background(BabyLogTheme.surface).clipShape(RoundedRectangle(cornerRadius: 5))
            .shadow(color: BabyLogTheme.shadowColor, radius: 10, y: 2)
        }.buttonStyle(.plain)
    }
}

struct AnalyticsCategoryContent: View {
    let category: TrackingCategory
    let snapshot: AnalyticsSnapshot
    let unit: VolumeUnit
    let onSwipeRange: (Int) -> Void
    var body: some View {
        let presentation = AnalyticsPresentation(category: category, snapshot: snapshot, unit: unit)
        VStack(spacing: 10) {
            AnalyticsFeaturedCard(presentation: presentation, category: category, volumeUnit: unit, onSwipeRange: onSwipeRange)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(presentation.stats) { stat in AnalyticsStatCard(stat: stat) }
            }
            AnalyticsBreakdownCard(title: presentation.breakdownTitle, rows: presentation.breakdown, category: category)
        }
        .padding(.horizontal, 16).padding(.bottom, 16)
    }
}

private struct AnalyticsFeaturedCard: View {
    let presentation: AnalyticsPresentation
    let category: TrackingCategory
    let volumeUnit: VolumeUnit
    let onSwipeRange: (Int) -> Void
    @State private var selectedPointDate: Date?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.label).font(AppFont.eyebrow).tracking(1.2).foregroundStyle(BabyLogTheme.mutedText)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(presentation.value).font(.largeTitle.bold()).foregroundStyle(BabyLogTheme.ink)
                    Text(presentation.unit).font(.caption.weight(.semibold)).foregroundStyle(BabyLogTheme.mutedText)
                }
                Text(presentation.subtitle).font(AppFont.secondary).foregroundStyle(BabyLogTheme.brown700)
            }
            Text(presentation.chartUnit)
                .font(AppFont.secondary.bold())
                .foregroundStyle(BabyLogTheme.mutedText)
            Chart(presentation.points) { point in
                BarMark(
                    x: .value("Day", point.id),
                    y: .value(presentation.chartUnit, point.value),
                    width: .fixed(barWidth)
                )
                    .foregroundStyle(category.style.main.opacity(point.id == presentation.points.last?.id ? 1 : 0.62))
                    .cornerRadius(3)
                if selectedPointDate == point.id {
                    RuleMark(x: .value("Selected", point.id))
                        .foregroundStyle(BabyLogTheme.brown700.opacity(0.45))
                        .annotation(position: .top, alignment: .center) {
                            VStack(spacing: 1) {
                                Text(point.id.formatted(date: .abbreviated, time: .omitted))
                                Text(AnalyticsFormat.chartValue(point.value, category: category, volumeUnit: volumeUnit))
                                    .fontWeight(.bold)
                            }
                            .font(AppFont.eyebrow)
                            .foregroundStyle(BabyLogTheme.ink)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(BabyLogTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .shadow(color: BabyLogTheme.shadowColorMedium, radius: 4, y: 1)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(7, max(1, presentation.points.count)))) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxisLabel("Date")
            .chartXSelection(value: $selectedPointDate)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let frame = proxy.plotFrame else { return }
                            let origin = geometry[frame].origin
                            guard let date = proxy.value(atX: location.x - origin.x, as: Date.self) else { return }
                            selectedPointDate = presentation.points.min {
                                abs($0.id.timeIntervalSince(date)) < abs($1.id.timeIntervalSince(date))
                            }?.id
                        }
                }
            }
            .frame(height: 220)
            .padding(.leading, 4)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(BabyLogTheme.divider).frame(height: 1) }
        }
        .padding(.horizontal, 16).padding(.vertical, 12).background(BabyLogTheme.surface).clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: BabyLogTheme.shadowColor, radius: 10, y: 2)
    }

    private var barWidth: CGFloat {
        if presentation.points.count <= 1 { return 52 }
        if presentation.points.count <= 7 { return 24 }
        if presentation.points.count <= 14 { return 12 }
        return 6
    }

}

private struct AnalyticsStatCard: View {
    let stat: AnalyticsStat
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stat.title).font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText)
            Text(stat.value).font(.headline).foregroundStyle(stat.tint ?? BabyLogTheme.ink)
            Text(stat.subtitle).font(AppFont.eyebrow).foregroundStyle(BabyLogTheme.muted).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading).padding(.horizontal, 14).padding(.vertical, 11)
        .background(BabyLogTheme.surface).clipShape(RoundedRectangle(cornerRadius: 5)).shadow(color: BabyLogTheme.shadowColor, radius: 10, y: 2)
    }
}

private struct AnalyticsBreakdownCard: View {
    let title: String
    let rows: [AnalyticsBreakdown]
    let category: TrackingCategory
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(AppFont.eyebrow).tracking(1.2).foregroundStyle(BabyLogTheme.mutedText)
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Text(row.label).font(AppFont.secondary).foregroundStyle(BabyLogTheme.ink).frame(minWidth: 78, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(category.style.soft)
                            RoundedRectangle(cornerRadius: 3).fill(category.style.main).frame(width: proxy.size.width * min(1, max(0, row.fraction)))
                        }
                    }.frame(height: 8)
                    Text(row.text).font(AppFont.secondary).fontWeight(.bold).foregroundStyle(BabyLogTheme.ink).frame(minWidth: 62, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12).background(BabyLogTheme.surface).clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: BabyLogTheme.shadowColor, radius: 10, y: 2)
    }
}

private struct AnalyticsSparkline: View {
    let points: [AnalyticsPoint]; let color: Color
    var body: some View {
        Chart(points) { point in BarMark(x: .value("Day", point.id), y: .value("Value", point.value)).foregroundStyle(color.opacity(point.id == points.last?.id ? 1 : 0.5)).cornerRadius(2) }
        .chartXAxis(.hidden).chartYAxis(.hidden)
    }
}
