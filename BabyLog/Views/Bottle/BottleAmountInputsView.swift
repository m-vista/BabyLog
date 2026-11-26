import SwiftUI

struct BottleAmountInputsView: View {
    @Bindable var form: BottleFormModel
    @FocusState private var focusedField: AmountField?

    private let columns = [
        GridItem(.flexible(), spacing: BabyLogTheme.cardSpacing),
        GridItem(.flexible(), spacing: BabyLogTheme.cardSpacing),
        GridItem(.flexible(), spacing: BabyLogTheme.cardSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: BabyLogTheme.cardSpacing) {
            LazyVGrid(columns: columns, spacing: BabyLogTheme.cardSpacing) {
                amountCard(title: "Breast milk", field: .left)
                amountCard(title: "Formula", field: .right)
                amountCard(title: "Total", field: .total)
            }

            Text("Entering any two auto calculates the third. A total on its own is logged as unspecified.")
                .font(AppFont.secondary)
                .foregroundStyle(BabyLogTheme.mutedText)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    private func amountCard(
        title: String,
        field: AmountField
    ) -> some View {
        let isCalculated = form.calculatedField == field
        let currentText = binding(for: field).wrappedValue

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(BabyLogTheme.mutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 2)
                if isCalculated {
                    Text("AUTO")
                        .font(AppFont.eyebrow)
                        .foregroundStyle(BabyLogTheme.mutedText)
                } else if !currentText.isEmpty {
                    Button {
                        form.updateAmount(field, text: "")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(BabyLogTheme.mutedText)
                    }
                    .accessibilityLabel("Clear \(title)")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("0", text: binding(for: field))
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: field)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(isCalculated ? BabyLogTheme.mutedText : BabyLogTheme.ink)
                    .accessibilityLabel(title)
                Text(form.volumeUnit.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
        }
        .padding(10)
        .background(isCalculated ? BabyLogTheme.divider.opacity(0.45) : BabyLogTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall)
                .stroke(
                    focusedField == field ? TrackingCategory.feed.style.main : BabyLogTheme.divider,
                    lineWidth: focusedField == field ? 2 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall))
    }

    private func binding(for field: AmountField) -> Binding<String> {
        Binding(
            get: {
                switch field {
                case .left: form.breastMilkInput
                case .right: form.formulaInput
                case .total: form.totalInput
                }
            },
            set: { form.updateAmount(field, text: $0) }
        )
    }
}
