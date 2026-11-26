import SwiftUI

struct SleepLoggingSheet: View {
    let access: BabyAccess?
    let existingSession: SleepSession?

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var form: SleepFormModel
    @State private var openSessions: [SleepSession] = []
    @State private var locallyStoppedSessionIDs: Set<String> = []
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false
    @State private var wasTimerStopped = false
    @State private var isRecordingSoothing = false
    @State private var lastRecordedSoothingTime: Date?
    @State private var showsSoothingEditor = false

    init(access: BabyAccess?, existingSession: SleepSession? = nil) {
        self.access = access
        self.existingSession = existingSession
        _form = State(initialValue: SleepFormModel(session: existingSession))
    }

    var body: some View {
        @Bindable var form = form

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    startTimeCard
                    endTimeCard
                    durationEditor

                    if activeSession == nil {
                        soothingSummaryLine
                    }

                    if let activeSession {
                        runningSection(activeSession)
                    } else if wasTimerStopped {
                        restartButton
                    } else if form.endTime == nil, existingSession == nil {
                        startButton
                    }

                    notesSection

                    if !extraOpenSessions.isEmpty { duplicateNotice }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(AppFont.secondary)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if existingSession != nil { deleteButton }
                }
                .padding(BabyLogTheme.horizontalPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BabyLogTheme.cream)
            .navigationTitle(existingSession == nil ? "Sleep" : "Edit Sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isWorking || access == nil || (form.endTime == nil && !form.isEditing))
                        .accessibilityIdentifier("sleep-save")
                }
            }
        }
        .babyLogSheetPresentation()
        .interactiveDismissDisabled(isWorking)
        .task(id: access?.baby.id) { await observeOpenSessions() }
        .task {
            if access == nil { errorMessage = "Sign in and select a baby to start or save Sleep." }
        }
        .alert("Delete sleep?", isPresented: $showsDeleteConfirmation) {
            Button("Delete", role: .destructive) { Task { await deleteSession() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the sleep for every caregiver.")
        }
        .sheet(isPresented: $showsSoothingEditor) {
            SoothingTimesEditorSheet(
                soothingTimes: $form.soothingTimes,
                addSoothingTime: { form.addSoothingTime() }
            )
        }
    }

    private var visibleOpenSessions: [SleepSession] {
        SleepCalculator.excludingLocallyCompleted(locallyStoppedSessionIDs, from: openSessions)
    }

    private var soothingSummary: String {
        let times = form.soothingTimes
            .map(\.date)
            .sorted()
            .map { AppFormatters.time().string(from: $0) }

        guard !times.isEmpty else {
            return "No soothing times recorded."
        }

        let count = times.count
        return "Soothed \(count) time\(count == 1 ? "" : "s") at \(times.joined(separator: ", "))."
    }
    private var activeSession: SleepSession? { SleepCalculator.activeSession(in: visibleOpenSessions) }
    private var extraOpenSessions: [SleepSession] { SleepCalculator.extraOpenSessions(in: visibleOpenSessions) }

    private var soothingSummaryLine: some View {
        HStack(spacing: 4) {
            Text(soothingSummary)
                .font(AppFont.secondary)
                .foregroundStyle(BabyLogTheme.mutedText)
            Button {
                showsSoothingEditor = true
            } label: {
                Text("Edit")
                    .font(AppFont.secondary.weight(.semibold))
                    .underline()
            }
            .accessibilityLabel("Edit soothing times")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var startTimeCard: some View {
        EditableDateTimeCard(
            title: "Start time",
            date: Binding(get: { form.startTime }, set: form.setStartTime),
            category: .sleep,
            icon: .sleep,
            isEnabled: activeSession == nil
        )
    }

    private var startButton: some View {
        Button {
            Task { await startSleep() }
        } label: {
            Label("Start Sleep", systemImage: "moon.zzz.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .tint(TrackingCategory.sleep.style.main)
        .disabled(isWorking || access == nil)
        .accessibilityIdentifier("sleep-start")
    }

    private var endTimeCard: some View {
        OptionalEditableDateTimeCard(
            title: "End time",
            date: Binding(get: { form.endTime }, set: form.setEndTime),
            category: .sleep,
            minimumDate: form.startTime,
            isEnabled: activeSession == nil
        )
    }

    private var durationEditor: some View {
        OptionalDurationEditor(
            title: "Duration",
            durationSeconds: Binding(
                get: { form.durationSeconds },
                set: { if let value = $0 { form.setDuration(seconds: value) } }
            )
        )
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(BabyLogTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusLarge))
        .allowsHitTesting(activeSession == nil)
        .opacity(activeSession == nil ? 1 : 0.65)
    }

    private var restartButton: some View {
        Button("Restart Timer") { restartTimer() }
            .buttonStyle(.bordered)
            .tint(TrackingCategory.sleep.style.main)
            .frame(maxWidth: .infinity)
    }

    private func runningSection(_ session: SleepSession) -> some View {
        VStack(spacing: BabyLogTheme.cardSpacing) {
            SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                timerCard(duration: SleepCalculator.duration(of: session, now: context.date), title: "Sleeping…")
            }
            Button { stopTimer(session) } label: {
                Text("Stop Sleep")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
                .buttonStyle(.borderedProminent)
                .tint(TrackingCategory.sleep.style.main)
                .font(AppFont.primaryRow.bold())
                .accessibilityIdentifier("sleep-stop")
            Button {
                Task { await recordSoothing(session) }
            } label: {
                Label("Needed soothing", systemImage: "moon.stars")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(TrackingCategory.sleep.style.main)
            .disabled(isRecordingSoothing)
            soothingSummaryLine
            if let lastRecordedSoothingTime {
                Text("Successfully recorded that \(access?.baby.name ?? "Baby") needed soothing at \(lastRecordedSoothingTime, format: .dateTime.hour().minute()).")
                    .font(AppFont.secondary)
                    .foregroundStyle(TrackingCategory.sleep.style.text)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("sleep-soothing-confirmation")
            }
            Button("Cancel Sleep", role: .destructive) {
                Task { await cancelActiveSleep(session) }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func timerCard(duration: TimeInterval, title: LocalizedStringKey) -> some View {
        VStack(spacing: 5) {
            Text(title).font(AppFont.eyebrow).foregroundStyle(TrackingCategory.sleep.style.text)
            Text(runningDurationText(duration))
                .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(BabyLogTheme.headingPadding)
        .background(TrackingCategory.sleep.style.soft)
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusLarge))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: BabyLogTheme.cardSpacing) {
            Text("Note").font(AppFont.primaryRow)
            TextField("Optional note", text: $form.notes, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(BabyLogTheme.surface)
                .overlay { RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall).stroke(BabyLogTheme.divider) }
        }
    }

    private var duplicateNotice: some View {
        VStack(alignment: .leading, spacing: BabyLogTheme.cardSpacing) {
            Label("Extra open Sleep session\(extraOpenSessions.count == 1 ? "" : "s")", systemImage: "exclamationmark.triangle")
                .font(AppFont.primaryRow)
            Text("The earliest session remains active. Delete extras after reviewing them.")
                .font(AppFont.secondary).foregroundStyle(BabyLogTheme.mutedText)
            ForEach(extraOpenSessions) { session in
                Button("Delete extra from \(session.startTime, formatter: AppFormatters.dateAndTime())", role: .destructive) {
                    Task { await deleteExtra(session) }
                }
            }
        }
        .padding(BabyLogTheme.headingPadding)
        .background(BabyLogTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusLarge))
    }

    private var deleteButton: some View {
        Button("Delete Sleep", role: .destructive) { showsDeleteConfirmation = true }
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    @MainActor private func observeOpenSessions() async {
        guard existingSession == nil, let babyID = access?.baby.id else { return }
        do {
            for try await sessions in environment.sleepRepository.observeOpenSessions(babyID: babyID) {
                openSessions = sessions
                if form.endTime == nil, let active = SleepCalculator.activeSession(in: visibleOpenSessions) {
                    form = SleepFormModel(session: active)
                }
            }
        } catch { errorMessage = "Sleep updates are temporarily unavailable." }
    }

    @MainActor private func startSleep() async {
        guard let access else { return }
        isWorking = true; defer { isWorking = false }
        do {
            form.setEndTime(nil)
            let proposed = try form.makeSession(babyID: access.baby.id, userID: access.membership.userID)
            let active = try await environment.sleepRepository.startIfNeeded(proposed)
            form = SleepFormModel(session: active)
            errorMessage = nil
        } catch SleepRepositoryError.overlappingSession {
            errorMessage = "This Sleep overlaps an existing session."
        } catch { errorMessage = "Couldn’t start Sleep. Try again." }
    }

    private func stopTimer(_ session: SleepSession) {
        form.finishTimer(at: .now)
        locallyStoppedSessionIDs.insert(session.id)
        wasTimerStopped = true
        errorMessage = nil
    }

    private func restartTimer() {
        guard let session = form.originalSession else { return }
        form.setEndTime(nil)
        locallyStoppedSessionIDs.remove(session.id)
        wasTimerStopped = false
        errorMessage = nil
    }

    @MainActor private func cancelActiveSleep(_ session: SleepSession) async {
        isWorking = true; defer { isWorking = false }
        do {
            try await environment.sleepRepository.delete(id: session.id, babyID: session.babyID)
            locallyStoppedSessionIDs.remove(session.id)
            openSessions.removeAll { $0.id == session.id }
            form = SleepFormModel()
            wasTimerStopped = false
            errorMessage = nil
        } catch { errorMessage = "Couldn’t cancel Sleep. Try again." }
    }

    @MainActor private func save() async {
        guard let access else { return }
        isWorking = true; defer { isWorking = false }
        do {
            let session = try form.makeSession(babyID: access.baby.id, userID: access.membership.userID)
            if form.isEditing { _ = try await environment.sleepRepository.update(session) }
            else { try await environment.sleepRepository.create(session) }
            dismiss()
        } catch SleepRepositoryError.overlappingSession {
            errorMessage = "This Sleep overlaps an existing session."
        } catch SleepSessionError.invalidTimeRange {
            errorMessage = "End time must be after Start time."
        } catch { errorMessage = "Couldn’t save Sleep. Your entry is still here; try again." }
    }

    @MainActor private func recordSoothing(_ session: SleepSession) async {
        let recordedAt = Date.now
        isRecordingSoothing = true
        defer { isRecordingSoothing = false }
        do {
            let updated = try await environment.sleepRepository.update(session.addingSoothing(at: recordedAt))
            if let index = openSessions.firstIndex(where: { $0.id == updated.id }) {
                openSessions[index] = updated
            }
            form.setSoothingTimes(updated.soothingTimes)
            lastRecordedSoothingTime = recordedAt
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t record that soothing was needed. Try again."
        }
    }

    @MainActor private func deleteSession() async {
        guard let session = existingSession else { return }
        isWorking = true; defer { isWorking = false }
        do {
            try await environment.sleepRepository.delete(id: session.id, babyID: session.babyID)
            dismiss()
        } catch { errorMessage = "Couldn’t delete the Sleep session." }
    }

    @MainActor private func deleteExtra(_ session: SleepSession) async {
        do { try await environment.sleepRepository.delete(id: session.id, babyID: session.babyID) }
        catch { errorMessage = "Couldn’t delete the extra session." }
    }

    private func durationText(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int((interval / 60).rounded()))
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }

    private func runningDurationText(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.down)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        return hours > 0 ? "\(hours)h \(minutes)m \(remainder)s" : "\(minutes)m \(remainder)s"
    }
}

private struct SoothingTimesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var soothingTimes: [SleepFormModel.SoothingTime]
    let addSoothingTime: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if soothingTimes.isEmpty {
                    ContentUnavailableView(
                        "No soothing times",
                        systemImage: "moon.stars",
                        description: Text("Add a time when soothing was needed.")
                    )
                } else {
                    ForEach($soothingTimes) { $soothingTime in
                        DatePicker(
                            "Soothed at",
                            selection: $soothingTime.date,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    .onDelete { offsets in
                        soothingTimes.remove(atOffsets: offsets)
                    }
                }

                Button {
                    addSoothingTime()
                } label: {
                    Label("Add soothing time", systemImage: "plus")
                }
            }
            .navigationTitle("Needed soothing")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        soothingTimes.sort { $0.date < $1.date }
                        dismiss()
                    }
                }
            }
        }
        .babyLogSheetPresentation()
    }
}
