import Foundation

enum NursingSideAction: Equatable, Sendable {
    case start
    case pause
    case switchSide

    var systemImage: String {
        switch self {
        case .start: "play.fill"
        case .pause: "pause.fill"
        case .switchSide: "arrow.left.arrow.right"
        }
    }

    var title: String {
        switch self {
        case .start: "Start"
        case .pause: "Pause"
        case .switchSide: "Switch"
        }
    }
}

/// Decides what tapping a side does: running side pauses, other side switches,
/// and when paused (or not started) either side starts directly.
enum NursingTimerControls {
    static func action(for side: NursingSide, activeSide: NursingSide?, isPaused: Bool) -> NursingSideAction {
        guard let activeSide, !isPaused else { return .start }
        return side == activeSide ? .pause : .switchSide
    }

    static func canEndSession(isPaused: Bool) -> Bool { isPaused }
}
