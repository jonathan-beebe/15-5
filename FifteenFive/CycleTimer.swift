import Foundation
import Observation

@MainActor
@Observable
final class CycleTimer {
    private(set) var position: CyclePosition? {
        didSet { session.show(position, cycle: cycle) }
    }
    /// Increments on each alert. The iOS flash overlay animates when this changes.
    private(set) var flashCount = 0

    /// True while paused, so the display holds its place. False once stopped.
    private(set) var isPaused = false

    /// The phase `play()` starts from. Only changes while stopped.
    private(set) var selectedPhase = Phase.focus

    /// True when background alerts can't sound because the user denied notifications.
    var notificationsDenied: Bool { session.notificationsDenied }

    /// True while running or paused.
    var isActive: Bool { position != nil }
    var isRunning: Bool { isActive && !isPaused }

    private(set) var cycle: Cycle {
        didSet { session.cycleChanged(cycle) }
    }

    /// Elapsed time comes from the continuous clock, which keeps counting through sleep and holds
    /// still through wall-clock changes. The wall-clock date is kept only for the session to persist.
    @ObservationIgnored private let clock = ContinuousClock()
    @ObservationIgnored private var startInstant: ContinuousClock.Instant?
    @ObservationIgnored private var pausedElapsed: TimeInterval?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let saveCycle: (Cycle) -> Void
    @ObservationIgnored private let session: any TimerSession

    init(launchOptions: LaunchOptions = .current, session: any TimerSession = PlatformSession()) {
        cycle = launchOptions.cycle
        saveCycle = launchOptions.saveCycle
        self.session = session
        session.show(nil, cycle: cycle)
        if launchOptions.autostart {
            play()
        } else if let restored = session.restoredStart {
            begin(elapsed: Date.now.timeIntervalSince(restored))
        } else if let elapsed = session.restoredPausedElapsed {
            pausedElapsed = elapsed
            isPaused = true
            position = cycle.position(elapsed: elapsed)
        }
    }

    /// Starts from the beginning, or resumes from where a pause left off.
    func play() {
        guard !isRunning else { return }
        begin(elapsed: pausedElapsed ?? cycle.offset(of: selectedPhase))
    }

    /// Holds the current time. `play()` resumes from here.
    func pause() {
        guard isRunning else { return }
        let elapsed = elapsed()
        pausedElapsed = elapsed
        isPaused = true
        halt()
        session.paused(elapsed: elapsed)
    }

    /// Resets to the beginning of the cycle.
    func stop() {
        selectedPhase = .focus
        pausedElapsed = nil
        isPaused = false
        position = nil
        halt()
    }

    /// Switches the phase `play()` starts from. Does nothing unless stopped.
    func flipSelectedPhase() {
        guard !isActive else { return }
        selectedPhase = selectedPhase == .focus ? .rest : .focus
    }

    /// Changes the selected phase's length. Does nothing unless stopped.
    func adjustSelectedPhase(byMinutes delta: Int) {
        guard !isActive else { return }
        cycle = cycle.adjusting(selectedPhase, byMinutes: delta)
        saveCycle(cycle)
    }

    /// iOS keeps at most 64 pending notifications, so each return to the foreground refills them.
    func refreshAlerts() {
        guard isRunning else { return }
        session.began(start: Date.now.addingTimeInterval(-elapsed()), cycle: cycle)
    }

    /// Time since the start of the session, excluding pauses.
    func elapsed() -> TimeInterval {
        if let pausedElapsed { return pausedElapsed }
        guard let startInstant else { return 0 }
        return (clock.now - startInstant).seconds
    }

    private func halt() {
        ticker?.cancel()
        ticker = nil
        startInstant = nil
        session.ended()
    }

    #if DEBUG && os(macOS)
    /// Ends the current phase now, so the next phase and its alert begin immediately.
    func advanceToPhaseEnd() {
        guard let startInstant, let position else { return }
        self.startInstant = startInstant - .seconds(position.secondsRemaining)
        tick()
    }
    #endif

    private func begin(elapsed: TimeInterval) {
        pausedElapsed = nil
        isPaused = false
        startInstant = clock.now - .seconds(elapsed)
        position = cycle.position(elapsed: elapsed)
        session.began(start: Date.now.addingTimeInterval(-elapsed), cycle: cycle)
        ticker?.cancel()
        ticker = Task { [weak self] in
            // A thrown sleep means the task was cancelled. A nil self means the timer was released.
            while (try? await Task.sleep(for: .milliseconds(250))) != nil {
                guard let self else { return }
                tick()
            }
        }
    }

    private func tick() {
        guard startInstant != nil, let old = position else { return }
        let new = cycle.position(elapsed: elapsed())
        guard new != old else { return }
        position = new
        if cycle.shouldAlert(from: old, to: new), session.canAlert {
            alert(entering: new.phase)
        }
    }

    private func alert(entering phase: Phase) {
        flashCount += 1
        session.alert(entering: phase)
    }
}

private extension Duration {
    var seconds: TimeInterval {
        let (seconds, attoseconds) = components
        return TimeInterval(seconds) + TimeInterval(attoseconds) / 1e18
    }
}
