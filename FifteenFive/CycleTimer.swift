import Foundation
import Observation

@MainActor
@Observable
final class CycleTimer {
    private(set) var position: CyclePosition? {
        didSet {
            #if os(macOS)
            DockIcon.show(position, cycle: cycle)
            #endif
        }
    }
    /// Increments on each alert. The iOS flash overlay animates when this changes.
    private(set) var flashCount = 0

    /// True while paused, so the display holds its place. False once stopped.
    private(set) var isPaused = false

    /// True while running or paused.
    var isActive: Bool { position != nil }
    var isRunning: Bool { isActive && !isPaused }

    let cycle: Cycle

    @ObservationIgnored private var startDate: Date?
    @ObservationIgnored private var pausedElapsed: TimeInterval?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let chime = ChimePlayer()
    @ObservationIgnored private let session = PlatformSession()

    init(launchOptions: LaunchOptions = .current) {
        cycle = launchOptions.cycle
        if launchOptions.autostart {
            play()
        } else if let restored = session.restoredStart {
            begin(at: restored)
        }
    }

    /// Starts from the beginning, or resumes from where a pause left off.
    func play() {
        guard !isRunning else { return }
        begin(at: Date.now.addingTimeInterval(-(pausedElapsed ?? 0)))
    }

    /// Holds the current time. `play()` resumes from here.
    func pause() {
        guard isRunning, let startDate else { return }
        pausedElapsed = Date.now.timeIntervalSince(startDate)
        isPaused = true
        halt()
    }

    /// Resets to the beginning of the cycle.
    func stop() {
        pausedElapsed = nil
        isPaused = false
        position = nil
        halt()
    }

    /// Time since the start of the session, excluding pauses.
    func elapsed(at date: Date) -> TimeInterval {
        if let pausedElapsed { return pausedElapsed }
        return startDate.map { date.timeIntervalSince($0) } ?? 0
    }

    private func halt() {
        ticker?.cancel()
        ticker = nil
        startDate = nil
        chime.stop()
        session.ended()
    }

    #if DEBUG && os(macOS)
    /// Ends the current phase now, so the next phase and its alert begin immediately.
    func advanceToPhaseEnd() {
        guard let startDate else { return }
        self.startDate = cycle.startAdvancedToPhaseEnd(start: startDate, now: .now)
        tick()
    }
    #endif

    private func begin(at start: Date) {
        pausedElapsed = nil
        isPaused = false
        startDate = start
        position = cycle.position(start: start, now: .now)
        session.began(start: start, cycle: cycle)
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                self?.tick()
            }
        }
    }

    private func tick() {
        guard let startDate, let old = position else { return }
        let new = cycle.position(start: startDate, now: .now)
        guard new != old else { return }
        position = new
        if cycle.shouldAlert(from: old, to: new), session.canAlert {
            alert(entering: new.phase)
        }
    }

    private func alert(entering phase: Phase) {
        flashCount += 1
        chime.play()
        #if os(macOS)
        ScreenFlash.play(entering: phase)
        #endif
    }
}
