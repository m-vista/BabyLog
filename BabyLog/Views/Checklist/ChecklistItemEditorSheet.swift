import SwiftUI

struct ChecklistItemEditorSheet: View {
    let existingItem: ChecklistItem?
    let babyID: String
    let userID: String
    let sortOrder: Int
    let onSave: (ChecklistItem) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var form: ChecklistItemFormModel
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(item: ChecklistItem? = nil, babyID: String, userID: String, sortOrder: Int, onSave: @escaping (ChecklistItem) async throws -> Void) {
        existingItem = item
        self.babyID = babyID
        self.userID = userID
        self.sortOrder = sortOrder
        self.onSave = onSave
        _form = State(initialValue: ChecklistItemFormModel(item: item))
    }

    var body: some View {
        @Bindable var form = form
        NavigationStack {
            VStack(alignment: .leading, spacing: BabyLogTheme.headingPadding) {
                TextField("One-word title", text: $form.title)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(BabyLogTheme.surface)
                    .overlay { RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall).stroke(BabyLogTheme.divider) }
                Text("Choose icon").font(AppFont.primaryRow)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    ForEach(ChecklistSymbol.allCases, id: \.self) { symbol in
                        Button { form.symbol = symbol } label: {
                            Image(systemName: symbol.rawValue)
                                .font(.title3)
                                .frame(width: 48, height: 48)
                                .background(form.symbol == symbol ? TrackingCategory.other.style.main : BabyLogTheme.surface)
                                .foregroundStyle(form.symbol == symbol ? .white : TrackingCategory.other.style.main)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel(symbol.title)
                    }
                }
                if let errorMessage { Text(errorMessage).font(AppFont.secondary).foregroundStyle(.red) }
                Spacer()
            }
            .padding(BabyLogTheme.headingPadding)
            .background(BabyLogTheme.cream)
            .navigationTitle(existingItem == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(isSaving) }
            }
        }
        .babyLogSheetPresentation()
    }

    @MainActor private func save() async {
        isSaving = true; defer { isSaving = false }
        do {
            let item = try form.makeItem(babyID: babyID, userID: userID, sortOrder: sortOrder)
            try await onSave(item)
            dismiss()
        } catch ChecklistError.titleMustBeOneWord { errorMessage = "Use a one-word title." }
        catch { errorMessage = "Couldn’t save the item. Try again." }
    }
}
