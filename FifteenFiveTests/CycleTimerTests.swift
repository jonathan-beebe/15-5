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

    @Test func pauseWhileIdleDoesNothing() {
        let timer = makeTimer()
        timer.pause()
        #expect(!timer.isPaused)
        #expect(!timer.isActive)
    }
}
