import SwiftUI

struct DiaperLoggingSheet: View {
    let access: BabyAccess?
    let existingEvent: DiaperEvent?

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var form: DiaperFormModel
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var showsDeleteConfirmation = false

    private let sizeMemory = DiaperSizeMemory()

    init(
        access: BabyAccess?,
        existingEvent: DiaperEvent? = nil,
        rememberSize: Bool
    ) {
        self.access = access
        self.existingEvent = existingEvent
        let rememberedSize = DiaperSizeMemory().load(isEnabled: rememberSize)
        _form = State(initialValue: DiaperFormModel(
            event: existingEvent,
            rememberedSize: rememberedSize
        ))
    }

    var body: some View {
        @Bindable var form = form

        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    categoryHeader
                    selectorsSection
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
            .navigationTitle(form.isEditing ? "Edit Diaper" : "Diaper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving || access == nil || !form.hasSelectedType)
                    .accessibilityIdentifier("diaper-save")
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
        .alert("Delete diaper?", isPresented: $showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deleteEvent() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the diaper for every caregiver.")
        }
    }

    private var categoryHeader: some View {
        EditableDateTimeCard(
            title: "Time",
            date: Binding(get: { form.startTime }, set: form.setStartTime),
            category: .diaper,
            icon: .diaper
        )
    }

    private var selectorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            selectorHeading("Type")
            HStack(spacing: 4) {
                ForEach(DiaperType.allCases, id: \.self) { type in
                    selectionButton(type.loggingTitle, isSelected: form.type == type) {
                        form.type = form.type == type ? nil : type
                    }
                }
            }

            selectorHeading("Fullness", trailing: "Optional")
            HStack(spacing: 4) {
                ForEach(DiaperFullness.allCases, id: \.self) { fullness in
                    selectionButton(fullness.title, isSelected: form.fullness == fullness) {
                        form.fullness = form.fullness == fullness ? nil : fullness
                    }
                }
            }

            selectorHeading(
                "Size",
                trailing: form.rememberedSize.map { "Last used: \($0.rawValue)" }
            )
            HStack(spacing: 3) {
                ForEach(DiaperSize.allCases, id: \.self) { size in
                    selectionButton(size.rawValue, isSelected: form.size == size, fontSize: 12) {
                        form.size = form.size == size ? nil : size
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: BabyLogTheme.cardSpacing) {
            Text("Note")
                .font(AppFont.primaryRow)
            TextField(
                "Optional note",
                text: $form.notes,
                axis: .vertical
            )
            .lineLimit(2...5)
            .padding(.vertical, 4)
        }
        .babyLogCard()
    }

    private var deleteButton: some View {
        Button("Delete Diaper", role: .destructive) {
            showsDeleteConfirmation = true
        }
        .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func selectorHeading(_ title: LocalizedStringKey, trailing: String? = nil) -> some View {
        HStack {
            Text(title).font(AppFont.secondary)
            Spacer()
            if let trailing {
                Text(trailing).font(AppFont.secondary)
            }
        }
        .foregroundStyle(BabyLogTheme.mutedText)
    }

    private func selectionButton(
        _ title: String,
        isSelected: Bool,
        fontSize: CGFloat = 13,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.avenirNext(fontSize, weight: isSelected ? .bold : .demiBold))
                .foregroundStyle(isSelected ? Color.white : BabyLogTheme.mutedText)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(isSelected ? TrackingCategory.diaper.style.main : TrackingCategory.diaper.style.soft)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @MainActor
    private func save() async {
        guard let access else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            let event = try form.makeEvent(
                babyID: access.baby.id,
                userID: access.membership.userID
            )
            if form.isEditing {
                _ = try await environment.diaperRepository.update(event)
            } else {
                try await environment.diaperRepository.create(event)
            }
            sizeMemory.save(
                form.size,
                isEnabled: environment.preferences.values.rememberDiaperSize
            )
            dismiss()
        } catch {
            errorMessage = "Couldn’t save. Your entry is still here; try again when the connection is available."
        }
    }

    @MainActor
    private func deleteEvent() async {
        guard let event = existingEvent else { return }
        isSaving = true
        defer { isSaving = false }

        do {
            try await environment.diaperRepository.delete(
                id: event.id,
                babyID: event.babyID
            )
            dismiss()
        } catch {
            errorMessage = "Couldn’t delete the diaper. Try again."
        }
    }
}
