import Foundation

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
    var notificationsDenied: Bool { get }

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
