//
//  Typography.swift
//  BabyLog
//

import SwiftUI

/// Avenir Next helpers. See BabyLog_Design_Requirements_Fresh.md section 4.
enum AppFont {
    enum Weight {
        case regular
        case medium
        case demiBold
        case bold

        var fontName: String {
            switch self {
            case .regular: return "AvenirNext-Regular"
            case .medium: return "AvenirNext-Medium"
            case .demiBold: return "AvenirNext-DemiBold"
            case .bold: return "AvenirNext-Bold"
            }
        }
    }

    /// Avenir Next at a larger base size, scaling with Dynamic Type relative to `.body`.
    static func avenirNext(_ size: CGFloat, weight: Weight = .regular) -> Font {
        .custom(weight.fontName, size: size * 1.075, relativeTo: .body)
    }

    // Reference sizes (design section 4).
    static let tag = avenirNext(11, weight: .medium)
    static let eyebrow = avenirNext(12, weight: .demiBold)
    static let secondary = avenirNext(14, weight: .regular)
    static let primaryRow = avenirNext(16, weight: .medium)
    static let loggingRow = avenirNext(17, weight: .medium)
    static let loggingValue = avenirNext(18, weight: .demiBold)
    static let homeRelativeTime = avenirNext(17, weight: .medium)
    static let screenTitle = avenirNext(21, weight: .demiBold)
    static let babyName = avenirNext(26, weight: .bold)
    static let analyticsFeatured = avenirNext(30, weight: .bold)

    // Tab bar labels: fixed size, not Dynamic-Type-scaled. The native tab
    // bar doesn't grow its labels either — it relies on the Large Content
    // Viewer instead (see CustomTabBar).
    static let tabLabelActive = Font.custom("AvenirNext-Bold", fixedSize: 11.5)
    static let tabLabelInactive = Font.custom("AvenirNext-DemiBold", fixedSize: 11.5)
}
