#if os(macOS)
import Foundation

/// macOS keeps the app running in the background. The activity disables App Nap and idle system
/// sleep, which would delay the timer. The display may sleep: the chime still sounds.
@MainActor
final class PlatformSession: TimerSession {
    private var activity: NSObjectProtocol?
    private let chime = ChimePlayer()
    private var pendingDockIconUpdate: Task<Void, Never>?

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

    func show(_ position: CyclePosition?, cycle: Cycle) {
        pendingDockIconUpdate?.cancel()
        DockIcon.show(position, cycle: cycle)
    }

    /// Setting the Dock icon is slow enough to lag a scroll, so wait for the scrolling to pause.
    func cycleChanged(_ cycle: Cycle) {
        pendingDockIconUpdate?.cancel()
        pendingDockIconUpdate = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            DockIcon.show(nil, cycle: cycle)
        }
    }

    private func endActivity() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }
}
#endif
