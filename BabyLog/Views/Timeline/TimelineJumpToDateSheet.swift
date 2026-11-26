import SwiftUI

/// Compact jump-to-date picker (design section 35). Loading the target
/// interval and positioning the scroll happen in the caller — this sheet
/// only picks a date.
struct TimelineJumpToDateSheet: View {
    let initialDate: Date
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Date

    init(initialDate: Date, onSelect: @escaping (Date) -> Void) {
        self.initialDate = initialDate
        self.onSelect = onSelect
        _selected = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            DatePicker(
                "Date",
                selection: $selected,
                in: ...Date.now,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .padding(BabyLogTheme.horizontalPadding)
            .background(BabyLogTheme.cream)
            .navigationTitle("Jump to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go") {
                        onSelect(selected)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(BabyLogTheme.cream)
    }
}
