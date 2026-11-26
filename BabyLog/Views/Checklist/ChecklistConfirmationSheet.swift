import SwiftUI

struct ChecklistConfirmationSheet: View {
    let item: ChecklistItem
    let userID: String
    let existingEvent: ChecklistEvent?
    let onSaved: (ChecklistEvent) async throws -> Void
    let onDelete: ((ChecklistEvent) async throws -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var form: ChecklistEventFormModel
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var confirmsDelete = false

    init(item: ChecklistItem, userID: String, event: ChecklistEvent? = nil, onSaved: @escaping (ChecklistEvent) async throws -> Void, onDelete: ((ChecklistEvent) async throws -> Void)? = nil) {
        self.item = item
        self.userID = userID
        existingEvent = event
        self.onSaved = onSaved
        self.onDelete = onDelete
        _form = State(initialValue: ChecklistEventFormModel(event: event))
    }

    var body: some View {
        @Bindable var form = form
        NavigationStack {
            ScrollView {
                VStack(spacing: BabyLogTheme.headingPadding) {
                Image(systemName: item.symbol)
                    .font(.title)
                    .foregroundStyle(TrackingCategory.other.style.main)
                    .frame(width: 56, height: 56)
                    .background(TrackingCategory.other.style.soft)
                    .clipShape(Circle())
                    .accessibilityHidden(true)
                Text(item.title).font(AppFont.screenTitle)
                EditableDateTimeCard(
                    title: "Time",
                    date: Binding(get: { form.timestamp }, set: form.setTimestamp),
                    category: .other
                )
                TextField("Optional note", text: $form.notes, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(BabyLogTheme.surface)
                    .overlay { RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall).stroke(BabyLogTheme.divider) }
                if let errorMessage { Text(errorMessage).font(AppFont.secondary).foregroundStyle(.red) }
                if existingEvent != nil {
                    Button("Undo completion", role: .destructive) { confirmsDelete = true }
                        .frame(minHeight: 44)
                }
                }
                .padding(BabyLogTheme.headingPadding)
                .frame(maxWidth: .infinity)
            }
            .background(BabyLogTheme.cream)
            .navigationTitle(existingEvent == nil ? "Log Checklist" : "Edit Completion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(isSaving) }
            }
        }
        .background(BabyLogTheme.cream.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationBackground(BabyLogTheme.cream)
        .presentationCornerRadius(0)
        .interactiveDismissDisabled(isSaving)
        .alert("Undo completion?", isPresented: $confirmsDelete) {
            Button("Undo", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This removes the completion for every caregiver.") }
    }

    @MainActor private func save() async {
        isSaving = true; defer { isSaving = false }
        do {
            let event = try form.makeEvent(item: item, userID: userID)
            try await onSaved(event)
            dismiss()
        } catch { errorMessage = "Couldn’t save. Your entry is still here; try again." }
    }

    @MainActor private func delete() async {
        guard let existingEvent, let onDelete else { return }
        isSaving = true; defer { isSaving = false }
        do { try await onDelete(existingEvent); dismiss() }
        catch { errorMessage = "Couldn’t undo the completion. Try again." }
    }
}
