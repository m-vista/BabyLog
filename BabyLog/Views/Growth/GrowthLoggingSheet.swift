import SwiftUI
import FirebaseFirestore

struct GrowthLoggingSheet: View {
    let access: BabyAccess?
    let existingMeasurement: GrowthMeasurement?

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var form: GrowthFormModel
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var showsDeleteConfirmation = false
    @State private var didLoadUnits = false
    @FocusState private var isMeasurementFieldFocused: Bool

    init(access: BabyAccess?, existingMeasurement: GrowthMeasurement? = nil) {
        self.access = access
        self.existingMeasurement = existingMeasurement
        _form = State(initialValue: GrowthFormModel(measurement: existingMeasurement))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date and time", selection: $form.timestamp, in: ...Date.now)
                }
                Section("MEASUREMENTS") {
                    if unitSystem == .metric {
                        measurementField("Weight", unit: "kg", text: $form.weightText)
                    } else {
                        LabeledContent("Weight") {
                            HStack(spacing: 5) {
                                TextField("0", text: $form.weightText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .focused($isMeasurementFieldFocused)
                                Text("lb").foregroundStyle(BabyLogTheme.mutedText)
                                TextField("0", text: $form.weightOuncesText).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                    .focused($isMeasurementFieldFocused)
                                Text("oz").foregroundStyle(BabyLogTheme.mutedText)
                            }
                            .frame(maxWidth: 210)
                        }
                    }
                    percentileText(metric: .weight, value: canonicalWeight)
                    measurementField("Height / length", unit: unitSystem == .metric ? "cm" : "in", text: $form.heightText)
                    percentileText(metric: .height, value: canonicalLength(form.parsedHeight))
                    measurementField("Head circumference", unit: unitSystem == .metric ? "cm" : "in", text: $form.headCircumferenceText)
                    percentileText(metric: .headCircumference, value: canonicalLength(form.parsedHeadCircumference))
                    Text("Enter at least one measurement.")
                        .font(.caption)
                        .foregroundStyle(BabyLogTheme.mutedText)
                }
                Section("NOTES") {
                    TextField("Optional notes", text: $form.notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                }
                if existingMeasurement != nil {
                    Section {
                        Button("Delete entry", role: .destructive) {
                            showsDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(existingMeasurement == nil ? "Log Growth" : "Edit Growth")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!form.canSave || isSaving)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isMeasurementFieldFocused = false }
                }
            }
            .confirmationDialog("Delete this growth entry?", isPresented: $showsDeleteConfirmation) {
                Button("Delete", role: .destructive) { Task { await delete() } }
            }
        }
        .task {
            guard !didLoadUnits else { return }
            form = GrowthFormModel(measurement: existingMeasurement, unitSystem: unitSystem)
            didLoadUnits = true
        }
    }

    private func measurementField(_ title: LocalizedStringKey, unit: String, text: Binding<String>) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField("Optional", text: text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($isMeasurementFieldFocused)
                Text(unit).foregroundStyle(BabyLogTheme.mutedText)
            }
            .frame(maxWidth: 150)
        } label: {
            Text(title)
        }
    }

    @MainActor
    private func save() async {
        guard let access else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let value = try form.measurement(access: access, existing: existingMeasurement, unitSystem: unitSystem)
            if existingMeasurement == nil {
                try await environment.growthRepository.create(value)
            } else {
                _ = try await environment.growthRepository.update(value)
            }
            dismiss()
        } catch let error as NSError {
            errorMessage = error.domain == FirestoreErrorDomain
                ? "Growth couldn’t be saved. Deploy the latest Firestore rules, then try again."
                : "Enter at least one valid measurement."
        }
    }

    private var unitSystem: GrowthUnitSystem {
        environment.preferences.values.growthUnitSystem
    }

    @ViewBuilder
    private func percentileText(metric: GrowthMetric, value: Double?) -> some View {
        if let baby = access?.baby,
           let gender = baby.gender,
           let value,
           let percentile = GrowthPercentileService.percentile(
               metric: metric,
               value: value,
               ageMonths: GrowthPercentileService.ageInMonths(on: form.timestamp, baby: baby),
               gender: gender
           ) {
            Text("Approximately \(percentile.ordinal) percentile for age")
                .font(.caption)
                .foregroundStyle(BabyLogTheme.mutedText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var canonicalWeight: Double? {
        guard let poundsOrKilograms = form.parsedWeight else { return nil }
        guard unitSystem == .imperial else { return poundsOrKilograms }
        let pounds = poundsOrKilograms + (Double(form.weightOuncesText) ?? 0) / 16
        return pounds / 2.204_622_6218
    }

    private func canonicalLength(_ value: Double?) -> Double? {
        value.map { unitSystem == .metric ? $0 : $0 * 2.54 }
    }

    @MainActor
    private func delete() async {
        guard let existingMeasurement else { return }
        do {
            try await environment.growthRepository.delete(
                id: existingMeasurement.id,
                babyID: existingMeasurement.babyID
            )
            dismiss()
        } catch {
            errorMessage = "The entry couldn’t be deleted. Try again."
        }
    }
}
