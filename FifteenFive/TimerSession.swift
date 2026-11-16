import Foundation

/// Whether a background alert reaches the user, read from the platform's notification settings.
/// Each case past `ready` names the one setting that stands in the way, most severe first.
enum AlertDelivery: Equatable, Sendable {
    case ready
    /// Notifications are denied, so nothing is scheduled.
    case denied
    /// Banners are off for the app.
    case alertsOff
    /// Notification sounds are off for the app.
    case soundOff
    /// The app is in the Scheduled Summary, which holds alerts until the summary time.
    case summarized
    /// Time Sensitive is off for the app, so a Focus silences its alerts.
    case notTimeSensitive

    /// What stands in the way, for the user. Nil when alerts get through.
    var problem: String? {
        switch self {
        case .ready:
            nil
        case .denied:
            "Notifications are off, so alerts stay silent while the app is in the background."
        case .alertsOff:
            "Banners are off for 15-5, so alerts stay hidden while the app is in the background."
        case .soundOff:
            "Notification sounds are off for 15-5, so alerts stay silent while the app is in the background."
        case .summarized:
            "15-5 is in the Scheduled Summary, so alerts arrive late while the app is in the background."
        case .notTimeSensitive:
            "Time Sensitive notifications are off for 15-5, so a Focus silences alerts while the app is in the background."
        }
    }
}

/// The platform side of a session: persistence, keeping the process awake, and the alert's sound
/// and visuals. CycleTimer owns the time and the session owns the effects, so tests swap it out.
@MainActor
protocol TimerSession: AnyObject {
    /// A running session that outlived the process, as its start date.
    var restoredStart: Date? { get }
    /// A paused session that outlived the process, as its elapsed time.
    var restoredPausedElapsed: TimeInterval? { get }
    /// False when the platform delivers the alert another way, such as a notification.
    var canAlert: Bool { get }
    /// Whether that other way reaches the user. Refreshed by `began`.
    var alertDelivery: AlertDelivery { get }

    func began(start: Date, cycle: Cycle)
    func paused(elapsed: TimeInterval)
    /// Ends a run or a pause. An alert in progress stops here.
    func ended()
    func alert(entering phase: Phase)

    /// The position to display: once at launch, on every tick, and nil on stop.
    func show(_ position: CyclePosition?, cycle: Cycle)
    /// The lengths changed while stopped, as often as a scroll moves.
    func cycleChanged(_ cycle: Cycle)
}
