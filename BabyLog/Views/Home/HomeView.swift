import SwiftUI
import UIKit

private enum HomeDestination: String, Identifiable {
    case pump, bottle, nursing, sleep, diaper, checklist, growth
    var id: String { rawValue }
}

private struct HomeObservationKey: Equatable {
    let babyID: String?
    let dayStart: Date
    let isActive: Bool
}

struct HomeView: View {
    let access: BabyAccess?
    let isActive: Bool
    let onOpenSettings: () -> Void
    let onAccessUpdated: (BabyAccess) -> Void
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model = HomeDashboardModel()
    @State private var destination: HomeDestination?
    @State private var selectedChecklistItem: ChecklistItem?
    @State private var showsBabyProfile = false
#if DEBUG
    @State private var developerDestination: DeveloperLoggerDestination?
#endif

    init(
        access: BabyAccess? = nil,
        isActive: Bool = true,
        onOpenSettings: @escaping () -> Void = {},
        onAccessUpdated: @escaping (BabyAccess) -> Void = { _ in }
    ) {
        self.access = access
        self.isActive = isActive
        self.onOpenSettings = onOpenSettings
        self.onAccessUpdated = onAccessUpdated
    }

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView {
                VStack(spacing: 0) {
                    header(now: context.date)
                    HomeChecklistSection(
                        items: model.checklistItems,
                        completions: model.checklistCompletion,
                        onSelect: { selectedChecklistItem = $0 },
                        onAdd: { destination = .checklist }
                    )
                    activityCards(now: context.date)
                        .padding(.top, 19)
                    if let errorMessage = model.errorMessage { Text(errorMessage).font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText).padding() }
#if DEBUG
                    if access == nil {
                        DisclosureGroup("Developer launchers") { DeveloperLauncherSection(destination: $developerDestination) }
                            .padding(BabyLogTheme.horizontalPadding)
                    }
#endif
                }
                .padding(.bottom, BabyLogTheme.tabBarItemHeight + 24)
            }
            .scrollIndicators(.hidden)
            .background(BabyLogTheme.cream)
            .ignoresSafeArea(edges: .top)
            .task(id: observationKey(now: context.date)) {
                guard isActive, let access else { return }
                await model.observe(access: access, environment: environment, preferences: environment.preferences.values, now: context.date)
            }
        }
        .task(id: access?.baby.id) {
            if let babyID = access?.baby.id {
                environment.babyPhotoStore.loadPhoto(for: babyID)
            }
        }
        .sheet(item: $destination, content: loggerSheet)
        .sheet(item: $selectedChecklistItem) { item in checklistSheet(item) }
        .sheet(isPresented: $showsBabyProfile) {
            if let access {
                NavigationStack {
                    BabySettingsEditor(access: access, onSaved: onAccessUpdated)
                }
            }
        }
#if DEBUG
        .sheet(item: $developerDestination) { destination in developerSheet(destination) }
