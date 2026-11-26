import Charts
import SwiftUI

struct AnalyticsView: View {
    let access: BabyAccess?
    let isActive: Bool
    @Environment(AppEnvironment.self) private var environment
    @State private var model = AnalyticsViewModel()
    @State private var selectedDate = Date.now

    init(access: BabyAccess? = nil, isActive: Bool = true) {
        self.access = access
        self.isActive = isActive
    }

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 60)) { context in
            if let access {
                let referenceDate = Calendar.autoupdatingCurrent.isDateInToday(selectedDate) ? context.date : selectedDate
                content(snapshot: model.snapshot(access: access, preferences: environment.preferences.values, now: referenceDate), baby: access.baby)
            } else {
                PlaceholderScreen(tab: .analytics)
            }
        }
        .ignoresSafeArea(edges: .top)
        .task(id: subscriptionKey) {
            guard isActive, let access else {
                model.stop()
                return
            }
            model.start(access: access, environment: environment, preferences: environment.preferences.values, now: selectedDate)
        }
    }

    private var subscriptionKey: String {
        let p = environment.preferences.values
        let day = Calendar.autoupdatingCurrent.startOfDay(for: selectedDate).timeIntervalSinceReferenceDate
        return "\(access?.baby.id ?? "none")|\(model.range.rawValue)|\(day)|\(p.dayStartMinutes)|\(p.useCustomDayInAnalytics)|\(isActive)"
    }

    private func content(snapshot: AnalyticsSnapshot, baby: Baby) -> some View {
        let showsGrowth = model.category == nil || model.category == .other
        let hasGrowth = showsGrowth && !model.growthMeasurements.isEmpty
        return VStack(spacing: 0) {
            AnalyticsHeader(category: model.category, range: model.range, interval: snapshot.interval)
            AnalyticsCategoryBar(selection: $model.category)
            AnalyticsRangeBar(selection: $model.range)
            AnalyticsDateNavigator(selection: $selectedDate, range: model.range, interval: snapshot.interval)
            if model.isLoading {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.errorMessage, !snapshot.hasData(for: model.category) && !hasGrowth {
                CompactContentStateView(
                    icon: "wifi.slash",
                    title: "Analytics unavailable",
                    message: LocalizedStringKey(error),
                    retry: restart
                )
            } else if !snapshot.hasData(for: model.category) && !hasGrowth {
                CompactContentStateView(
                    icon: "chart.bar",
                    title: "No data yet",
                    message: "Log activity to see analytics for this range."
                )
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        if let category = model.category {
                            if snapshot.hasData(for: category) {
                                AnalyticsCategoryContent(
                                    category: category,
                                    snapshot: snapshot,
                                    unit: environment.preferences.values.volumeUnit,
                                    onSwipeRange: moveRange
                                )
                            }
                        } else if snapshot.hasData(for: nil) {
                            AnalyticsOverview(snapshot: snapshot, unit: environment.preferences.values.volumeUnit) { model.category = $0 }
                        }
                        if showsGrowth {
                            GrowthAnalyticsSection(
                                measurements: model.growthMeasurements,
                                baby: baby,
                                unitSystem: environment.preferences.values.growthUnitSystem
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(BabyLogTheme.cream)
    }

    private func moveRange(_ direction: Int) {
        let days = direction
        let moved = Calendar.autoupdatingCurrent.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate
        selectedDate = min(moved, .now)
    }

    private func restart() {
        guard let access else { return }
        model.start(
            access: access,
            environment: environment,
            preferences: environment.preferences.values,
            now: selectedDate
        )
    }
}

private struct AnalyticsHeader: View {
    let category: TrackingCategory?
    let range: AnalyticsRange
    let interval: DateInterval
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(category.map(AnalyticsFormat.categoryName) ?? "All categories")
                .font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText)
            Text("Analytics").font(AppFont.screenTitle).foregroundStyle(BabyLogTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 54).padding(.horizontal, 20).padding(.bottom, 10)
    }
}

private struct AnalyticsDateNavigator: View {
    @Binding var selection: Date
    let range: AnalyticsRange
    let interval: DateInterval

    var body: some View {
        HStack {
            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel("Previous day")
            Spacer()
            Text(CalendarText.range(interval))
                .font(AppFont.primaryRow)
                .foregroundStyle(BabyLogTheme.ink)
                .multilineTextAlignment(.center)
            Spacer()
            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .disabled(Calendar.autoupdatingCurrent.isDateInToday(selection))
                .accessibilityLabel("Next day")
        }
        .font(.caption.bold())
        .foregroundStyle(BabyLogTheme.brown700)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .accessibilityElement(children: .contain)
    }

    private func move(_ days: Int) {
        let value = Calendar.autoupdatingCurrent.date(byAdding: .day, value: days, to: selection) ?? selection
        selection = min(value, .now)
    }
}

private struct AnalyticsCategoryBar: View {
    @Binding var selection: TrackingCategory?
    var body: some View {
        HStack(spacing: 2) {
            button(nil) { Text("All").font(AppFont.secondary).fontWeight(.bold) }
            ForEach(TrackingCategory.allCases) { category in
                button(category) { AnalyticsIcon(category: category).frame(width: 20, height: 20) }
            }
        }
        .padding(3).background(BabyLogTheme.surface).clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: BabyLogTheme.shadowColorMedium, radius: 6, y: 1)
        .padding(.horizontal, 16)
    }

    private func button<Content: View>(_ category: TrackingCategory?, @ViewBuilder content: () -> Content) -> some View {
        Button { selection = category } label: {
            content().frame(maxWidth: .infinity, minHeight: 38)
                .foregroundStyle(category?.style.main ?? BabyLogTheme.brown800)
                .background(selection == category ? (category?.style.soft ?? BabyLogTheme.brown100) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.map(AnalyticsFormat.categoryName) ?? "All categories")
        .accessibilityAddTraits(selection == category ? .isSelected : [])
    }
}

private struct AnalyticsRangeBar: View {
    @Binding var selection: AnalyticsRange
    var body: some View {
        HStack(spacing: 3) {
            ForEach(AnalyticsRange.allCases) { range in
                Button(range.title) { selection = range }
                    .font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText)
                    .frame(maxWidth: .infinity, minHeight: 32)
                    .background(selection == range ? BabyLogTheme.surface : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .shadow(color: selection == range ? BabyLogTheme.shadowColorMedium : .clear, radius: 3, y: 1)
            }
        }
        .padding(3).background(BabyLogTheme.brown100).clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

struct AnalyticsIcon: View {
    let category: TrackingCategory
    var body: some View {
        switch category {
        case .feed: ActivityIconView(icon: .bottle, color: category.style.main)
        case .sleep: ActivityIconView(icon: .sleep, color: category.style.main)
        case .diaper: ActivityIconView(icon: .diaper, color: category.style.main)
        case .pump: ActivityIconView(icon: .pump, color: category.style.main)
        case .other: Image(systemName: "checkmark.square").foregroundStyle(category.style.main)
        }
    }
}
