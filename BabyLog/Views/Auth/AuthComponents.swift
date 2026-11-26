//
//  AuthComponents.swift
//  BabyLog
//

import SwiftUI

/// Shared input styling for Views/Auth screens (design section 11).
struct AuthTextField: View {
    let title: String
    @Binding var text: String
    var isSecure: Bool = false
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .never

    var body: some View {
        Group {
            if isSecure {
                SecureField(title, text: $text)
            } else {
                TextField(title, text: $text)
            }
        }
        .textContentType(contentType)
        .keyboardType(keyboardType)
        .autocorrectionDisabled()
        .textInputAutocapitalization(autocapitalization)
        .font(AppFont.avenirNext(14))
        .foregroundStyle(BabyLogTheme.ink)
        .padding(12)
        .background(BabyLogTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall))
    }
}

/// Shared primary action button for Views/Auth screens.
struct AuthPrimaryButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView()
                        .tint(.white)
                }
            }
            .font(AppFont.avenirNext(14, weight: .demiBold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(BabyLogTheme.brown800)
            .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall))
        }
        .disabled(isLoading)
    }
}

/// Compact inline error text (Phase 2 "Validate": auth errors are compact).
struct AuthErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(AppFont.secondary)
                .foregroundStyle(BabyLogTheme.brown700)
                .multilineTextAlignment(.center)
        }
    }
}

/// Shared "BABYLOG" eyebrow + screen title header.
struct AuthHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 4) {
            Text("BABYLOG")
                .font(AppFont.eyebrow)
                .foregroundStyle(BabyLogTheme.brown500)
            Text(title)
                .font(AppFont.screenTitle)
                .foregroundStyle(BabyLogTheme.ink)
        }
    }
}
