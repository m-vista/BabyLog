//
//  BabyLogTheme.swift
//  BabyLog
//

import SwiftUI
import UIKit

/// Centralized neutral colors, radii, spacing, and shadow reference.
/// See BabyLog_Design_Requirements_Fresh.md sections 5 and 8.
enum BabyLogTheme {
    // MARK: Neutral colors

    static let brown900 = Color(light: 0x382820, dark: 0xF2E6DF)
    static let brown800 = Color(light: 0x4A342A, dark: 0xE4D1C7)
    static let brown700 = Color(light: 0x68483A, dark: 0xD1B5A6)
    static let brown500 = Color(light: 0x9A7562, dark: 0xB89583)
    static let brown100 = Color(light: 0xFBF8F5, dark: 0x302A27)
    static let cream = Color(light: 0xFEFDFC, dark: 0x171514)
    static let surface = Color(light: 0xFFFFFF, dark: 0x24211F)
    static let ink = Color(light: 0x2C2522, dark: 0xF7F2EF)
    // Dark enough for WCAG AA normal text on both cream and white surfaces.
    static let muted = Color(light: 0x776F6A, dark: 0xBDB3AE)
    static let mutedText = Color(light: 0x776F6A, dark: 0xBDB3AE)
    static let divider = Color(light: 0xEBE5E1, dark: 0x403A37)
    static let heroStart = Color(hex: 0x5A4034)

    /// Hero Start → Brown 900, used for the Home header (section 13).
    static let heroGradient = LinearGradient(
        colors: [heroStart, brown900],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Radii

    static let radiusLarge: CGFloat = 6
    static let radiusSmall: CGFloat = 5
    static let radiusTiny: CGFloat = 4
    static let radiusChip: CGFloat = 3

    // MARK: Spacing

    static let horizontalPadding: CGFloat = 16
    static let headingPadding: CGFloat = 20
    static let cardSpacing: CGFloat = 8

    // MARK: Shadow

    static let shadowColor = Color(hex: 0x382820).opacity(0.05)
    static let shadowColorMedium = Color(hex: 0x382820).opacity(0.08)
    static let shadowColorStrong = Color(hex: 0x382820).opacity(0.1)
    static let shadowColorStrongest = Color(hex: 0x382820).opacity(0.2)
    static let shadowRadius: CGFloat = 10
    static let shadowOffset = CGSize(width: 0, height: 2)

    // MARK: Timeline (design sections 35–45; docs/prototypes/Timeline*.dc.html)

    static let timelineHeaderButtonSize: CGFloat = 40
    static let timelineFilterBarSegmentHeight: CGFloat = 38
    static let timelineDateTileWidth: CGFloat = 46
    static let timelineRowIconTileSize: CGFloat = 36
    static let timelineSummaryIconSize: CGFloat = 15
    static let timelineChevron = Color(hex: 0xC9C0BA)

    // MARK: Tab bar

    /// Custom tab bar constants, matching docs/prototypes/Main.dc.html's
    /// <nav> exactly. See design section 9 and CustomTabBar.
    static let tabBarBackground = Color(light: 0xFFFFFF, dark: 0x211E1C).opacity(0.96)
    static let tabBarActive = brown800
    static let tabBarInactive = muted
    static let tabBarTopPadding: CGFloat = 7
    static let tabBarItemHeight: CGFloat = 44
    static let tabBarIconSize: CGFloat = 24
    static let tabBarIconLabelSpacing: CGFloat = 3
    static let tabBarDividerHeight: CGFloat = 1
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
