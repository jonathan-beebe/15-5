#if os(macOS)
import AppKit
import WidgetKit

/// macOS keeps the app running in the background. The activity disables App Nap and idle system
/// sleep, which would delay the timer. The display may sleep: the chime still sounds.
///
/// The widget reads the session from the shared store. A session ends with the process here,
/// since nothing sounds the chime once the app has quit, so the store is cleared at launch and
/// on termination and the widget shows the timer only while the app runs.
@MainActor
final class PlatformSession: TimerSession {
    private var activity: NSObjectProtocol?
    private let chime = ChimePlayer()
    private var pendingDockIconUpdate: Task<Void, Never>?
    private var pendingWidgetReload: Task<Void, Never>?
    private var terminationObserver: NSObjectProtocol?

    let restoredStart: Date? = nil
    let restoredPausedElapsed: TimeInterval? = nil
    let canAlert = true
    let alertDelivery = AlertDelivery.ready

    init() {
        // A crash or a force quit leaves the last state behind; the next launch starts stopped.
        Self.saveAndReloadWidgets(.stopped)
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { Self.saveAndReloadWidgets(.stopped) }
        }
    }

    func began(start: Date, cycle: Cycle) {
        endActivity()
        activity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiated,
            reason: "15-5 timer running"
        )
        Self.saveAndReloadWidgets(.running(start: start))
    }

    func paused(elapsed: TimeInterval) {
        Self.saveAndReloadWidgets(.paused(elapsed: elapsed))
    }

    func ended() {
        endActivity()
        chime.stop()
        ScreenFlash.cancel()
        Self.saveAndReloadWidgets(.stopped)
    }

    func alert(entering phase: Phase) {
        chime.play()
        ScreenFlash.play(entering: phase)
    }

    func show(_ position: CyclePosition?, cycle: Cycle) {
        pendingDockIconUpdate?.cancel()
        DockIcon.show(position, cycle: cycle)
    }

    /// Setting the Dock icon is slow enough to lag a scroll, and WidgetKit budgets reloads, so
    /// both wait for the scrolling to pause.
    func cycleChanged(_ cycle: Cycle) {
        pendingDockIconUpdate?.cancel()
        pendingDockIconUpdate = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            DockIcon.show(nil, cycle: cycle)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private static func saveAndReloadWidgets(_ state: SessionState) {
        SessionStore.shared.save(state)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func endActivity() {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
    }
}
#endif
