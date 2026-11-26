import SwiftUI

/// Matches docs/prototypes/Timeline.dc.html and TimelineSummaries.dc.html
/// headers: small relative label, full date below, back-to-today on the
/// left when away from today, expand/collapse on the right. No prev/next
/// arrows — tapping the date opens jump-to-date (design section 35).
struct TimelineHeaderView: View {
    let focusedDayStart: Date
    let todayStart: Date
    let displayMode: TimelineDisplayMode
    let onBackToToday: () -> Void
    let onToggleDisplayMode: () -> Void
    let onTapDate: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if focusedDayStart != todayStart {
                circleButton(systemImage: "chevron.left", background: BabyLogTheme.surface, foreground: BabyLogTheme.brown800, action: onBackToToday)
                    .accessibilityLabel("Back to today")
            }

            Button(action: onTapDate) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(TimelineHeaderFormatter.relativeDayLabel(for: focusedDayStart, today: todayStart))
                        .font(AppFont.avenirNext(11, weight: .demiBold))
                        .foregroundStyle(BabyLogTheme.mutedText)
                    Text(TimelineHeaderFormatter.fullDateText(for: focusedDayStart))
                        .font(AppFont.avenirNext(19, weight: .bold))
                        .foregroundStyle(BabyLogTheme.ink)
                        .tracking(-0.19)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHint("Opens jump to date")

            Button(action: onToggleDisplayMode) {
                TimelineExpandCollapseIcon(isCollapseIcon: displayMode == .fullList)
                    .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: 18, height: 18)
                    .frame(width: BabyLogTheme.timelineHeaderButtonSize, height: BabyLogTheme.timelineHeaderButtonSize)
                    .background(displayMode == .fullList ? BabyLogTheme.surface : BabyLogTheme.brown800)
                    .clipShape(Circle())
                    .shadow(color: displayMode == .fullList ? BabyLogTheme.shadowColorStrong : BabyLogTheme.shadowColorStrongest, radius: 4, y: 1)
            }
            .buttonStyle(.plain)
            .foregroundStyle(displayMode == .fullList ? BabyLogTheme.brown800 : .white)
            .accessibilityLabel(displayMode == .fullList ? "Show day summaries only" : "Show full list")
        }
        .padding(.leading, focusedDayStart != todayStart ? 12 : 20)
        .padding(.trailing, 16)
        .padding(.top, 54)
        .padding(.bottom, 10)
    }

    private func circleButton(systemImage: String, background: Color, foreground: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: BabyLogTheme.timelineHeaderButtonSize, height: BabyLogTheme.timelineHeaderButtonSize)
                .background(background)
                .clipShape(Circle())
                .shadow(color: BabyLogTheme.shadowColorStrong, radius: 4, y: 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
    }
}

/// Reproduces the prototype's exact double-chevron glyphs: arrows pointing
/// inward (collapse, to summaries-only) or outward (expand, to full list).
private struct TimelineExpandCollapseIcon: Shape {
    let isCollapseIcon: Bool

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: x / 24 * rect.width, y: y / 24 * rect.height)
        }
        var path = Path()
        if isCollapseIcon {
            path.move(to: point(7, 20)); path.addLine(to: point(12, 15)); path.addLine(to: point(17, 20))
            path.move(to: point(7, 4)); path.addLine(to: point(12, 9)); path.addLine(to: point(17, 4))
        } else {
            path.move(to: point(7, 15)); path.addLine(to: point(12, 20)); path.addLine(to: point(17, 15))
            path.move(to: point(7, 9)); path.addLine(to: point(12, 4)); path.addLine(to: point(17, 9))
        }
        return path
    }
}
