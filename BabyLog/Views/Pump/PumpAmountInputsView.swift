import SwiftUI

struct PumpAmountInputsView: View {
    @Bindable var form: PumpFormModel
    @FocusState.Binding var focusedField: AmountField?
    let rateElapsedSeconds: TimeInterval?
    let showsRates: Bool

    private let columns = [
        GridItem(.flexible(), spacing: BabyLogTheme.cardSpacing),
        GridItem(.flexible(), spacing: BabyLogTheme.cardSpacing),
        GridItem(.flexible(), spacing: BabyLogTheme.cardSpacing)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            LazyVGrid(columns: columns, spacing: BabyLogTheme.cardSpacing) {
                amountCard(title: "Left", field: .left, text: form.leftInput)
                amountCard(title: "Right", field: .right, text: form.rightInput)
                amountCard(title: "Total", field: .total, text: form.totalInput)
            }

            Text("Entering any two auto calculates the third.")
                .font(AppFont.secondary)
                .foregroundStyle(BabyLogTheme.mutedText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
    }

    private func amountCard(title: LocalizedStringKey, field: AmountField, text: String) -> some View {
        let isCalculated = form.calculatedField == field

        return VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(AppFont.avenirNext(12, weight: .medium))
                    .foregroundStyle(BabyLogTheme.mutedText)
                if let rate = rateText(for: field, input: text) {
                    Text(rate)
                        .font(AppFont.tag)
                        .foregroundStyle(TrackingCategory.pump.style.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer(minLength: 2)
                if isCalculated {
                    Text("AUTO")
                        .font(AppFont.eyebrow)
                        .foregroundStyle(BabyLogTheme.mutedText)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("0", text: binding(for: field))
                    .keyboardType(.decimalPad)
                    .disabled(isCalculated)
                    .focused($focusedField, equals: field)
                    .font(AppFont.avenirNext(22, weight: .bold))
                    .foregroundStyle(isCalculated ? BabyLogTheme.mutedText : BabyLogTheme.ink)
                    .accessibilityLabel(title)
                    .accessibilityValue(text.isEmpty ? "Not entered" : "\(text) \(form.volumeUnit.rawValue)")
                Text(form.volumeUnit.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
        }
        .padding(8)
        .background(isCalculated ? BabyLogTheme.divider.opacity(0.45) : BabyLogTheme.surface)
        .overlay {
            RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall)
                .stroke(
                    focusedField == field ? TrackingCategory.pump.style.main : BabyLogTheme.divider,
                    lineWidth: focusedField == field ? 2 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall))
    }

    private func binding(for field: AmountField) -> Binding<String> {
        Binding(
            get: {
                switch field {
                case .left: form.leftInput
                case .right: form.rightInput
                case .total: form.totalInput
                }
            },
            set: { form.updateAmount(field, text: $0) }
        )
    }

    private func rateText(for field: AmountField, input: String) -> String? {
        guard showsRates,
              !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        guard let amounts = try? form.resolvedAmounts() else { return nil }

        let milliliters: Double? = switch field {
        case .left: amounts.leftAmountMl
        case .right: amounts.rightAmountMl
        case .total: amounts.totalAmountMl
        }
        guard let milliliters else { return nil }
        guard let rateElapsedSeconds,
              let rate = PumpRateService.millilitersPerHour(
                amountMl: milliliters,
                elapsedSeconds: rateElapsedSeconds
              )
        else { return "– \(form.volumeUnit.rawValue)/hr" }
        return "\(VolumeService.displayString(milliliters: rate, unit: form.volumeUnit))/hr"
    }
}
