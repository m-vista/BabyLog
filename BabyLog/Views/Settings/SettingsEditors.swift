import SwiftUI
import UIKit

struct BabySettingsEditor: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let access: BabyAccess
    let onSaved: (BabyAccess) -> Void
    @State private var name: String
    @State private var birthDate: Date
    @State private var gender: BabyGender
    @State private var usesCorrectedDate: Bool
    @State private var dueDate: Date
    @State private var nightStart: Date
    @State private var nightEnd: Date
    @State private var error: String?

    init(access: BabyAccess, onSaved: @escaping (BabyAccess) -> Void) {
        self.access = access; self.onSaved = onSaved
        _name = State(initialValue: access.baby.name)
        _birthDate = State(initialValue: access.baby.birthDate)
        _gender = State(initialValue: access.baby.gender ?? .preferNotToSay)
        _usesCorrectedDate = State(initialValue: access.baby.usesCorrectedDate ?? false)
        _dueDate = State(initialValue: access.baby.dueDate ?? access.baby.birthDate)
        _nightStart = State(initialValue: SettingsTime.date(access.baby.nightStartMinutes))
        _nightEnd = State(initialValue: SettingsTime.date(access.baby.nightEndMinutes))
    }

    var body: some View {
        Form {
            Section("BABY") {
                BabyPhotoPicker(babyID: access.baby.id)
                TextField("Name", text: $name)
                DatePicker("Birth date", selection: $birthDate, in: ...Date.now, displayedComponents: .date)
                Picker("Gender", selection: $gender) {
                    ForEach(BabyGender.allCases) { value in
                        Text(value.title).tag(value)
                    }
                }
                if gender == .preferNotToSay {
                    Text("Accurate WHO percentiles won’t be shown without a sex-specific growth standard.")
                        .font(.caption)
                        .foregroundStyle(BabyLogTheme.mutedText)
                }
            }
            Section("CORRECTED AGE") {
                Toggle("Use corrected date", isOn: $usesCorrectedDate)
                if usesCorrectedDate {
                    DatePicker("Due date", selection: $dueDate, displayedComponents: .date)
                    Text("Growth charts use the due date to calculate corrected age.")
                        .font(.caption)
                        .foregroundStyle(BabyLogTheme.mutedText)
                }
            }
            Section("NIGHT WINDOW") {
                DatePicker("Starts", selection: $nightStart, displayedComponents: .hourAndMinute)
                DatePicker("Ends", selection: $nightEnd, displayedComponents: .hourAndMinute)
                Text("Used to classify night sleep and naps throughout Timeline and Analytics.").font(.caption).foregroundStyle(BabyLogTheme.mutedText)
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Baby")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } } }
    }

    private func save() async {
        do {
            var baby = access.baby
            baby.name = name; baby.birthDate = birthDate
            baby.gender = gender
            baby.usesCorrectedDate = usesCorrectedDate
            baby.dueDate = usesCorrectedDate ? dueDate : nil
            baby.nightStartMinutes = SettingsTime.minutes(nightStart)
            baby.nightEndMinutes = SettingsTime.minutes(nightEnd)
            let updated = try await environment.babyRepository.update(baby)
            onSaved(BabyAccess(baby: updated, membership: access.membership)); dismiss()
        } catch { self.error = BabyErrorPresenter.message(for: error) }
    }
}

struct AccountSettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    let userID: String
    @State private var displayName = ""
    @State private var error: String?
    var body: some View {
        Form {
            Section("ACCOUNT") {
                TextField("Display name", text: $displayName)
                LabeledContent("Email", value: environment.authService.currentEmail)
                VStack(alignment: .leading, spacing: 4) {
                    Text("User ID"); Text(userID).font(.caption.monospaced()).foregroundStyle(BabyLogTheme.mutedText)
                    Button("Copy") { UIPasteboard.general.string = userID }
                }
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Account")
        .task { displayName = environment.authService.currentDisplayName }
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } } } }
    }
    private func save() async { do { try await environment.authService.updateDisplayName(displayName) } catch { self.error = "Couldn’t update your name." } }
}

struct AddCaregiverView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    let babyID: String
    @State private var userID = ""
    @State private var role: BabyMembership.Role = .admin
    @State private var error: String?
    var body: some View {
        Form {
            Section("CAREGIVER") {
                TextField("User ID", text: $userID).textInputAutocapitalization(.never).autocorrectionDisabled()
                Picker("Role", selection: $role) { Text("Admin").tag(BabyMembership.Role.admin); Text("Caregiver").tag(BabyMembership.Role.caregiver) }
            }
            Text("Admins can edit baby settings and manage caregivers. Caregivers can log and edit activities.").font(.caption).foregroundStyle(BabyLogTheme.mutedText)
            if let error { Text(error).foregroundStyle(.red) }
        }
        .navigationTitle("Add Caregiver")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Add") { Task { await add() } } } }
    }
    private func add() async { do { try await environment.babyRepository.addMember(userID: userID, role: role, to: babyID); dismiss() } catch { self.error = BabyErrorPresenter.message(for: error) } }
}
