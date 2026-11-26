import SwiftUI

struct BottleLoggingSheet: View {
    let access: BabyAccess?
    let existingFeed: BottleFeed?

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var form: BottleFormModel
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false

    init(
        access: BabyAccess?,
        existingFeed: BottleFeed? = nil,
        volumeUnit: VolumeUnit
    ) {
        self.access = access
        self.existingFeed = existingFeed
        _form = State(initialValue: BottleFormModel(
            feed: existingFeed,
            volumeUnit: volumeUnit
        ))
    }

    var body: some View {
        @Bindable var form = form

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    categoryHeader
                    amountSection
                    notesSection

                    if let message = errorMessage ?? form.validationMessage {
                        Label(message, systemImage: "exclamationmark.triangle.fill")
                            .font(AppFont.secondary)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("bottle-error")
                    }

                    if form.isEditing {
                        deleteButton
                    }
                }
                .padding(BabyLogTheme.horizontalPadding)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(BabyLogTheme.cream)
            .navigationTitle(form.isEditing ? "Edit Bottle" : "Bottle")
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
                    .accessibilityIdentifier("bottle-save")
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
        .babyLogSheetPresentation()
        .interactiveDismissDisabled(isSaving)
        .task {
            if access == nil {
                errorMessage = "Sign in and select a baby to save. Fields remain available for UI verification."
            }
        }
        .task(id: access?.baby.id) {
            await loadAutofill()
        }
        .alert("Delete bottle?", isPresented: $showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deleteFeed() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the bottle for every caregiver.")
        }
    }

    private var categoryHeader: some View {
        EditableDateTimeCard(
            title: "Time",
            date: Binding(get: { form.startTime }, set: form.setStartTime),
            category: .feed,
            icon: .bottle
        )
    }

    private var amountSection: some View {
        VStack(alignment: .leading, spacing: BabyLogTheme.cardSpacing) {
            HStack {
                Text("Amounts")
                    .font(AppFont.primaryRow)
                Spacer()
                Text(form.volumeUnit.rawValue)
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
            BottleAmountInputsView(form: form)
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: BabyLogTheme.cardSpacing) {
            Text("Note")
                .font(AppFont.primaryRow)
            TextField(
                "Optional note",
                text: Binding(
                    get: { form.notes },
                    set: { form.notes = $0 }
                ),
                axis: .vertical
            )
            .lineLimit(2...5)
            .padding(.vertical, 4)
        }
        .babyLogCard()
    }

    private var deleteButton: some View {
        Button("Delete Bottle", role: .destructive) {
            showsDeleteConfirmation = true
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .accessibilityIdentifier("bottle-delete")
    }

    @MainActor
    private func loadAutofill() async {
        guard existingFeed == nil,
              environment.preferences.values.bottleAutofill == .lastUsed,
              let babyID = access?.baby.id
        else { return }

        do {
            if let nearby = try await nearbyYesterdayFeed(babyID: babyID) {
                form.applyAutofill(from: nearby)
                return
            }
            for try await latest in environment.bottleRepository.observeLatest(babyID: babyID) {
                if let latest { form.applyAutofill(from: latest) }
                break
            }
        } catch {
            // Autofill is optional; a read failure must not block manual logging.
        }
    }

    /// Prefers yesterday's entry at a similar time of day (±1 hour) over the
    /// simple "most recent" fallback, so autofill reflects the baby's usual
    /// schedule rather than whatever was logged most recently overall.
    @MainActor
    private func nearbyYesterdayFeed(babyID: String) async throws -> BottleFeed? {
        guard let yesterdayAnchor = Calendar.autoupdatingCurrent.date(byAdding: .day, value: -1, to: form.startTime)
        else { return nil }
        let interval = DateInterval(
            start: yesterdayAnchor.addingTimeInterval(-3_600),
            // Repository ranges use an exclusive end; add one millisecond so
            // an entry exactly one hour after the anchor remains eligible.
            end: yesterdayAnchor.addingTimeInterval(3_600.001)
        )
        for try await feeds in environment.bottleRepository.observe(babyID: babyID, interval: interval) {
            return BottleAutofillSelector.closest(to: yesterdayAnchor, among: feeds)
        }
        return nil
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
            let feed = try form.makeFeed(
                babyID: access.baby.id,
                userID: access.membership.userID
            )
            if form.isEditing {
                _ = try await environment.bottleRepository.update(feed)
            } else {
                try await environment.bottleRepository.create(feed)
            }
            dismiss()
        } catch {
            errorMessage = "Couldn’t save. Your entry is still here; try again when the connection is available."
        }
    }

    @MainActor
    private func deleteFeed() async {
        guard let feed = existingFeed else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await environment.bottleRepository.delete(
                id: feed.id,
                babyID: feed.babyID
            )
            dismiss()
        } catch {
            errorMessage = "Couldn’t delete the bottle. Try again."
        }
    }
}
