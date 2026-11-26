//
//  AppTab.swift
//  BabyLog
//

import Foundation

/// Centralized tab definitions. See BabyLog_Design_Requirements_Fresh.md section 9.
enum AppTab: String, CaseIterable, Identifiable {
    case home
    case timeline
    case calendar
    case analytics
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .timeline: return "Timeline"
        case .calendar: return "Calendar"
        case .analytics: return "Analytics"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .timeline: return "list.bullet"
        case .calendar: return "calendar"
        case .analytics: return "chart.bar"
        case .settings: return "slider.horizontal.3"
        }
    }
}
