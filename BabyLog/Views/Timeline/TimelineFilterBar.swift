import SwiftUI

/// One segmented white filter bar (design section 36 and 48): All, Feed,
/// Diaper, Sleep, Pump, Other. All = Brown 100; each category = its own
/// soft fill; Other uses checklist-style icon in Brown 500.
struct TimelineFilterBar: View {
    @Binding var selection: TimelineFilter

    var body: some View {
        HStack(spacing: 2) {
            allSegment
            ForEach(TrackingCategory.allCases) { category in
                categorySegment(category)
            }
            multiSegment
        }
        .padding(3)
        .background(BabyLogTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall))
        .shadow(color: BabyLogTheme.shadowColorMedium, radius: 6, y: 1)
        .padding(.horizontal, BabyLogTheme.horizontalPadding)
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filter by category")
    }

    private var allSegment: some View {
        Button {
            selection = .all
        } label: {
            Text("All")
                .font(AppFont.avenirNext(12, weight: .bold))
                .foregroundStyle(BabyLogTheme.brown800)
            .frame(maxWidth: .infinity)
            .frame(height: BabyLogTheme.timelineFilterBarSegmentHeight)
            .background(selection == .all ? BabyLogTheme.brown100 : .clear)
            .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusTiny))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("All")
        .accessibilityAddTraits(selection == .all ? .isSelected : [])
    }

    private func categorySegment(_ category: TrackingCategory) -> some View {
        let isSelected = selection != .all && selection.selectedCategories.contains(category)
        return Button {
            selection.select(category)
        } label: {
            categoryIcon(category)
                .frame(maxWidth: .infinity)
                .frame(height: BabyLogTheme.timelineFilterBarSegmentHeight)
                .background(isSelected ? category.style.soft : .clear)
                .overlay {
                    if isSelected && selection.isMulti {
                        RoundedRectangle(cornerRadius: BabyLogTheme.radiusTiny)
                            .stroke(category.style.main, lineWidth: 1.5)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusTiny))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(categoryLabel(category))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var multiSegment: some View {
        Button {
            selection = selection.isMulti ? .all : .multi([])
        } label: {
            Image(systemName: "square.3.layers.3d")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(selection.isMulti ? .white : BabyLogTheme.brown800)
                .frame(maxWidth: .infinity)
                .frame(height: BabyLogTheme.timelineFilterBarSegmentHeight)
                .background(selection.isMulti ? BabyLogTheme.brown800 : .clear)
                .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusTiny))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select multiple categories")
        .accessibilityAddTraits(selection.isMulti ? .isSelected : [])
    }

    @ViewBuilder private func categoryIcon(_ category: TrackingCategory) -> some View {
        switch category {
        case .feed: ActivityIconView(icon: .bottle, color: category.style.main).frame(width: 22, height: 22)
        case .diaper: ActivityIconView(icon: .diaper, color: category.style.main).frame(width: 22, height: 22)
        case .sleep: ActivityIconView(icon: .sleep, color: category.style.main).frame(width: 22, height: 22)
        case .pump: ActivityIconView(icon: .pump, color: category.style.main).frame(width: 22, height: 22)
        case .other: Image(systemName: "checklist").font(.system(size: 19, weight: .medium)).foregroundStyle(category.style.main)
        }
    }

    private func categoryLabel(_ category: TrackingCategory) -> String {
        switch category {
        case .feed: "Feed"
        case .diaper: "Diaper"
        case .sleep: "Sleep"
        case .pump: "Pump"
        case .other: "Other: daily checklist and growth"
        }
    }
}

#Preview {
    @Previewable @State var selection: TimelineFilter = .all
    VStack {
        TimelineFilterBar(selection: $selection)
    }
    .padding(.top, 40)
    .background(BabyLogTheme.cream)
}
