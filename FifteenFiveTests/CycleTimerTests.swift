import Foundation
import Testing
@testable import FifteenFive

@MainActor
struct CycleTimerTests {
    private let session = RecordingSession()

    private func makeTimer(_ options: LaunchOptions = LaunchOptions()) -> CycleTimer {
        CycleTimer(launchOptions: options, session: session)
    }

    @Test func playPauseAndStopTellTheSession() {
        let timer = makeTimer()
        timer.play()
        timer.pause()
        timer.stop()

        #expect(session.events.count == 4)
        if case .began(_, let cycle) = session.events[0] { #expect(cycle == .standard) } else { Issue.record("no began") }
        #expect(session.events[1] == .ended)
        if case .paused(let elapsed) = session.events[2] { #expect(elapsed < 1) } else { Issue.record("no paused") }
        #expect(session.events[3] == .ended)
    }

    @Test func restoresARunningSession() {
        session.restoredStart = Date.now.addingTimeInterval(-100)
        let timer = makeTimer()
        #expect(timer.isRunning)
        #expect(timer.position?.phase == .focus)
        #expect(timer.position?.secondsRemaining == 800)
        timer.stop()
    }

    @Test func restoresAPausedSession() {
        session.restoredPausedElapsed = 950
        let timer = makeTimer()
        #expect(timer.isPaused)
        #expect(!timer.isRunning)
        #expect(timer.position == CyclePosition(transitionCount: 1, phase: .rest, secondsRemaining: 250))
        #expect(timer.elapsed() == 950)
        #expect(session.events.isEmpty)
    }

    @Test func aPhaseChangeAlertsOnce() async throws {
        let timer = makeTimer(LaunchOptions(cycle: Cycle(focus: 1, rest: 1), autostart: true))
        try await Task.sleep(for: .seconds(1.4))
        #expect(timer.position?.phase == .rest)
        #expect(timer.flashCount == 1)
        #expect(session.events.filter { $0 == .alert(.rest) }.count == 1)
        timer.stop()
    }

    @Test func aPhaseChangeIsSilentWhenTheSessionCannotAlert() async throws {
        session.canAlert = false
        let timer = makeTimer(LaunchOptions(cycle: Cycle(focus: 1, rest: 1), autostart: true))
        try await Task.sleep(for: .seconds(1.4))
        #expect(timer.position?.phase == .rest)
        #expect(timer.flashCount == 0)
        #expect(!session.events.contains(.alert(.rest)))
        timer.stop()
    }

    @Test func playThenStopReturnsToIdle() {
        let timer = makeTimer()
        #expect(!timer.isActive)
        #expect(!timer.isRunning)

        timer.play()
        #expect(timer.isRunning)
        #expect(timer.position?.phase == .focus)
        #expect(timer.position?.secondsRemaining == 900)

        timer.stop()
        #expect(!timer.isActive)
        #expect(timer.position == nil)
    }

    @Test func restartBeginsANewFocusPeriod() {
        let timer = makeTimer()
        timer.play()
        timer.stop()
        timer.play()
        #expect(timer.position?.transitionCount == 0)
        timer.stop()
    }

    @Test func pauseHoldsTheTimeAndStaysActive() async throws {
        let timer = makeTimer()
        timer.play()
        timer.pause()
        let held = timer.position
        let elapsed = timer.elapsed()

        try await Task.sleep(for: .seconds(1.2))

        #expect(timer.isPaused)
        #expect(timer.isActive)
        #expect(!timer.isRunning)
        #expect(timer.position == held)
        #expect(timer.elapsed() == elapsed)
        timer.stop()
    }

    @Test func playResumesFromThePausedTime() async throws {
        let timer = makeTimer()
        timer.play()
        try await Task.sleep(for: .seconds(1.2))
        timer.pause()
        let elapsed = timer.elapsed()

        try await Task.sleep(for: .seconds(1.2))
        timer.play()

        #expect(timer.isRunning)
        #expect(!timer.isPaused)
        // Under the 1.2s spent paused, with room for a busy test machine.
        #expect(abs(timer.elapsed() - elapsed) < 1)
        timer.stop()
    }

    @Test func stopWhilePausedResets() async throws {
        let timer = makeTimer()
        timer.play()
        try await Task.sleep(for: .seconds(1.2))
        timer.pause()
        timer.stop()
        #expect(!timer.isPaused)
        #expect(!timer.isActive)

        timer.play()
        // Under the 1.2s from before the stop, with room for a busy test machine.
        #expect(timer.elapsed() < 1)
        timer.stop()
    }

    @Test func flippingWhileStoppedStartsTheOtherPhase() {
        let timer = makeTimer()
        timer.flipSelectedPhase()
        #expect(timer.selectedPhase == .rest)
        #expect(!timer.isActive)

        timer.play()
        #expect(timer.position == CyclePosition(transitionCount: 1, phase: .rest, secondsRemaining: 300))
        timer.stop()
    }

    @Test func flippingTwiceReturnsToFocus() {
        let timer = makeTimer()
        timer.flipSelectedPhase()
        timer.flipSelectedPhase()
        #expect(timer.selectedPhase == .focus)
    }

    @Test func flippingDoesNothingWhileRunningOrPaused() {
        let timer = makeTimer()
        timer.play()
        timer.flipSelectedPhase()
        #expect(timer.selectedPhase == .focus)
        #expect(timer.position?.phase == .focus)

        timer.pause()
        timer.flipSelectedPhase()
        #expect(timer.selectedPhase == .focus)
        #expect(timer.position?.phase == .focus)
        timer.stop()
    }

    @Test func pauseAndResumeKeepTheSelectedPhase() {
        let timer = makeTimer()
        timer.flipSelectedPhase()
        timer.play()
        timer.pause()
        timer.play()
        #expect(timer.position?.phase == .rest)
        timer.stop()
    }

    @Test func stopReturnsTheSelectionToFocus() {
        let timer = makeTimer()
        timer.flipSelectedPhase()
        timer.play()
        timer.stop()
        #expect(timer.selectedPhase == .focus)
    }

    @Test func adjustingWhileStoppedChangesTheSelectedPhase() {
        let timer = makeTimer()
        timer.adjustSelectedPhase(byMinutes: 10)
        #expect(timer.cycle == Cycle(focus: 25 * 60, rest: 5 * 60))

        timer.flipSelectedPhase()
        timer.adjustSelectedPhase(byMinutes: 1)
        #expect(timer.cycle == Cycle(focus: 25 * 60, rest: 6 * 60))
    }

    @Test func playUsesTheAdjustedLength() {
        let timer = makeTimer()
        timer.adjustSelectedPhase(byMinutes: 10)
        timer.play()
        #expect(timer.position?.secondsRemaining == 25 * 60)
        timer.stop()
    }

    @Test func adjustingDoesNothingWhileRunningOrPaused() {
        let timer = makeTimer()
        timer.play()
        timer.adjustSelectedPhase(byMinutes: 5)
        #expect(timer.cycle == .standard)
        timer.pause()
        timer.adjustSelectedPhase(byMinutes: 5)
        #expect(timer.cycle == .standard)
        timer.stop()
    }

    @Test func lengthsSurviveStop() {
        let timer = makeTimer()
        timer.adjustSelectedPhase(byMinutes: 10)
        timer.play()
        timer.stop()
        #expect(timer.cycle.focus == 25 * 60)
    }

    @Test func adjustingSavesTheCycle() {
        var saved: [Cycle] = []
        var options = LaunchOptions()
        options.saveCycle = { saved.append($0) }
        let timer = CycleTimer(launchOptions: options)
        timer.stop()
        timer.adjustSelectedPhase(byMinutes: 1)
        #expect(saved == [Cycle(focus: 16 * 60, rest: 5 * 60)])
    }

    @Test func pauseWhileIdleDoesNothing() {
        let timer = makeTimer()
        timer.pause()
        #expect(!timer.isPaused)
        #expect(!timer.isActive)
    }
}
