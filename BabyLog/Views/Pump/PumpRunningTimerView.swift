import SwiftUI

struct PumpRunningTimerView: View {
    let engine: TimerEngine

    var body: some View {
        SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: BabyLogTheme.cardSpacing) {
                Text(engine.activeState?.isPaused == true ? "Paused" : "Pumping")
                    .font(AppFont.eyebrow)
                    .foregroundStyle(TrackingCategory.pump.style.text)

                Text(Self.durationString(engine.elapsedSeconds(at: context.date)))
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(BabyLogTheme.ink)
                    .accessibilityLabel("Elapsed time")
                    .accessibilityValue(Self.accessibleDuration(engine.elapsedSeconds(at: context.date)))
            }
            .frame(maxWidth: .infinity)
            .padding(BabyLogTheme.headingPadding)
            .background(TrackingCategory.pump.style.soft)
            .clipShape(RoundedRectangle(cornerRadius: BabyLogTheme.radiusLarge))
        }
    }

    private static func durationString(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainder = seconds % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%02d:%02d", minutes, remainder)
    }

    private static func accessibleDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: interval) ?? "0 seconds"
    }
}
