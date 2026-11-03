#if os(iOS)
import UIKit
import UserNotifications

/// iOS suspends the app in the background, so scheduled local notifications carry the sound there.
/// With no notification delegate set, iOS does not present them while the app is in the foreground.
@MainActor
final class PlatformSession {
    private static let startKey = "startDate"
    /// iOS keeps at most 64 pending notifications per app.
    private static let maxPending = 64

    private var notificationWork: Task<Void, Never>?

    /// Scheduled notifications outlive the process, so a relaunch resumes the running session.
    var restoredStart: Date? {
        UserDefaults.standard.object(forKey: Self.startKey) as? Date
    }

    /// While backgrounded, the notification plays the sound.
    var canAlert: Bool {
        UIApplication.shared.applicationState != .background
    }

    func began(start: Date, cycle: Cycle) {
        UserDefaults.standard.set(start, forKey: Self.startKey)
        UIApplication.shared.isIdleTimerDisabled = true
        replaceNotifications(start: start, cycle: cycle)
    }

    func ended() {
        UserDefaults.standard.removeObject(forKey: Self.startKey)
        UIApplication.shared.isIdleTimerDisabled = false
        replaceNotifications(start: nil, cycle: nil)
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
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            guard granted else { return }

            let now = Date.now
            for transition in cycle.upcomingTransitions(start: start, now: now, limit: Self.maxPending) {
                guard !Task.isCancelled else { return }
                try? await center.add(Self.request(for: transition, now: now))
            }
        }
    }

    private static func request(for transition: Transition, now: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        switch transition.entering {
        case .focus:
            content.title = "Focus"
            content.body = "Break is over. 15 minutes of focus."
        case .rest:
            content.title = "Break"
            content.body = "Focus is over. 5 minute break."
        }
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
