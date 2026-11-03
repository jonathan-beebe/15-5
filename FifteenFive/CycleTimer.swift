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

    var isRunning: Bool { position != nil }

    let cycle: Cycle

    @ObservationIgnored private var startDate: Date?
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let chime = ChimePlayer()
    @ObservationIgnored private let session = PlatformSession()

    init(launchOptions: LaunchOptions = .current) {
        cycle = launchOptions.cycle
        if launchOptions.autostart {
            start()
        } else if let restored = session.restoredStart {
            begin(at: restored)
        }
    }

    func start() {
        begin(at: .now)
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
        startDate = nil
        position = nil
        chime.stop()
        session.ended()
    }

    func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
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
