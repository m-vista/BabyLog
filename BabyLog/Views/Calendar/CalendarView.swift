import SwiftUI

struct CalendarView: View {
    let access: BabyAccess?
    let isActive: Bool

    @Environment(AppEnvironment.self) private var environment
    @State private var model = CalendarViewModel()
    @State private var selectedMarkID: String?
    @State private var editorDestination: TimelineEditorDestination?
    @State private var visibleStartDate: Date?

    init(access: BabyAccess? = nil, isActive: Bool = true) {
        self.access = access
        self.isActive = isActive
    }

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 30)) { context in
            calendarContent(now: context.date)
        }
        .ignoresSafeArea(edges: .top)
        .task(id: subscriptionKey) {
            guard isActive, let access else {
                model.stop()
                return
            }
            model.start(
                access: access,
                environment: environment,
                preferences: environment.preferences.values
            )
            selectedMarkID = nil
        }
        .sheet(item: $editorDestination) { destination in
            TimelineEditorSheet(destination: destination, access: access)
        }
    }

    private var subscriptionKey: String {
        let categories = model.filter.selectedCategories.map(\.rawValue).sorted().joined(separator: ",")
        let values = environment.preferences.values
        return "\(access?.baby.id ?? "none")|\(model.range.rawValue)|\(categories)|\(values.dayStartMinutes)|\(values.useCustomDayInCalendar)|\(isActive)"
    }

    private func calendarContent(now: Date) -> some View {
        let preferences = environment.preferences.values
        let layout = model.layout(preferences: preferences, now: now)
        let selected = layout.marks.first { $0.id == selectedMarkID }
        return VStack(spacing: 0) {
            CalendarHeaderView(interval: visibleInterval(in: layout), range: $model.range, preferences: preferences)
            CalendarFilterBar(filter: $model.filter)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            if model.isLoading && layout.marks.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = model.errorMessage, layout.marks.isEmpty {
                CompactContentStateView(
                    icon: "wifi.slash",
                    title: "Calendar unavailable",
                    message: LocalizedStringKey(error),
                    retry: restart
                )
            } else if layout.marks.isEmpty && !model.filter.isEmptyMulti {
                CompactContentStateView(
                    icon: "calendar",
                    title: "No activity yet",
                    message: "Logged activity in this range will appear here."
                )
            } else {
                CalendarGridView(
                    layout: layout,
                    range: model.range,
                    selectedMarkID: selectedMarkID,
                    visibleStartDate: $visibleStartDate,
                    onSelect: { selectedMarkID = $0 }
                )
                .simultaneousGesture(
                    MagnifyGesture().onEnded { value in
                        let next = model.range.afterPinch(scale: value.magnification)
                        if next != model.range { withAnimation(.snappy) { model.range = next } }
                    }
                )
            }

            CalendarDetailStrip(
                mark: selected,
                emptyMulti: model.filter.isEmptyMulti,
                growthUnitSystem: preferences.growthUnitSystem
            ) {
                guard let selected, let destination = TimelineEditorDestination(entry: selected.entry) else { return }
                editorDestination = destination
            }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
        }
        .background(BabyLogTheme.cream)
        .onChange(of: layout.days) { _, days in
            guard visibleStartDate == nil, !days.isEmpty else { return }
            visibleStartDate = days[max(0, days.count - model.range.rawValue)].id
        }
        .onChange(of: model.range) { _, range in
            guard !layout.days.isEmpty else { return }
            visibleStartDate = layout.days[max(0, layout.days.count - range.rawValue)].id
        }
        .onChange(of: visibleStartDate) { _, date in
            guard isActive, let access, let date else { return }
            model.extendOlderIfNeeded(
                visibleStartDate: date,
                access: access,
                environment: environment,
                preferences: preferences
            )
        }
    }

    private func visibleInterval(in layout: CalendarLayout) -> DateInterval {
        guard !layout.days.isEmpty else { return layout.interval }
        let startIndex = visibleStartDate.flatMap { value in layout.days.firstIndex { $0.id == value } }
            ?? max(0, layout.days.count - model.range.rawValue)
        let endIndex = min(layout.days.count - 1, startIndex + model.range.rawValue - 1)
        return DateInterval(start: layout.days[startIndex].interval.start, end: layout.days[endIndex].interval.end)
    }

    private func restart() {
        guard let access else { return }
        model.start(access: access, environment: environment, preferences: environment.preferences.values)
    }
}

