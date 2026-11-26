//
//  CreateAccountView.swift
//  BabyLog
//

import SwiftUI

/// Create Account sheet, presented from SignInView (design section 11).
struct CreateAccountView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                AuthHeader(title: "Create Account")
                    .padding(.top, 24)

                VStack(spacing: 12) {
                    AuthTextField(
                        title: "Name",
                        text: $displayName,
                        contentType: .name,
                        autocapitalization: .words
                    )
                    AuthTextField(
                        title: "Email",
                        text: $email,
                        contentType: .username,
                        keyboardType: .emailAddress
                    )
                    AuthTextField(
                        title: "Password",
                        text: $password,
                        isSecure: true,
                        contentType: .newPassword
                    )
                }

                AuthErrorText(message: errorMessage)

                AuthPrimaryButton(title: "Create Account", isLoading: isLoading, action: createAccount)

                Spacer()
            }
            .padding(.horizontal, BabyLogTheme.horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BabyLogTheme.cream.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func createAccount() {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await environment.authService.createAccount(
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: email,
                    password: password
                )
                dismiss()
            } catch {
                errorMessage = AuthErrorPresenter.message(for: error)
            }
        }
    }
}

#Preview {
    CreateAccountView()
        .environment(AppEnvironment())
}
