#if os(macOS)
import Foundation

/// macOS keeps the app running in the background. The activity disables App Nap and idle system
/// sleep, which would delay the timer. The display may sleep: the chime still sounds.
@MainActor
final class PlatformSession: TimerSession {
    private var activity: NSObjectProtocol?
    private let chime = ChimePlayer()

    let restoredStart: Date? = nil
    let restoredPausedElapsed: TimeInterval? = nil
    let canAlert = true
    let notificationsDenied = false

    func began(start: Date, cycle: Cycle) {
        endActivity()
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "15-5 timer running"
        )
    }

    func paused(elapsed: TimeInterval) {}

    func ended() {
        endActivity()
        chime.stop()
        ScreenFlash.cancel()
    }

    func alert(entering phase: Phase) {
        chime.play()
        ScreenFlash.play(entering: phase)
    }

    private func endActivity() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }
}
#endif