#endif
    }

    private func header(now: Date) -> some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                if let photo = access.flatMap({ environment.babyPhotoStore.image(for: $0.baby.id) }) {
                    BabyPhotoCropPreview(
                        image: photo,
                        crop: environment.babyPhotoStore.crop(for: access?.baby.id ?? "")
                    )
                    .frame(width: proxy.size.width, height: proxy.size.height)
                        .overlay(BabyLogTheme.heroGradient.opacity(0.22))
                } else {
                    BabyLogTheme.heroGradient
                }
            }
            .allowsHitTesting(false)
            Circle().stroke(.white.opacity(0.08), lineWidth: 1).frame(width: 220, height: 220).offset(x: 245, y: -60)
            Circle().fill(.white.opacity(0.04)).frame(width: 150, height: 150).offset(x: 285, y: -16)
            Circle().stroke(.white.opacity(0.07), lineWidth: 1).frame(width: 90, height: 90).offset(x: -30, y: 40)
            HStack(spacing: 8) {
                headerButton(systemImage: "pencil", label: "Edit profile") {
                    showsBabyProfile = true
                }
                headerButton(systemImage: "gearshape", label: "Settings", action: onOpenSettings)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 54)
            .padding(.top, 14)
            .padding(.trailing, 16)
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(access?.baby.name ?? "BabyLog")
                        .font(AppFont.babyName)
                        .lineLimit(2)
                    Text(ageText(now: now))
                        .font(AppFont.avenirNext(12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                Text(now, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(AppFont.avenirNext(13, weight: .demiBold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .foregroundStyle(.white)
            .padding(BabyLogTheme.headingPadding)
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 250 : 190)
        .clipped()
    }

    private func headerButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.14))
                .overlay { Circle().stroke(.white.opacity(0.18)) }
                .clipShape(Circle())
        }
        .foregroundStyle(.white)
        .accessibilityLabel(label)
    }

    private func activityCards(now: Date) -> some View {
        VStack(spacing: BabyLogTheme.cardSpacing) {
            HStack(spacing: 4) {
                bottleCard(now: now)
                nursingCard(now: now)
            }
            sleepCard(now: now)
            diaperCard(now: now)
            pumpCard(now: now)
            growthCard(now: now)
        }
        .padding(.horizontal, BabyLogTheme.horizontalPadding)
    }

    private func bottleCard(now: Date) -> some View {
        let latest = model.latestBottle
        let unit = environment.preferences.values.volumeUnit
        let total = model.bottles.reduce(0) { $0 + $1.totalAmountMl }
        return HomeActivityCard(title: "Bottle", icon: .bottle, category: .feed, timeText: latest == nil ? "—" : "", primaryText: latest.map { HomeSummaryService.bottleDescription($0, unit: unit) } ?? "No bottles yet", summaryText: "\(model.bottles.count) times · \(volume(total))", eventDate: latest?.startTime, eventID: latest?.id, now: now, showsRelativeTimeByDefault: environment.preferences.values.showRelativeTimes, position: .leadingPair, action: { destination = .bottle })
    }

    private func nursingCard(now: Date) -> some View {
        let timer = timerState(.nursing)
        let latest = model.latestNursing
        let live = timer.map { liveDuration(elapsed($0, now: now)) }
        let primary = timer.map { "Nursing... \(($0.activeNursingSide == .left) ? "L" : "R") \(live ?? "0m 0s") · Last \(($0.activeNursingSide == .left) ? "L" : "R")" } ?? latest.map { "L \(HomeSummaryService.duration($0.leftDurationSeconds)) · R \(HomeSummaryService.duration($0.rightDurationSeconds)) · Last \($0.lastSide == .left ? "L" : "R")" } ?? "No nursing yet"
        let duration = model.nursing.reduce(0) { $0 + $1.totalDurationSeconds }
        return HomeActivityCard(title: "Nursing", icon: .nursing, category: .feed, timeText: timer == nil ? (latest == nil ? "—" : "") : "Now", primaryText: primary, italicizedWord: timer == nil ? nil : "Nursing...", summaryText: "\(model.nursing.count) sessions · \(HomeSummaryService.duration(duration))", eventDate: timer == nil ? latest?.startTime : nil, eventID: timer == nil ? latest?.id : nil, now: now, showsRelativeTimeByDefault: environment.preferences.values.showRelativeTimes, position: .trailingPair, action: { destination = .nursing })
    }

    private func sleepCard(now: Date) -> some View {
        if let active = model.activeSleep {
            let awake = SleepCalculator.awakeWindowBefore(session: active, previousCompleted: model.latestSleep)
                .map { HomeSummaryService.duration($0) } ?? "—"
            return HomeActivityCard(title: "Sleep", icon: .sleep, category: .sleep, timeText: AppFormatters.time().string(from: active.startTime), primaryText: "Awake \(awake) · Sleeping... \(liveDuration(now.timeIntervalSince(active.startTime)))", italicizedWord: "Sleeping...", summaryText: sleepDailySummary, action: { destination = .sleep })
        }
        let latest = model.latestSleep
        let range = latest.flatMap { sleep in sleep.endTime.map { "\(AppFormatters.time().string(from: sleep.startTime)) – \(AppFormatters.time().string(from: $0))" } } ?? "No sleep yet"
        let awake = liveDuration(SleepCalculator.currentAwakeDuration(latestCompleted: latest, now: now))
        let sleepState = latest.map { "Slept \(HomeSummaryService.duration(SleepCalculator.duration(of: $0))) · Awake... \(awake)" } ?? "Awake..."
        return HomeActivityCard(title: "Sleep", icon: .sleep, category: .sleep, timeText: range, primaryText: sleepState, summaryText: sleepDailySummary, action: { destination = .sleep })
    }

    private func diaperCard(now: Date) -> some View {
        let latest = model.latestDiaper
        let counts = HomeSummaryService.diaperCounts(model.diapers)
        let detail = latest.map {
            let type = $0.type == .both ? "Wet and Dirty" : $0.type.loggingTitle
            return type + ($0.fullness.map { " · \($0.title)" } ?? "")
        } ?? "No diapers yet"
        return HomeActivityCard(title: "Diaper", icon: .diaper, category: .diaper, timeText: latest == nil ? "—" : "", primaryText: detail, summaryText: "\(model.diapers.count) times · \(counts.wet) Wet · \(counts.dirty) Dirty", eventDate: latest?.startTime, eventID: latest?.id, now: now, showsRelativeTimeByDefault: environment.preferences.values.showRelativeTimes, action: { destination = .diaper })
    }

    private func pumpCard(now: Date) -> some View {
        let timer = timerState(.pump)
        let latest = model.latestPump
        let primary = timer.map { "Pumping... \(liveDuration(elapsed($0, now: now)))" } ?? latest.map { session in
            var text = "\(HomeSummaryService.duration(session.durationSeconds)) · \(volume(session.totalAmountMl))"
            if environment.preferences.values.showPumpRate {
                let rate = PumpRateService.sessionRate(
                    session,
                    previousSessionEndTime: PumpRateService.rateAnchorEndTime(
                        for: session,
                        previousPumpEndTime: model.previousPumpRecord?.endTime,
                        nursingSessions: model.latestNursing.map { [$0] } ?? []
                    )
                )
                text += " · \(pumpRateText(rate))"
            }
            return text
        } ?? "No pumps yet"
        let totalDuration = model.pumps.reduce(0) { $0 + $1.durationSeconds }
        let totalAmount = model.pumps.reduce(0) { $0 + $1.totalAmountMl }
        var summary = "\(model.pumps.count) times · \(HomeSummaryService.duration(totalDuration)) · \(volume(totalAmount))"
        if environment.preferences.values.showPumpRate, !model.pumps.isEmpty {
            let rate = PumpRateService.weightedCleanRate(
                sessions: model.pumps,
                sessionImmediatelyBeforeRange: model.pumpBeforeTrackingDay
            )
            summary += " · \(pumpRateText(rate))"
        }
        return HomeActivityCard(title: "Pump", icon: .pump, category: .pump, timeText: timer == nil ? (latest == nil ? "—" : "") : "Now", primaryText: primary, italicizedWord: timer == nil ? nil : "Pumping...", summaryText: summary, eventDate: timer == nil ? latest?.startTime : nil, eventID: timer == nil ? latest?.id : nil, now: now, showsRelativeTimeByDefault: environment.preferences.values.showRelativeTimes, action: { destination = .pump })
    }

    private func growthCard(now: Date) -> some View {
        let latest = model.latestGrowth
        return HomeActivityCard(
            title: "Growth",
            icon: nil,
            systemImage: "ruler",
            category: .other,
            timeText: latest == nil ? "—" : "",
            primaryText: latest.map { GrowthFormat.summary($0, unitSystem: environment.preferences.values.growthUnitSystem) } ?? "No measurements yet",
            summaryText: "Weight · Height · Head circumference",
            eventDate: latest?.timestamp,
            eventID: latest?.id,
            now: now,
            showsRelativeTimeByDefault: environment.preferences.values.showRelativeTimes,
            action: { destination = .growth }
        )
    }

    @ViewBuilder private func loggerSheet(_ destination: HomeDestination) -> some View {
        switch destination {
        case .pump: PumpLoggingSheet(access: access, volumeUnit: environment.preferences.values.volumeUnit, rememberDuration: environment.preferences.values.rememberPumpDuration, showPumpRate: environment.preferences.values.showPumpRate)
        case .bottle: BottleLoggingSheet(access: access, volumeUnit: environment.preferences.values.volumeUnit)
        case .nursing: NursingLoggingSheet(access: access)
        case .sleep: SleepLoggingSheet(access: access)
        case .diaper: DiaperLoggingSheet(access: access, rememberSize: environment.preferences.values.rememberDiaperSize)
        case .checklist: ChecklistLoggingSheet(access: access)
        case .growth: GrowthLoggingSheet(access: access)
        }
    }

    @ViewBuilder private func checklistSheet(_ item: ChecklistItem) -> some View {
        if let access {
            ChecklistConfirmationSheet(item: item, userID: access.membership.userID, event: model.checklistCompletion[item.id]) { event in
                if model.checklistCompletion[item.id] == nil { try await environment.checklistRepository.createEvent(event) }
                else { _ = try await environment.checklistRepository.updateEvent(event) }
            } onDelete: { event in try await environment.checklistRepository.deleteEvent(id: event.id, babyID: event.babyID) }
        }
    }

    /// Changes when the baby or the Home tracking day changes, restarting day-scoped observation.
    private func observationKey(now: Date) -> HomeObservationKey {
        HomeObservationKey(
            babyID: access?.baby.id,
            dayStart: TrackingDayService.interval(containing: now, surface: .home, preferences: environment.preferences.values).start,
            isActive: isActive
        )
    }

    private func timerState(_ type: TimerType) -> ActiveTimerState? {
        guard let babyID = access?.baby.id else { return nil }
        return try? DurableTimerStore().load(babyID: babyID, timerType: type)
    }

    private func elapsed(_ state: ActiveTimerState, now: Date) -> TimeInterval {
        let reference = state.isPaused ? (state.pauseStartedAt ?? state.startTime) : now
        return max(0, reference.timeIntervalSince(state.startTime) - state.accumulatedPausedSeconds)
    }

    private func liveDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.down)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        return hours > 0 ? "\(hours)h \(minutes)m \(remainder)s" : "\(minutes)m \(remainder)s"
    }

    private var sleepDailySummary: String {
        HomeSummaryService.sleepDailySummary(
            model.sleeps,
            nightStartMinutes: access?.baby.nightStartMinutes ?? Baby.defaultNightStartMinutes,
            nightEndMinutes: access?.baby.nightEndMinutes ?? Baby.defaultNightEndMinutes
        )
    }
    private func volume(_ ml: Double) -> String { "\(VolumeService.displayString(milliliters: ml, unit: environment.preferences.values.volumeUnit)) \(environment.preferences.values.volumeUnit.rawValue)" }
    private func pumpRateText(_ millilitersPerHour: Double?) -> String {
        guard let millilitersPerHour else {
            return "– \(environment.preferences.values.volumeUnit.rawValue)/hr"
        }
        return "\(volume(millilitersPerHour))/hr"
    }
    private func ageText(now: Date) -> String {
        guard let birthDate = access?.baby.birthDate else { return "Your daily care overview" }
        return HomeSummaryService.ageText(birthDate: birthDate, now: now)
    }

#if DEBUG
    @ViewBuilder private func developerSheet(_ destination: DeveloperLoggerDestination) -> some View {
        switch destination {
        case .pump: loggerSheet(.pump)
        case .bottle: loggerSheet(.bottle)
        case .nursing: loggerSheet(.nursing)
        case .sleep: loggerSheet(.sleep)
        case .diaper: loggerSheet(.diaper)
        case .checklistConfirmation: loggerSheet(.checklist)
        }
    }
#endif
}

#Preview { HomeView().environment(AppEnvironment()) }
