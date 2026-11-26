import SwiftUI

extension View {
    func babyLogSheetPresentation() -> some View {
        self
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(0)
            .presentationBackground(BabyLogTheme.cream)
            .background(BabyLogTheme.cream.ignoresSafeArea())
            .foregroundStyle(BabyLogTheme.ink)
    }

    func babyLogCard(padding: CGFloat = 14) -> some View {
        self
            .padding(padding)
            .background(BabyLogTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall))
            .shadow(color: BabyLogTheme.shadowColor, radius: BabyLogTheme.shadowRadius, y: BabyLogTheme.shadowOffset.height)
    }
}
