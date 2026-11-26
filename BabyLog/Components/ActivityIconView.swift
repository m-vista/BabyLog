import SwiftUI

enum ActivityIcon: String, Sendable {
    case bottle = "IconBottle"
    case nursing = "IconNursing"
    case sleep = "IconSleep"
    case diaper = "IconDiaper"
    case pump = "IconPump"
}

struct ActivityIconView: View {
    let icon: ActivityIcon
    let color: Color

    var body: some View {
        Image(icon.rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .foregroundStyle(color)
            .accessibilityHidden(true)
    }
}