private struct CalendarHeaderView: View {
    let interval: DateInterval
    @Binding var range: CalendarRange
    let preferences: UserPreferences

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Calendar · day starts \(CalendarText.dayStart(preferences))")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
                Text(CalendarText.range(interval))
                    .font(AppFont.screenTitle)
                    .foregroundStyle(BabyLogTheme.ink)
            }
            Spacer()
            HStack(spacing: 0) {
                ForEach(CalendarRange.allCases) { value in
                    Button(value.title) { range = value }
                        .font(AppFont.secondary).fontWeight(.bold)
                        .foregroundStyle(BabyLogTheme.mutedText)
                        .frame(minWidth: 38, minHeight: 30)
                        .background(range == value ? BabyLogTheme.surface : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .shadow(color: range == value ? BabyLogTheme.shadowColorMedium : .clear, radius: 2, y: 1)
                }
            }
            .padding(3)
            .background(BabyLogTheme.brown100)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.top, 54)
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
    }
}

private struct CalendarFilterBar: View {
    @Binding var filter: CalendarFilter

    var body: some View {
        HStack(spacing: 2) {
            filterButton(label: "All", category: nil)
            ForEach(TrackingCategory.allCases) { category in
                filterButton(label: nil, category: category)
            }
            Button {
                if case .multi = filter { filter = .all } else { filter = .multi([]) }
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .foregroundStyle(isMulti ? Color.white : BabyLogTheme.brown800)
                    .background(isMulti ? BabyLogTheme.brown800 : .clear)
            }
            .buttonStyle(.plain)
        }
        .padding(3)
        .background(BabyLogTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .shadow(color: BabyLogTheme.shadowColor, radius: 5, y: 2)
    }

    private var isMulti: Bool { if case .multi = filter { true } else { false } }

    @ViewBuilder private func filterButton(label: String?, category: TrackingCategory?) -> some View {
        let selected = category.map { filter.selectedCategories.contains($0) && filter != .all } ?? (filter == .all)
        Button {
            if let category {
                if case .multi = filter { filter.select(category) } else { filter = .single(category) }
            } else { filter = .all }
        } label: {
            Group {
                if let label { Text(label).font(AppFont.secondary).fontWeight(.bold) }
                else if let category { CalendarCategoryIcon(category: category) }
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .foregroundStyle(category?.style.main ?? BabyLogTheme.brown800)
            .background(selected ? (category?.style.soft ?? BabyLogTheme.brown100) : .clear)
            .overlay {
                if selected, isMulti, let category {
                    RoundedRectangle(cornerRadius: 4).stroke(category.style.main, lineWidth: 1.5)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.map(categoryLabel) ?? "All categories")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func categoryLabel(_ category: TrackingCategory) -> String {
        switch category {
        case .feed: "Feed"
        case .sleep: "Sleep"
        case .diaper: "Diaper"
        case .pump: "Pump"
        case .other: "Other"
        }
    }
}

private struct CalendarCategoryIcon: View {
    let category: TrackingCategory
    var body: some View {
        Group {
            switch category {
            case .feed: ActivityIconView(icon: .bottle, color: category.style.main)
            case .sleep: ActivityIconView(icon: .sleep, color: category.style.main)
            case .diaper: ActivityIconView(icon: .diaper, color: category.style.main)
            case .pump: ActivityIconView(icon: .pump, color: category.style.main)
            case .other: Image(systemName: "checkmark.square").foregroundStyle(category.style.main)
            }
        }
        .frame(width: 19, height: 19)
    }
}
