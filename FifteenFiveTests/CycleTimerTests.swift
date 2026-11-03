import Testing
@testable import FifteenFive

@MainActor
struct CycleTimerTests {
    @Test func startThenStopReturnsToIdle() {
        let timer = CycleTimer(launchOptions: LaunchOptions())
        timer.stop()
        #expect(!timer.isRunning)

        timer.start()
        #expect(timer.isRunning)
        #expect(timer.position?.phase == .focus)
        #expect(timer.position?.secondsRemaining == 900)

        timer.stop()
        #expect(!timer.isRunning)
        #expect(timer.position == nil)
    }

    @Test func restartBeginsANewFocusPeriod() {
        let timer = CycleTimer(launchOptions: LaunchOptions())
        timer.start()
        timer.stop()
        timer.start()
        #expect(timer.position?.transitionCount == 0)
        timer.stop()
    }
}
