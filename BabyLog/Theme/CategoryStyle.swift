//
//  CategoryStyle.swift
//  BabyLog
//

import SwiftUI

/// The five tracking categories and their color roles.
/// Bottle and Nursing both use `.feed`. See BabyLog_Design_Requirements_Fresh.md section 6.
enum TrackingCategory: String, CaseIterable, Identifiable, Hashable, Sendable {
    case feed
    case sleep
    case diaper
    case pump
    case other

    var id: String { rawValue }

    var style: CategoryStyle {
        switch self {
        case .feed: return CategoryStyle(main: Color(hex: 0xD28A58), soft: Color(light: 0xFAEDE3, dark: 0x422D22), text: Color(light: 0xA35E2C, dark: 0xF1B184))
        case .sleep: return CategoryStyle(main: Color(hex: 0x6877A6), soft: Color(light: 0xE9EBF4, dark: 0x292D42), text: Color(light: 0x515F92, dark: 0xAFBCE8))
        case .diaper: return CategoryStyle(main: Color(hex: 0x6F9B8B), soft: Color(light: 0xE8F1ED, dark: 0x253831), text: Color(light: 0x4C7A69, dark: 0xA7D4C4))
        case .pump: return CategoryStyle(main: Color(hex: 0xAD6E7C), soft: Color(light: 0xF5E8EB, dark: 0x402A31), text: Color(light: 0x94566A, dark: 0xE6A8B7))
        case .other: return CategoryStyle(main: Color(hex: 0x9A7562), soft: Color(light: 0xF3EBE6, dark: 0x392F2A), text: Color(light: 0x68483A, dark: 0xDABDAC))
        }
    }
}

/// Main/Soft/Text color triple for a tracking category.
struct CategoryStyle {
    let main: Color
    let soft: Color
    let text: Color
}
