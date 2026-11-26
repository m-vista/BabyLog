//
//  MainTabView.swift
//  BabyLog
//

import SwiftUI

/// Custom five-tab shell (design section 9; custom bar because iOS 26+
/// TabView renders Liquid Glass — see CustomTabBar).
struct MainTabView: View {
    @State private var access: BabyAccess
    @State private var selectedTab: AppTab = .home

    init(access: BabyAccess) { _access = State(initialValue: access) }

    var body: some View {
        ZStack {
            ForEach(AppTab.allCases) { tab in
                tabContent(for: tab, isActive: tab == selectedTab)
                    .opacity(tab == selectedTab ? 1 : 0)
                    .allowsHitTesting(tab == selectedTab)
                    .accessibilityHidden(tab != selectedTab)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            CustomTabBar(selectedTab: $selectedTab)
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppTab, isActive: Bool) -> some View {
        switch tab {
        case .home:
            HomeView(
                access: access,
                isActive: isActive,
                onOpenSettings: { selectedTab = .settings },
                onAccessUpdated: { access = $0 }
            )
        case .timeline: TimelineView(access: access, isActive: isActive)
        case .calendar: CalendarView(access: access, isActive: isActive)
        case .analytics: AnalyticsView(access: access, isActive: isActive)
        case .settings: SettingsView(access: access) { access = $0 }
        }
    }
}

#Preview {
    MainTabView(access: BabyAccess(
        baby: Baby(id: "preview", name: "Baby", birthDate: .now, createdByUserID: "user", createdAt: .now, updatedAt: .now),
        membership: BabyMembership(id: "user", babyID: "preview", userID: "user", role: .owner, status: .active, createdAt: .now, updatedAt: .now)
    ))
}
