import Foundation
import Testing
@testable import FifteenFive

@MainActor
struct CycleTimerTests {
    private func makeTimer() -> CycleTimer {
        let timer = CycleTimer(launchOptions: LaunchOptions())
        timer.stop()
        return timer
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
        let elapsed = timer.elapsed(at: .now)

        try await Task.sleep(for: .seconds(1.2))

        #expect(timer.isPaused)
        #expect(timer.isActive)
        #expect(!timer.isRunning)
        #expect(timer.position == held)
        #expect(timer.elapsed(at: .now) == elapsed)
        timer.stop()
    }

    @Test func playResumesFromThePausedTime() async throws {
        let timer = makeTimer()
        timer.play()
        try await Task.sleep(for: .seconds(1.2))
        timer.pause()
        let elapsed = timer.elapsed(at: .now)

        try await Task.sleep(for: .seconds(1.2))
        timer.play()

        #expect(timer.isRunning)
        #expect(!timer.isPaused)
        // Under the 1.2s spent paused, with room for a busy test machine.
        #expect(abs(timer.elapsed(at: .now) - elapsed) < 1)
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
        #expect(timer.elapsed(at: .now) < 1)
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
