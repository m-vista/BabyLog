import Foundation

enum RelativeTimeService {
    static func string(for date: Date, relativeTo now: Date = .now) -> String {
        let elapsedSeconds = max(0, now.timeIntervalSince(date))
        guard elapsedSeconds >= 60 else { return "Now" }

        let totalMinutes = Int(elapsedSeconds / 60)
        guard totalMinutes >= 60 else { return "\(totalMinutes)m ago" }

        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return minutes == 0 ? "\(hours)h ago" : "\(hours)h \(minutes)m ago"
    }
}
