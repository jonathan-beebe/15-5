#if os(iOS)
import UIKit
import UserNotifications

/// iOS suspends the app in the background, so scheduled local notifications carry the sound there.
/// With no notification delegate set, iOS does not present them while the app is in the foreground.
@MainActor
@Observable
final class PlatformSession: TimerSession {
    private static let startKey = "startDate"
    private static let pausedElapsedKey = "pausedElapsed"
    /// iOS keeps at most 64 pending notifications per app.
    private static let maxPending = 64

    @ObservationIgnored private var notificationWork: Task<Void, Never>?
    @ObservationIgnored private let chime = ChimePlayer()

    /// True once the user has denied notifications, so the app can say why background alerts
    /// stay silent.
    private(set) var notificationsDenied = false

    /// Scheduled notifications outlive the process, so a relaunch resumes the running session.
    var restoredStart: Date? {
        UserDefaults.standard.object(forKey: Self.startKey) as? Date
    }

    /// A paused session has no notifications, so only its elapsed time needs to survive.
    var restoredPausedElapsed: TimeInterval? {
        UserDefaults.standard.object(forKey: Self.pausedElapsedKey) as? TimeInterval
    }

    /// While backgrounded, the notification plays the sound.
    var canAlert: Bool {
        UIApplication.shared.applicationState != .background
    }

    func began(start: Date, cycle: Cycle) {
        UserDefaults.standard.set(start, forKey: Self.startKey)
        replaceNotifications(start: start, cycle: cycle)
    }

    /// Called after `ended()`, so the start date and notifications are already gone.
    func paused(elapsed: TimeInterval) {
        UserDefaults.standard.set(elapsed, forKey: Self.pausedElapsedKey)
    }

    func ended() {
        UserDefaults.standard.removeObject(forKey: Self.startKey)
        UserDefaults.standard.removeObject(forKey: Self.pausedElapsedKey)
        chime.stop()
        replaceNotifications(start: nil, cycle: nil)
    }

    func alert(entering phase: Phase) {
        chime.play()
    }

    /// Runs after the previous replacement finishes, so a quick stop/start cannot interleave.
    private func replaceNotifications(start: Date?, cycle: Cycle?) {
        let previous = notificationWork
        previous?.cancel()
        notificationWork = Task {
            await previous?.value
            let center = UNUserNotificationCenter.current()
            center.removeAllPendingNotificationRequests()
            center.removeAllDeliveredNotifications()

            guard let start, let cycle else { return }
            do {
                notificationsDenied = try await !center.requestAuthorization(options: [.alert, .sound])
            } catch {
                logger.error("Notification authorization failed: \(error)")
                notificationsDenied = true
            }
            guard !notificationsDenied else { return }

            let now = Date.now
            let transitions = cycle.upcomingTransitions(start: start, now: now, limit: Self.maxPending)
            for (index, transition) in transitions.enumerated() {
                guard !Task.isCancelled else { return }
                let request = Self.request(
                    for: transition,
                    cycle: cycle,
                    now: now,
                    endsQueue: index == transitions.count - 1
                )
                do {
                    try await center.add(request)
                } catch {
                    logger.error("Scheduling a notification failed: \(error)")
                }
            }
        }
    }

    /// The text names the length of the phase being entered, which the user can change. The last
    /// notification in the queue asks for a visit, which refills the queue.
    nonisolated static func body(entering phase: Phase, cycle: Cycle, endsQueue: Bool = false) -> String {
        let minutes = Int((cycle.duration(of: phase) / 60).rounded())
        let body = switch phase {
        case .focus: "Break is over. \(minutes) \(minutes == 1 ? "minute" : "minutes") of focus."
        case .rest: "Focus is over. \(minutes)-minute break."
        }
        return endsQueue ? body + " Open 15-5 to keep the alerts coming." : body
    }

    private static func request(
        for transition: Transition,
        cycle: Cycle,
        now: Date,
        endsQueue: Bool
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = transition.entering.title
        content.body = body(entering: transition.entering, cycle: cycle, endsQueue: endsQueue)
        content.sound = UNNotificationSound(named: UNNotificationSoundName(ChimePlayer.fileName))
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: transition.date.timeIntervalSince(now),
            repeats: false
        )
        return UNNotificationRequest(
            identifier: "transition-\(transition.date.timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )
    }
}
#endif
