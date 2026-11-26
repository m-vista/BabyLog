import SwiftUI

struct BabySetupView: View {
    @Environment(AppEnvironment.self) private var environment
    let userID: String
    let onCreated: (BabyAccess) -> Void

    @State private var name = ""
    @State private var birthDate = Date()
    @State private var isCreating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                BabyLogTheme.cream.ignoresSafeArea()
                BabySetupForm(
                    name: $name,
                    birthDate: $birthDate,
                    isCreating: isCreating,
                    errorMessage: errorMessage,
                    create: createBaby
                )
            }
            .navigationTitle("Baby Setup")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") { try? environment.authService.signOut() }
                }
            }
        }
    }

    private func createBaby() {
        guard !isCreating else { return }
        isCreating = true
        errorMessage = nil
        Task {
            do {
                let access = try await environment.babyRepository.createFirstBaby(
                    name: name,
                    birthDate: birthDate,
                    userID: userID
                )
                onCreated(access)
            } catch {
                errorMessage = BabyErrorPresenter.message(for: error)
            }
            isCreating = false
        }
    }
}

private struct BabySetupForm: View {
    @Binding var name: String
    @Binding var birthDate: Date
    let isCreating: Bool
    let errorMessage: String?
    let create: () -> Void

    var body: some View {
        Form {
            Section("BABY") {
                TextField("Baby name", text: $name)
                    .textContentType(.name)
                    .submitLabel(.done)
                DatePicker("Birth date", selection: $birthDate, in: ...Date(), displayedComponents: .date)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(AppFont.secondary)
                    .foregroundStyle(.red)
            }

            Button(action: create) {
                if isCreating {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text("Create Baby").frame(maxWidth: .infinity)
                }
            }
            .disabled(isCreating)
        }
        .scrollContentBackground(.hidden)
    }
}
