//
//  PlaceholderScreen.swift
//  BabyLog
//

import SwiftUI

/// Shared styled placeholder shown for tabs that have not been built yet.
struct PlaceholderScreen: View {
    let tab: AppTab

    var body: some View {
        ZStack {
            BabyLogTheme.cream.ignoresSafeArea()

            VStack(spacing: BabyLogTheme.cardSpacing) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 32))
                    .foregroundStyle(BabyLogTheme.brown500)

                Text(tab.title)
                    .font(AppFont.screenTitle)
                    .foregroundStyle(BabyLogTheme.ink)

                Text("Coming soon")
                    .font(AppFont.secondary)
                    .foregroundStyle(BabyLogTheme.mutedText)
            }
        }
    }
}

#Preview {
    PlaceholderScreen(tab: .home)
}
