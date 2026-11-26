import SwiftUI

/// Production Timeline (Phase 16), built on the Phase 15 aggregation layer.
/// Reproduces docs/prototypes/Timeline.dc.html (full list) and
/// TimelineSummaries.dc.html (summaries-only) as closely as practical.
struct TimelineView: View {
    let access: BabyAccess?
    let isActive: Bool

    @Environment(AppEnvironment.self) private var environment
    @State private var model = TimelineViewModel()
    @State private var scrolledID: Date?
    @State private var showsJumpSheet = false
    @State private var editorDestination: TimelineEditorDestination?
    @State private var pendingDeletion: TimelineEntry?
    @State private var deletionErrorMessage: String?

    init(access: BabyAccess? = nil, isActive: Bool = true) {
        self.access = access
        self.isActive = isActive
    }

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 30)) { context in
            content(now: context.date)
        }
        .ignoresSafeArea(edges: .top)
        .task(id: "\(access?.baby.id ?? "none")|\(isActive)") {
            guard isActive, let access else {
                model.stop()
                return
            }
            model.start(access: access, environment: environment, preferences: environment.preferences.values)
        }
        .task(id: "\(boundaryKey)|\(isActive)") {
            guard isActive, access != nil else { return }
            model.updateDayBoundaryIfNeeded(preferences: environment.preferences.values, environment: environment)
        }
        .sheet(isPresented: $showsJumpSheet) {
            TimelineJumpToDateSheet(initialDate: scrolledID ?? .now) { date in
                let target = model.jumpToDate(date, preferences: environment.preferences.values, environment: environment)
                model.displayMode = .fullList
                scrolledID = target
            }
        }
        .sheet(item: $editorDestination) { destination in
            TimelineEditorSheet(destination: destination, access: access)
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(
                get: { pendingDeletion != nil },
                set: { if !$0 { pendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let entry = pendingDeletion { deleteEntry(entry) }
                pendingDeletion = nil
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("This can’t be undone.")
        }
        .alert(
            "Couldn’t Delete",
            isPresented: Binding(
                get: { deletionErrorMessage != nil },
                set: { if !$0 { deletionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionErrorMessage ?? "")
        }
    }

    private func deleteEntry(_ entry: TimelineEntry) {
        Task {
            do {
                try await TimelineEntryDeletion.delete(entry, environment: environment)
            } catch {
                deletionErrorMessage = "That entry couldn’t be deleted. Please try again."
            }
        }
    }

    private var boundaryKey: String {
        let prefs = environment.preferences.values
        return "\(prefs.dayStartMinutes)|\(prefs.useCustomDayInTimeline)"
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let preferences = environment.preferences.values
        let todayStart = TrackingDayService.interval(containing: now, surface: .timeline, preferences: preferences).start
        let sections = model.sections(preferences: preferences, now: now)
        let focusedDayStart = scrolledID ?? todayStart

        VStack(spacing: 0) {
            TimelineHeaderView(
                focusedDayStart: focusedDayStart,
                todayStart: todayStart,
                displayMode: model.displayMode,
                onBackToToday: { scrolledID = todayStart },
                onToggleDisplayMode: {
                    model.displayMode = model.displayMode == .fullList ? .summariesOnly : .fullList
                },
                onTapDate: { showsJumpSheet = true }
            )
            TimelineFilterBar(selection: $model.filter)
            scrollableBody(sections: sections, preferences: preferences, now: now)
        }
        .background(BabyLogTheme.cream)
        .task(id: todayStart) {
            model.advanceToCurrentTrackingDayIfNeeded(
                preferences: preferences,
                environment: environment,
                now: now
            )
        }
    }

    @ViewBuilder
    private func scrollableBody(sections: [TimelineDaySection], preferences: UserPreferences, now: Date) -> some View {
        if sections.isEmpty {
            emptyOrLoadingState
        } else {
            ScrollView {
                LazyVStack(spacing: model.displayMode == .summariesOnly ? 8 : 0) {
                    ForEach(sections) { section in
                        sectionView(section, preferences: preferences, now: now)
                            .id(section.id)
                    }
                    bottomSentinel(preferences: preferences)
                }
                .scrollTargetLayout()
                .padding(.top, model.displayMode == .summariesOnly ? 10 : 0)
                .padding(.bottom, 24)
            }
            .scrollPosition(id: $scrolledID, anchor: .top)
            .scrollIndicators(.hidden)
            .modifier(TimelineSwipeActionsContainerModifier())
        }
    }

    @ViewBuilder
    private func sectionView(_ section: TimelineDaySection, preferences: UserPreferences, now: Date) -> some View {
        switch model.displayMode {
        case .summariesOnly:
            Button {
                model.displayMode = .fullList
                scrolledID = section.id
            } label: {
                TimelineDaySummaryCard(
                    section: section,
                    filter: model.filter,
                    preferences: preferences,
                    pumpRate: model.pumpRate(for: section.summary.pump)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, BabyLogTheme.horizontalPadding)

        case .fullList:
            VStack(spacing: 0) {
                TimelineDaySummaryCard(
                    section: section,
                    filter: model.filter,
                    preferences: preferences,
                    pumpRate: model.pumpRate(for: section.summary.pump)
                )
                    .padding(.horizontal, BabyLogTheme.horizontalPadding)
                    .padding(.top, 10)
                    .padding(.bottom, 8)

                VStack(spacing: 0) {
                    ForEach(Array(section.entries.enumerated()), id: \.element.id) { index, entry in
                        TimelineEventRowView(
                            entry: entry,
                            preferences: preferences,
                            priorAwake: priorAwake(for: entry),
                            pumpRate: pumpRate(for: entry),
                            nursingEstimate: nursingEstimate(for: entry),
                            now: now,
                            isLast: index == section.entries.count - 1,
                            onTap: { editorDestination = TimelineEditorDestination(entry: entry) },
                            onDelete: { pendingDeletion = entry }
                        )
                    }
                }
                .background(BabyLogTheme.surface)
                .overlay(alignment: .top) {
                    Rectangle().fill(BabyLogTheme.divider).frame(height: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func bottomSentinel(preferences: UserPreferences) -> some View {
        if model.isLoadingWindow {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 16)
        } else {
            Color.clear
                .frame(height: 1)
                .onAppear { model.extendOlder(preferences: preferences, environment: environment) }
        }
    }

    private var emptyOrLoadingState: some View {
        VStack(spacing: 10) {
            if model.isLoadingWindow {
                ProgressView()
                Text("Loading Timeline…")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
            } else if let errorMessage = model.errorMessage {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 26))
                    .foregroundStyle(BabyLogTheme.brown500)
                Text(errorMessage)
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
                    .multilineTextAlignment(.center)
            } else if model.filter != .all {
                Image(systemName: "tray")
                    .font(.system(size: 26))
                    .foregroundStyle(BabyLogTheme.brown500)
                Text("No Events")
                    .font(AppFont.loggingRow)
                    .foregroundStyle(BabyLogTheme.ink)
                Text("Nothing logged in this category yet.")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
            } else {
                Image(systemName: "list.bullet")
                    .font(.system(size: 26))
                    .foregroundStyle(BabyLogTheme.brown500)
                Text("No Events Yet")
                    .font(AppFont.loggingRow)
                    .foregroundStyle(BabyLogTheme.ink)
                Text("Logged activity will appear here.")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BabyLogTheme.horizontalPadding)
        .background(BabyLogTheme.cream)
    }

    private func priorAwake(for entry: TimelineEntry) -> TimeInterval? {
        guard case .sleep(let session) = entry.kind else { return nil }
        return TimelineAggregator.priorAwakeDuration(before: session, allSleepSessions: model.allSleepSessions)
    }

    private func pumpRate(for entry: TimelineEntry) -> Double? {
        guard case .pump(let session) = entry.kind else { return nil }
        return model.pumpRate(for: session)
    }

    private func nursingEstimate(for entry: TimelineEntry) -> NursingEstimate? {
        guard case .nursing(let session) = entry.kind else { return nil }
        return model.nursingEstimate(for: session)
    }
}

/// `swipeActionsContainer()` is iOS 27+; on earlier OS versions the row's
/// own `swipeActions` modifier (available since iOS 15, but effective only
/// inside a `List` pre-27) simply has no effect outside a `List`, so swipe
/// gestures are unavailable but tapping into the editor's own Delete button
/// still works. The app's deployment target is iOS 17.
private struct TimelineSwipeActionsContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content.swipeActionsContainer()
        } else {
            content
        }
    }
}

#Preview {
    TimelineView()
        .environment(AppEnvironment())
}
