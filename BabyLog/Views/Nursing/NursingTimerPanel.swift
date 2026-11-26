import SwiftUI

struct NursingTimerPanel: View {
    let engine: TimerEngine
    let onTapSide: (NursingSide) -> Void

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            let durations = engine.nursingDurations(at: context.date)
                ?? NursingDurations(leftSeconds: 0, rightSeconds: 0)
            VStack(spacing: BabyLogTheme.cardSpacing) {
                HStack(spacing: BabyLogTheme.cardSpacing) {
                    sideCard(side: .left, seconds: durations.leftSeconds)
                    sideCard(side: .right, seconds: durations.rightSeconds)
                }

                HStack {
                    Text("Total")
                    Spacer()
                    Text(durationString(durations.leftSeconds + durations.rightSeconds))
                        .monospacedDigit()
                }
                .font(AppFont.primaryRow)
            }
        }
    }

    private func sideCard(side: NursingSide, seconds: TimeInterval) -> some View {
        let isActive = engine.activeState?.activeNursingSide == side
        let isRunning = isActive && engine.activeState?.isPaused == false
        let action = NursingTimerControls.action(
            for: side,
            activeSide: engine.activeState?.activeNursingSide,
            isPaused: engine.activeState?.isPaused ?? true
        )
        return Button {
            onTapSide(side)
        } label: {
            NursingSideCardLabel(
                title: title(side),
                durationText: durationString(seconds),
                action: action,
                isHighlighted: isActive,
                statusText: isRunning ? "ACTIVE" : (isActive ? "PAUSED" : nil)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title(side)) side")
        .accessibilityValue("\(durationString(seconds))\(isRunning ? ", active" : "")")
        .accessibilityHint(action.title)
    }

    private func title(_ side: NursingSide) -> String {
        side == .left ? "Left" : "Right"
    }

    private func durationString(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.down)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        return hours > 0
            ? "\(hours)h \(minutes)m \(remainder)s"
            : "\(minutes)m \(remainder)s"
    }
}

/// Side timer box with a large action symbol underlaid so it reads at a glance.
struct NursingSideCardLabel: View {
    let title: String
    let durationText: String
    let action: NursingSideAction
    var isHighlighted = false
    var statusText: String? = nil

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(title.uppercased())
                    .font(AppFont.eyebrow)
                if let statusText {
                    Text(statusText)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(TrackingCategory.feed.style.soft)
                        .clipShape(Capsule())
                }
            }
            Text(durationText)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
            Text(action.title.uppercased())
                .font(AppFont.eyebrow)
        }
        .foregroundStyle(TrackingCategory.feed.style.text)
        .frame(maxWidth: .infinity, minHeight: 120)
        .background {
            Image(systemName: action.systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)
                .foregroundStyle(TrackingCategory.feed.style.main.opacity(0.22))
                .accessibilityHidden(true)
        }
        .background(isHighlighted ? BabyLogTheme.surface : TrackingCategory.feed.style.soft)
        .overlay {
            RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall)
                .stroke(
                    isHighlighted ? TrackingCategory.feed.style.main : BabyLogTheme.divider,
                    lineWidth: isHighlighted ? 2 : 1
                )
        }
        .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall))
        .contentShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusSmall))
    }
}
