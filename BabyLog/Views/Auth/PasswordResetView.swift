//
//  PasswordResetView.swift
//  BabyLog
//

import SwiftUI

/// Optional password reset sheet, presented from SignInView (design section 11).
struct PasswordResetView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var email: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var didSend = false

    init(email: String) {
        _email = State(initialValue: email)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                AuthHeader(title: "Reset Password")
                    .padding(.top, 24)

                if didSend {
                    Text("Check \(email) for a reset link.")
                        .font(AppFont.secondary)
                        .foregroundStyle(BabyLogTheme.mutedText)
                        .multilineTextAlignment(.center)
                } else {
                    AuthTextField(
                        title: "Email",
                        text: $email,
                        contentType: .username,
                        keyboardType: .emailAddress
                    )
                    AuthErrorText(message: errorMessage)
                    AuthPrimaryButton(title: "Send Reset Link", isLoading: isLoading, action: sendReset)
                }

                Spacer()
            }
            .padding(.horizontal, BabyLogTheme.horizontalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BabyLogTheme.cream.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sendReset() {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await environment.authService.sendPasswordReset(email: email)
                didSend = true
            } catch {
                errorMessage = AuthErrorPresenter.message(for: error)
            }
        }
    }
}

#Preview {
    PasswordResetView(email: "")
        .environment(AppEnvironment())
}
