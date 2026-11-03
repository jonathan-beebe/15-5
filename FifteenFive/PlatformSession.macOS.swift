#if os(macOS)
import Foundation

/// macOS keeps the app running in the background. The activity disables App Nap, which would
/// delay the timer, and display sleep, which would hide the flash.
@MainActor
final class PlatformSession {
    private var activity: NSObjectProtocol?

    let restoredStart: Date? = nil
    let canAlert = true

    func began(start: Date, cycle: Cycle) {
        ended()
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleDisplaySleepDisabled],
            reason: "15-5 timer running"
        )
    }

    func ended() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }
}
#endif
