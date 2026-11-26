import SwiftUI

enum HomeActivityCardPosition {
    case full
    case leadingPair
    case trailingPair
}

struct HomeActivityCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let icon: ActivityIcon?
    var systemImage: String? = nil
    let category: TrackingCategory
    let timeText: String
    let primaryText: String
    var italicizedWord: String? = nil
    let summaryText: String
    var eventDate: Date? = nil
    var eventID: String? = nil
    var now: Date = .now
    var showsRelativeTimeByDefault = true
    var position: HomeActivityCardPosition = .full
    let action: () -> Void
    @State private var toggledTimeStyle = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: action) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .frame(height: 18)
                        .accessibilityHidden(true)
                    primaryLabel
                        .font(AppFont.avenirNext(isPaired ? 14 : 15, weight: .bold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 19, alignment: .leading)
                        .padding(.top, 3)
                    Rectangle()
                        .fill(.white.opacity(0.5))
                        .frame(height: 1)
                        .padding(.top, 5)
                    Text(summaryText)
                        .font(AppFont.avenirNext(isPaired ? 11 : 12, weight: .demiBold))
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 16, alignment: .leading)
                        .padding(.top, 4)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: cardHeight)
                .background {
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(.white.opacity(0.055))
                            .frame(width: isPaired ? 120 : 150, height: isPaired ? 120 : 150)
                            .offset(x: isPaired ? 40 : 30, y: isPaired ? -44 : -60)
                    }
                    .overlay(alignment: .topTrailing) {
                        Group {
                            if let icon {
                                ActivityIconView(icon: icon, color: .white.opacity(0.12))
                            } else if let systemImage {
                                Image(systemName: systemImage)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.white.opacity(0.12))
                            }
                        }
                        .frame(width: 76, height: 76)
                        .padding(.top, 6)
                        .padding(.trailing, 6)
                        .accessibilityHidden(true)
                    }
                    .allowsHitTesting(false)
                }
                .clipShape(cardShape)
                .contentShape(cardShape)
                .shadow(color: category.style.main.opacity(0.24), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)

            timeControl
                .padding(.leading, horizontalPadding)
                .padding(.top, 10)
        }
        .frame(height: cardHeight)
        .onChange(of: eventID) { _, _ in toggledTimeStyle = false }
        .onChange(of: showsRelativeTimeByDefault) { _, _ in toggledTimeStyle = false }
    }

    private var primaryLabel: some View {
        var value = AttributedString(primaryText)
        if let italicizedWord, let range = value.range(of: italicizedWord) {
            value[range].inlinePresentationIntent = .emphasized
        }
        return Text(value)
    }

    @ViewBuilder
    private var timeControl: some View {
        if eventDate != nil {
            Button {
                toggledTimeStyle.toggle()
            } label: {
                timeLabel
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Event time, \(displayedTime)")
            .accessibilityHint("Toggles relative and clock time")
        } else {
            timeLabel
        }
    }

    private var timeLabel: some View {
        Text(displayedTime)
            .font(AppFont.avenirNext(15, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? nil : 18, alignment: .leading)
            .contentShape(Rectangle())
    }

    private var displayedTime: String {
        guard let eventDate else { return timeText }
        let showRelative = showsRelativeTimeByDefault != toggledTimeStyle
        return HomeSummaryService.eventTime(eventDate, showRelative: showRelative, now: now)
    }

    private var isPaired: Bool { position != .full }
    private var horizontalPadding: CGFloat { isPaired ? 14 : 16 }
    private var cardHeight: CGFloat { dynamicTypeSize.isAccessibilitySize ? 140 : 88 }
    private var cardShape: UnevenRoundedRectangle { UnevenRoundedRectangle(cornerRadii: cornerRadii) }

    private var cornerRadii: RectangleCornerRadii {
        switch position {
        case .full:
            RectangleCornerRadii(
                topLeading: BabyLogTheme.radiusLarge,
                bottomLeading: BabyLogTheme.radiusLarge,
                bottomTrailing: BabyLogTheme.radiusLarge,
                topTrailing: BabyLogTheme.radiusLarge
            )
        case .leadingPair:
            RectangleCornerRadii(topLeading: 6, bottomLeading: 6, bottomTrailing: 3, topTrailing: 3)
        case .trailingPair:
            RectangleCornerRadii(topLeading: 3, bottomLeading: 3, bottomTrailing: 6, topTrailing: 6)
        }
    }

    private var gradientColors: [Color] {
        switch category {
        case .feed:
            position == .leadingPair
                ? [Color(hex: 0xCF8A4E), Color(hex: 0xAE6A2E)]
                : [Color(hex: 0xC9834A), Color(hex: 0xA6632A)]
        case .sleep: [Color(hex: 0x8B87C6), Color(hex: 0x6A67A6)]
        case .diaper: [Color(hex: 0x7EB29B), Color(hex: 0x5A9179)]
        case .pump: [Color(hex: 0xC98C98), Color(hex: 0xA6677A)]
        case .other: [BabyLogTheme.brown500, BabyLogTheme.brown700]
        }
    }
}
