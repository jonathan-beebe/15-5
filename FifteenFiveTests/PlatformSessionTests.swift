#if os(iOS)
import Testing
@testable import FifteenFive

struct PlatformSessionTests {
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
