import SwiftUI

struct PumpLoggingSheet: View {
    let access: BabyAccess?
    let existingSession: PumpSession?

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var form: PumpFormModel
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false
    @State private var previousPumpEndTime: Date?
    @FocusState private var focusedAmountField: AmountField?

    private let showPumpRate: Bool
    private let durationMemory = PumpDurationMemory()
    private let debugBabyID = "debug-pump-verification"

    init(
        access: BabyAccess?,
        existingSession: PumpSession? = nil,
        volumeUnit: VolumeUnit,
        rememberDuration: Bool,
        showPumpRate: Bool
    ) {
        self.access = access
        self.existingSession = existingSession
        self.showPumpRate = showPumpRate
        let remembered = PumpDurationMemory().load(isEnabled: rememberDuration)
        _form = State(initialValue: PumpFormModel(
            session: existingSession,
            volumeUnit: volumeUnit,
            rememberedDurationSeconds: remembered
        ))
    }

    var body: some View {
        @Bindable var form = form

        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    categoryHeader
                    timerSection
                    manualDetails
                    amountSection
                    notesSection

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(AppFont.secondary)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("pump-error")
                    }

                    if form.isEditing {
                        deleteButton
                    }
                }
                .padding(.horizontal, BabyLogTheme.horizontalPadding)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(BabyLogTheme.cream)
            .background {
                BabyLogTheme.cream
                    .contentShape(Rectangle())
                    .onTapGesture { focusedAmountField = nil }
            }
            .navigationTitle(form.isEditing ? "Edit Pump" : "Pump")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || access == nil)
                    .accessibilityIdentifier("pump-save")
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Saving…")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall))
                }
            }
        }
        .background(BabyLogTheme.cream.ignoresSafeArea())
        .babyLogSheetPresentation()
        .interactiveDismissDisabled(isSaving)
        .task {
            restoreTimer()
            await applyPostNursingDefaultIfNeeded()
            if access == nil {
                errorMessage = "Sign in and select a baby to save. Timer controls remain available for UI verification."
            }
        }
        .task(id: rateLookupKey) {
            await loadPreviousPumpEndTime()
        }
        .alert("Delete pump session?", isPresented: $showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deleteSession() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the session for every caregiver.")
        }
    }

    @MainActor
    private func applyPostNursingDefaultIfNeeded() async {
        guard existingSession == nil, !form.isPostNursing, let babyID = access?.baby.id else { return }
        do {
            async let latestNursing = firstValue(from: environment.nursingRepository.observeLatest(babyID: babyID))
            async let latestPump = firstValue(from: environment.pumpRepository.observeLatest(babyID: babyID))
            let (nursingValue, pumpValue) = try await (latestNursing, latestPump)
            let nursing = nursingValue ?? nil
            let pump = pumpValue ?? nil
            if PumpPostNursingDefaultService.shouldDefaultOn(
                latestNursing: nursing,
                latestPump: pump
            ) {
                form.isPostNursing = true
            }
        } catch {
            // A smart default must never block logging while offline.
        }
    }

    private func firstValue<T>(from stream: AsyncThrowingStream<T, Error>) async throws -> T? {
        for try await value in stream { return value }
        return nil
    }

    private var categoryHeader: some View {
        EditableDateTimeCard(
            title: "Start time",
            date: Binding(get: { form.startTime }, set: form.setStartTime),
            category: .pump,
            icon: .pump,
            isEnabled: !hasActivePumpTimer
        )
    }

    @ViewBuilder
    private var timerSection: some View {
        if form.isEditing {
            EmptyView()
        } else if hasActivePumpTimer {
            PumpRunningTimerView(engine: environment.timerEngine)

            HStack {
                Button(environment.timerEngine.activeState?.isPaused == true ? "Resume" : "Pause") {
                    togglePause()
                }
                .buttonStyle(.bordered)
                .tint(TrackingCategory.pump.style.main)
                .frame(maxWidth: .infinity)

                Button("Stop") {
                    stopTimer()
                }
                .buttonStyle(.borderedProminent)
                .tint(TrackingCategory.pump.style.main)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("pump-stop-timer")
            }
        } else {
            Button {
                startTimer()
            } label: {
                Label("Start Timer", systemImage: "timer")
                    .font(AppFont.loggingRow)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.bordered)
            .tint(TrackingCategory.pump.style.main)
            .accessibilityIdentifier("pump-start-timer")
        }
    }

    private var manualDetails: some View {
        VStack(spacing: BabyLogTheme.cardSpacing) {
            if !hasActivePumpTimer {
                PumpDurationEditor(
                    title: "Duration",
                    durationSeconds: Binding(
                        get: { form.durationSeconds },
                        set: form.setDuration
                    )
                )
            }

            Toggle("Post nursing", isOn: Binding(
                get: { form.isPostNursing },
                set: { form.isPostNursing = $0 }
            ))
            .font(AppFont.loggingRow)
            .tint(TrackingCategory.pump.style.main)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(BabyLogTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusLarge))
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: BabyLogTheme.cardSpacing) {
            HStack {
                Text("Amounts")
                    .font(AppFont.loggingRow)
                Spacer()
                Text(form.volumeUnit.rawValue)
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
            SwiftUI.TimelineView(.periodic(from: .now, by: 30)) { context in
                PumpAmountInputsView(
                    form: form,
                    focusedField: $focusedAmountField,
                    rateElapsedSeconds: rateElapsedSeconds(at: context.date),
                    showsRates: showPumpRate
                )
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: BabyLogTheme.cardSpacing) {
            Text("Note")
                .font(AppFont.loggingRow)
            TextField("Optional note", text: Binding(
                get: { form.notes },
                set: { form.notes = $0 }
            ), axis: .vertical)
            .lineLimit(1...3)
            .padding(10)
            .background(BabyLogTheme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall)
                    .stroke(BabyLogTheme.divider)
            }
        }
    }

    private var deleteButton: some View {
        Button("Delete Pump Session", role: .destructive) {
            showsDeleteConfirmation = true
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityIdentifier("pump-delete")
    }

    private var hasActivePumpTimer: Bool {
        environment.timerEngine.activeState?.babyID == timerBabyID
            && environment.timerEngine.activeState?.timerType == .pump
    }

    private var timerBabyID: String {
        access?.baby.id ?? debugBabyID
    }

    private var rateLookupKey: String {
        "\(access?.baby.id ?? "debug")|\(form.startTime.timeIntervalSinceReferenceDate)"
    }

    private func rateElapsedSeconds(at now: Date) -> TimeInterval? {
        guard let previousPumpEndTime else { return nil }
        let currentEndTime = hasActivePumpTimer
            ? now
            : form.startTime.addingTimeInterval(form.durationSeconds)
        let elapsed = currentEndTime.timeIntervalSince(previousPumpEndTime)
        return elapsed > 0 ? elapsed : nil
    }

    @MainActor
    private func loadPreviousPumpEndTime() async {
        guard showPumpRate, let access else {
            previousPumpEndTime = nil
            return
        }
        do {
            let previous = try await environment.pumpRepository.fetchSessionImmediatelyBefore(
                babyID: access.baby.id,
                startTime: form.startTime,
                excludingID: existingSession?.id
            )
            previousPumpEndTime = previous?.endTime
        } catch {
            previousPumpEndTime = nil
        }
    }

    private func restoreTimer() {
        guard !form.isEditing else { return }
        do {
            _ = try environment.timerEngine.restore(babyID: timerBabyID, timerType: .pump)
            if let state = environment.timerEngine.activeState {
                form.setStartTime(state.startTime)
            }
        } catch {
            errorMessage = "The saved timer couldn’t be restored."
        }
    }

    private func startTimer() {
        do {
            try environment.timerEngine.start(babyID: timerBabyID, timerType: .pump)
            if let state = environment.timerEngine.activeState {
                form.setStartTime(state.startTime)
            }
            errorMessage = nil
        } catch {
            errorMessage = "The timer couldn’t be started."
        }
    }

    private func togglePause() {
        do {
            if environment.timerEngine.activeState?.isPaused == true {
                try environment.timerEngine.resume()
            } else {
                try environment.timerEngine.pause()
            }
            errorMessage = nil
        } catch {
            errorMessage = "The timer couldn’t be updated."
        }
    }

    private func stopTimer() {
        guard let state = environment.timerEngine.activeState else { return }
        let measured = environment.timerEngine.elapsedSeconds()
        do {
            _ = try environment.timerEngine.finish()
            form.applyTimerStop(startTime: state.startTime, measuredDuration: measured)
            errorMessage = nil
        } catch {
            errorMessage = "The timer couldn’t be stopped."
        }
    }

    @MainActor
    private func save() async {
        guard let access else { return }
        guard form.validate() else {
            errorMessage = form.validationMessage
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
                _ = try await environment.pumpRepository.update(session)
            } else {
                try await environment.pumpRepository.create(session)
            }
            durationMemory.save(
                form.durationSeconds,
                isEnabled: environment.preferences.values.rememberPumpDuration
            )
            dismiss()
        } catch {
            errorMessage = "Couldn’t save. Your entry is still here; try again when the connection is available."
        }
    }

    @MainActor
    private func deleteSession() async {
        guard let session = existingSession else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await environment.pumpRepository.delete(id: session.id, babyID: session.babyID)
            dismiss()
        } catch {
            errorMessage = "Couldn’t delete the session. Try again."
        }
    }
}
