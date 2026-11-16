#if os(iOS)
import Foundation
import Testing
import UserNotifications
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

    @Test func onlyOneOfRunningAndPausedSurvives() {
        let session = PlatformSession()
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        session.paused(elapsed: 42)
        session.began(start: start, cycle: .standard)
        #expect(session.restoredStart == start)
        #expect(session.restoredPausedElapsed == nil)

        session.paused(elapsed: 43)
        #expect(session.restoredStart == nil)
        #expect(session.restoredPausedElapsed == 43)
        session.ended()
    }

    @Test func requestsAreTimeSensitiveWithTheChime() {
        let now = Date(timeIntervalSinceReferenceDate: 1_000)
        let transition = Transition(date: now.addingTimeInterval(900), entering: .rest)
        let request = PlatformSession.request(for: transition, cycle: .standard, now: now, endsQueue: false)
        #expect(request.content.interruptionLevel == .timeSensitive)
        #expect(request.content.sound == UNNotificationSound(named: UNNotificationSoundName("chime.wav")))
        #expect(request.content.title == Phase.rest.title)
        #expect(request.content.body == "Focus is over. 5-minute break.")
        let trigger = request.trigger as? UNTimeIntervalNotificationTrigger
        #expect(trigger?.timeInterval == 900)
        #expect(trigger?.repeats == false)
    }

    @Test func notificationBodyUsesTheCycleLengths() {
        let cycle = Cycle(focus: 25 * 60, rest: 10 * 60)
        #expect(PlatformSession.body(entering: .focus, cycle: cycle) == "Break is over. 25 minutes of focus.")
        #expect(PlatformSession.body(entering: .rest, cycle: cycle) == "Focus is over. 10-minute break.")
    }

    @Test func lastNotificationInTheQueueAsksForAVisit() {
        let body = PlatformSession.body(entering: .rest, cycle: .standard, endsQueue: true)
        #expect(body == "Focus is over. 5-minute break. Open 15-5 to keep the alerts coming.")
    }

    @Test func notificationBodyUsesSingularForOneMinute() {
        let cycle = Cycle(focus: 60, rest: 60)
        #expect(PlatformSession.body(entering: .focus, cycle: cycle) == "Break is over. 1 minute of focus.")
        #expect(PlatformSession.body(entering: .rest, cycle: cycle) == "Focus is over. 1-minute break.")
    }
}
#endif
