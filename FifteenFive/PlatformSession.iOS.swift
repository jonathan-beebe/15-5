#if os(iOS)
import UIKit
import UserNotifications
import WidgetKit

/// iOS suspends the app in the background, so scheduled local notifications carry the sound there.
/// With no notification delegate set, iOS does not present them while the app is in the foreground.
@MainActor
@Observable
final class PlatformSession: TimerSession {
    /// iOS keeps at most 64 pending notifications per app.
    private static let maxPending = 64

    @ObservationIgnored private var notificationWork: Task<Void, Never>?
    @ObservationIgnored private var pendingWidgetReload: Task<Void, Never>?
    @ObservationIgnored private let chime = ChimePlayer()

    /// Read from the notification settings each time a session begins or the app returns to the
    /// foreground, so the app can say which setting keeps background alerts from the user.
    private(set) var alertDelivery = AlertDelivery.ready

    /// Scheduled notifications outlive the process, so a relaunch resumes the running session.
    var restoredStart: Date? {
        if case .running(let start) = SessionStore.shared.state { return start }
        return nil
    }

    /// A paused session has no notifications, so only its elapsed time needs to survive.
    var restoredPausedElapsed: TimeInterval? {
        if case .paused(let elapsed) = SessionStore.shared.state { return elapsed }
        return nil
    }

    /// While backgrounded, the notification plays the sound.
    var canAlert: Bool {
        UIApplication.shared.applicationState != .background
    }

    /// The widget reads the store, so every state change reloads its timeline.
    func began(start: Date, cycle: Cycle) {
        SessionStore.shared.save(.running(start: start))
        WidgetCenter.shared.reloadAllTimelines()
        replaceNotifications(start: start, cycle: cycle)
    }

    func paused(elapsed: TimeInterval) {
        SessionStore.shared.save(.paused(elapsed: elapsed))
        WidgetCenter.shared.reloadAllTimelines()
    }

    func ended() {
        SessionStore.shared.save(.stopped)
        WidgetCenter.shared.reloadAllTimelines()
        chime.stop()
        replaceNotifications(start: nil, cycle: nil)
    }

    func alert(entering phase: Phase) {
        chime.play()
    }

    func show(_ position: CyclePosition?, cycle: Cycle) {}

    /// WidgetKit budgets reloads, so wait for the scrolling to pause.
    func cycleChanged(_ cycle: Cycle) {
        pendingWidgetReload?.cancel()
        pendingWidgetReload = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
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
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                logger.error("Notification authorization failed: \(error)")
            }
            alertDelivery = Self.delivery(from: await center.notificationSettings())
            guard alertDelivery != .denied else { return }

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

    /// The first setting that keeps an alert from the user. `.notSupported` for Time Sensitive
    /// means the build lacks the entitlement, which is a build problem and not the user's.
    nonisolated static func delivery(from settings: UNNotificationSettings) -> AlertDelivery {
        switch settings.authorizationStatus {
        case .denied, .notDetermined: return .denied
        case .authorized, .provisional, .ephemeral: break
        @unknown default: break
        }
        if settings.alertSetting == .disabled { return .alertsOff }
        if settings.soundSetting == .disabled { return .soundOff }
        if settings.scheduledDeliverySetting == .enabled { return .summarized }
        if settings.timeSensitiveSetting == .disabled { return .notTimeSensitive }
        return .ready
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

    /// Time Sensitive, so a Focus or the Scheduled Summary lets the alert through at its time.
    /// A timer the user set is within Apple's stated use for the level.
    nonisolated static func request(
        for transition: Transition,
        cycle: Cycle,
        now: Date,
        endsQueue: Bool
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = transition.entering.title
        content.body = body(entering: transition.entering, cycle: cycle, endsQueue: endsQueue)
        content.sound = UNNotificationSound(named: UNNotificationSoundName(ChimePlayer.fileName))
        content.interruptionLevel = .timeSensitive
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
