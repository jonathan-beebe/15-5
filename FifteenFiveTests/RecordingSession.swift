import Foundation
@testable import FifteenFive

/// Records what the timer asks of its session, with nothing persisted and no sound or wash.
@MainActor
final class RecordingSession: TimerSession {
    enum Event: Equatable {
        case began(start: Date, cycle: Cycle)
        case paused(elapsed: TimeInterval)
        case ended
        case alert(Phase)
    }

    var restoredStart: Date?
    var restoredPausedElapsed: TimeInterval?
    var canAlert = true
    var notificationsDenied = false
    private(set) var events: [Event] = []

    func began(start: Date, cycle: Cycle) { events.append(.began(start: start, cycle: cycle)) }
    func paused(elapsed: TimeInterval) { events.append(.paused(elapsed: elapsed)) }
    func ended() { events.append(.ended) }
    func alert(entering phase: Phase) { events.append(.alert(phase)) }
    /// Display updates happen on every tick, so recording them would bury the other events.
    func show(_ position: CyclePosition?, cycle: Cycle) {}
    func cycleChanged(_ cycle: Cycle) {}
}
