//
//  CustomTabBar.swift
//  BabyLog
//

import SwiftUI

/// Flat, opaque bottom tab bar matching design section 9 and
/// docs/prototypes/Main.dc.html exactly — not the native `TabView`, which
/// renders as a floating Liquid Glass capsule on iOS 26+ and has no
/// supported way to force the spec's opaque edge-to-edge look. There is no
/// selection pill/underline; the prototype shows selection only through
/// color and weight.
struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                item(for: tab)
            }
        }
        .padding(.top, BabyLogTheme.tabBarTopPadding)
        .frame(maxWidth: .infinity)
        .background {
            BabyLogTheme.tabBarBackground.ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(BabyLogTheme.divider)
                .frame(height: BabyLogTheme.tabBarDividerHeight)
        }
        .accessibilityElement(children: .contain)
    }

    private func item(for tab: AppTab) -> some View {
        let isSelected = tab == selectedTab

        return Button {
            selectedTab = tab
        } label: {
            VStack(spacing: BabyLogTheme.tabBarIconLabelSpacing) {
                Image(systemName: tab.systemImage)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .frame(height: BabyLogTheme.tabBarIconSize)

                Text(tab.title)
                    .font(isSelected ? AppFont.tabLabelActive : AppFont.tabLabelInactive)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? BabyLogTheme.tabBarActive : BabyLogTheme.tabBarInactive)
            .frame(maxWidth: .infinity, minHeight: BabyLogTheme.tabBarItemHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(tab.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("tab.\(tab.rawValue)")
        .accessibilityShowsLargeContentViewer {
            Image(systemName: tab.systemImage)
            Text(tab.title)
        }
    }
}

#Preview {
    @Previewable @State var selectedTab: AppTab = .home

    ZStack(alignment: .bottom) {
        BabyLogTheme.cream.ignoresSafeArea()
        CustomTabBar(selectedTab: $selectedTab)
    }
}
