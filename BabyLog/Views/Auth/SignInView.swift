//
//  SignInView.swift
//  BabyLog
//

import SwiftUI

/// Entry point for the "not authenticated" route (design section 11).
struct SignInView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCreateAccount = false
    @State private var showingPasswordReset = false

    var body: some View {
        VStack(spacing: 20) {
            AuthHeader(title: "Sign In")
                .padding(.top, 40)

            VStack(spacing: 12) {
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
                    contentType: .password
                )
            }

            AuthErrorText(message: errorMessage)

            AuthPrimaryButton(title: "Sign In", isLoading: isLoading, action: signIn)

            Button("Forgot password?") {
                showingPasswordReset = true
            }
            .font(AppFont.secondary)
            .foregroundStyle(BabyLogTheme.brown700)

            Spacer()

            Button {
                showingCreateAccount = true
            } label: {
                (Text("Don't have an account? ")
                    .foregroundStyle(BabyLogTheme.mutedText)
                    + Text("Create one")
                    .foregroundStyle(BabyLogTheme.brown700))
                    .font(AppFont.secondary)
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal, BabyLogTheme.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(BabyLogTheme.cream.ignoresSafeArea())
        .sheet(isPresented: $showingCreateAccount) {
            CreateAccountView()
        }
        .sheet(isPresented: $showingPasswordReset) {
            PasswordResetView(email: email)
        }
    }

    private func signIn() {
        errorMessage = nil
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await environment.authService.signIn(email: email, password: password)
            } catch {
                errorMessage = AuthErrorPresenter.message(for: error)
            }
        }
    }
}

#Preview {
    SignInView()
        .environment(AppEnvironment())
}
