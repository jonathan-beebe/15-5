#if os(iOS)
import Foundation
import Testing
@testable import FifteenFive

@MainActor
struct PlatformSessionTests {
    @Test func pausedElapsedSurvivesUntilEnded() {
        let session = PlatformSession()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        session.began(start: start, cycle: .standard)
        #expect(session.restoredStart == start)
        #expect(session.restoredPausedElapsed == nil)

        session.ended()
        session.paused(elapsed: 42)
        #expect(session.restoredStart == nil)
        #expect(session.restoredPausedElapsed == 42)

        session.ended()
        #expect(session.restoredPausedElapsed == nil)
    }

    @Test func notificationBodyUsesTheCycleLengths() {
        let cycle = Cycle(focus: 25 * 60, rest: 10 * 60)
        #expect(PlatformSession.body(entering: .focus, cycle: cycle) == "Break is over. 25 minutes of focus.")
        #expect(PlatformSession.body(entering: .rest, cycle: cycle) == "Focus is over. 10-minute break.")
    }

    @Test func notificationBodyUsesSingularForOneMinute() {
        let cycle = Cycle(focus: 60, rest: 60)
        #expect(PlatformSession.body(entering: .focus, cycle: cycle) == "Break is over. 1 minute of focus.")
        #expect(PlatformSession.body(entering: .rest, cycle: cycle) == "Focus is over. 1-minute break.")
    }
}
#endif
