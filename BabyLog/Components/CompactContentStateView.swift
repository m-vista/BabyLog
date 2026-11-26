import SwiftUI

struct CompactContentStateView: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(BabyLogTheme.brown500)
                .accessibilityHidden(true)
            Text(title)
                .font(AppFont.loggingRow)
                .foregroundStyle(BabyLogTheme.ink)
            Text(message)
                .font(AppFont.secondary)
                .foregroundStyle(BabyLogTheme.mutedText)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Retry", action: retry)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BabyLogTheme.brown700)
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(BabyLogTheme.horizontalPadding)
    }
}
