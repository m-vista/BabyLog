import SwiftUI

struct NursingLoggingSheet: View {
    let access: BabyAccess?
    let existingSession: NursingSession?

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var form: NursingFormModel
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false
    @State private var previousLastSide: NursingSide?

    private let debugBabyID = "debug-nursing-verification"

    init(
        access: BabyAccess?,
        existingSession: NursingSession? = nil
    ) {
        self.access = access
        self.existingSession = existingSession
        _form = State(initialValue: NursingFormModel(session: existingSession))
    }

    var body: some View {
        @Bindable var form = form

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    categoryHeader

                    if hasActiveTimer {
                        activeTimerSection
                    } else {
                        startSection
                        finalizedSection
                    }

                    notesSection

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(AppFont.secondary)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if form.isEditing {
                        deleteButton
                    }
                }
                .padding(BabyLogTheme.horizontalPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BabyLogTheme.cream)
            .navigationTitle(form.isEditing ? "Edit Nursing" : "Nursing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(
                        isSaving
                            || access == nil
                    )
                    .accessibilityIdentifier("nursing-save")
                }
            }
        }
        .babyLogSheetPresentation()
        .interactiveDismissDisabled(isSaving)
        .task {
            restoreTimer()
            if access == nil {
                errorMessage = "Sign in and select a baby to save. Timer controls remain available for UI verification."
            }
        }
        .task(id: access?.baby.id) { await loadPreviousLastSide() }
        .alert("Delete nursing session?", isPresented: $showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deleteSession() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the session for every caregiver.")
        }
    }

    private var categoryHeader: some View {
        EditableDateTimeCard(
            title: "Start time",
            date: Binding(get: { form.startTime }, set: form.setStartTime),
            category: .feed,
            icon: .nursing,
            isEnabled: !hasActiveTimer
        )
    }

    private var startSection: some View {
        VStack(spacing: BabyLogTheme.cardSpacing) {
            HStack(spacing: BabyLogTheme.cardSpacing) {
                startButton(side: .left)
                startButton(side: .right)
            }
            lastSideLabel(previousLastSide)
        }
    }

    private func startButton(side: NursingSide) -> some View {
        Button {
            startTimer(side: side)
        } label: {
            NursingSideCardLabel(title: sideTitle(side), durationText: "0m", action: .start)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start \(sideTitle(side)) side")
        .accessibilityIdentifier("nursing-start-\(side.rawValue)")
    }

    private var activeTimerSection: some View {
        let canEnd = NursingTimerControls.canEndSession(isPaused: environment.timerEngine.activeState?.isPaused == true)
        return VStack(spacing: BabyLogTheme.cardSpacing) {
            NursingTimerPanel(engine: environment.timerEngine, onTapSide: handleSideTap)
            lastSideLabel(previousLastSide)

            Button { stopTimer() } label: {
                Text("End session")
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
                .buttonStyle(.borderedProminent)
                .tint(TrackingCategory.feed.style.main)
                .font(AppFont.primaryRow.bold())
                .disabled(!canEnd)
                .accessibilityIdentifier("nursing-stop")
            if !canEnd {
                Text("Pause the timer to end the session.")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
        }
    }

    private var finalizedSection: some View {
        VStack(spacing: BabyLogTheme.cardSpacing) {
            HStack(spacing: BabyLogTheme.cardSpacing) {
                PumpDurationEditor(
                    title: "Left",
                    durationSeconds: Binding(
                        get: { form.leftDurationSeconds },
                        set: form.setLeftDuration
                    )
                )
                PumpDurationEditor(
                    title: "Right",
                    durationSeconds: Binding(
                        get: { form.rightDurationSeconds },
                        set: form.setRightDuration
                    )
                )
            }

            HStack {
                Text("Total")
                Spacer()
                Text(durationText(form.totalDurationSeconds))
                    .monospacedDigit()
            }
            .font(AppFont.primaryRow)

            VStack(alignment: .leading, spacing: 7) {
                Text("Last side")
                    .font(AppFont.secondary.bold())
                    .foregroundStyle(BabyLogTheme.mutedText)
                Picker("Last side", selection: Binding(get: { form.lastSide }, set: form.setLastSide)) {
                    Text("Left").tag(NursingSide.left)
                    Text("Right").tag(NursingSide.right)
                }
                .pickerStyle(.segmented)
            }

        }
        .padding(BabyLogTheme.headingPadding)
        .background(BabyLogTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusLarge))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: BabyLogTheme.cardSpacing) {
            Text("Note")
                .font(AppFont.primaryRow)
            TextField("Optional note", text: $form.notes, axis: .vertical)
                .lineLimit(2...5)
                .padding(12)
                .background(BabyLogTheme.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall)
                        .stroke(BabyLogTheme.divider)
                }
        }
    }

    private var deleteButton: some View {
        Button("Delete Nursing Session", role: .destructive) {
            showsDeleteConfirmation = true
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private var timerBabyID: String {
        access?.baby.id ?? debugBabyID
    }

    private var hasActiveTimer: Bool {
        environment.timerEngine.activeState?.babyID == timerBabyID
            && environment.timerEngine.activeState?.timerType == .nursing
    }

    private func lastSideLabel(_ side: NursingSide?) -> some View {
        Text("Last \(side.map { $0 == .left ? "L" : "R" } ?? "–")")
            .font(AppFont.secondary)
            .foregroundStyle(BabyLogTheme.mutedText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sideTitle(_ side: NursingSide) -> String {
        side == .left ? "Left" : "Right"
    }

    @MainActor
    private func loadPreviousLastSide() async {
        guard existingSession == nil, let babyID = access?.baby.id else { return }
        do {
            for try await latest in environment.nursingRepository.observeLatest(babyID: babyID) {
                previousLastSide = latest?.lastSide
                if let previousLastSide {
                    form.setLastSide(previousLastSide)
                }
                break
            }
        } catch {
            previousLastSide = nil
        }
    }

    private func restoreTimer() {
        guard !form.isEditing else { return }
        do {
            let restored = try environment.timerEngine.restore(
                babyID: timerBabyID,
                timerType: .nursing
            )
            if let recordedStart = restored?.recordedSessionStartTime {
                form.setStartTime(recordedStart)
            }
        } catch {
            errorMessage = "The saved Nursing timer couldn’t be restored."
        }
    }

    private func startTimer(side: NursingSide) {
        do {
            try environment.timerEngine.start(
                babyID: timerBabyID,
                timerType: .nursing,
                nursingSide: side,
                recordedSessionStartTime: form.startTime
            )
            errorMessage = nil
        } catch {
            errorMessage = "The Nursing timer couldn’t be started."
        }
    }

    private func handleSideTap(_ side: NursingSide) {
        let engine = environment.timerEngine
        let action = NursingTimerControls.action(
            for: side,
            activeSide: engine.activeState?.activeNursingSide,
            isPaused: engine.activeState?.isPaused ?? true
        )
        do {
            switch action {
            case .pause:
                try engine.pause()
            case .switchSide:
                try engine.switchNursingSide(to: side)
            case .start:
                try engine.switchNursingSide(to: side)
                try engine.resume()
            }
            errorMessage = nil
        } catch {
            errorMessage = "The Nursing timer couldn’t be updated."
        }
    }

    private func stopTimer() {
        do {
            let state = try environment.timerEngine.finish()
            let durations = NursingDurations(
                leftSeconds: state.leftAccumulatedSeconds,
                rightSeconds: state.rightAccumulatedSeconds
            )
            form.applyTimerStop(
                state: state,
                durations: durations
            )
            errorMessage = nil
        } catch {
            errorMessage = "The Nursing timer couldn’t be stopped."
        }
    }

    private func durationText(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        let hours = minutes / 60
        return hours > 0 ? "\(hours)h \(minutes % 60)m" : "\(minutes)m"
    }

    @MainActor
    private func save() async {
        guard let access else { return }
        if hasActiveTimer {
            dismiss()
            return
        }
        isSaving = true
        defer { isSaving = false }

        do {
            let session = try form.makeSession(
                babyID: access.baby.id,
                userID: access.membership.userID
            )
            if form.isEditing {
                _ = try await environment.nursingRepository.update(session)
            } else {
                try await environment.nursingRepository.create(session)
            }
            dismiss()
        } catch {
            errorMessage = "Couldn’t save. Check the times and try again."
        }
    }

    @MainActor
    private func deleteSession() async {
        guard let session = existingSession else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await environment.nursingRepository.delete(
                id: session.id,
                babyID: session.babyID
            )
            dismiss()
        } catch {
            errorMessage = "Couldn’t delete the Nursing session. Try again."
        }
    }
}
