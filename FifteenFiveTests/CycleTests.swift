import Foundation
import Testing
@testable import FifteenFive

struct CycleTests {
    private let cycle = Cycle.standard
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    private func position(at seconds: TimeInterval) -> CyclePosition {
        cycle.position(start: start, now: start.addingTimeInterval(seconds))
    }

    @Test func clockTextPadsMinutesAndSeconds() {
        #expect(Cycle.clockText(seconds: 900) == "15:00")
        #expect(Cycle.clockText(seconds: 65) == "01:05")
        #expect(Cycle.clockText(seconds: 0) == "00:00")
    }

    @Test func fractionElapsedIsRelativeToTheCurrentPhase() {
        #expect(cycle.fractionElapsed(of: position(at: 0)) == 0)
        #expect(cycle.fractionElapsed(of: position(at: 450)) == 0.5)
        #expect(cycle.fractionElapsed(of: position(at: 900)) == 0)
        #expect(cycle.fractionElapsed(of: position(at: 1050)) == 0.5)
    }

    #if DEBUG
    @Test func advancingToPhaseEndEntersTheNextPhaseAndAlerts() {
        let now = start.addingTimeInterval(100.5)
        let old = position(at: 100.5)
        let new = cycle.position(start: cycle.startAdvancedToPhaseEnd(start: start, now: now), now: now)
        #expect(new == CyclePosition(transitionCount: 1, phase: .rest, secondsRemaining: 300))
        #expect(cycle.shouldAlert(from: old, to: new))
    }

    @Test func advancingFromBreakEntersFocus() {
        let now = start.addingTimeInterval(1000)
        let new = cycle.position(start: cycle.startAdvancedToPhaseEnd(start: start, now: now), now: now)
        #expect(new == CyclePosition(transitionCount: 2, phase: .focus, secondsRemaining: 900))
    }
    #endif

    @Test func startsInFocusWithFifteenMinutes() {
        #expect(position(at: 0) == CyclePosition(transitionCount: 0, phase: .focus, secondsRemaining: 900))
    }

    @Test func clockBeforeStartClampsToStart() {
        #expect(position(at: -30) == position(at: 0))
    }

    @Test func roundsPartialSecondsUp() {
        #expect(position(at: 0.2).secondsRemaining == 900)
        #expect(position(at: 1).secondsRemaining == 899)
        #expect(position(at: 899.5).secondsRemaining == 1)
    }

    @Test func entersRestAtFifteenMinutes() {
        #expect(position(at: 900) == CyclePosition(transitionCount: 1, phase: .rest, secondsRemaining: 300))
    }

    @Test func loopsToFocusAtTwentyMinutes() {
        #expect(position(at: 1199.5) == CyclePosition(transitionCount: 1, phase: .rest, secondsRemaining: 1))
        #expect(position(at: 1200) == CyclePosition(transitionCount: 2, phase: .focus, secondsRemaining: 900))
    }

    @Test func keepsLoopingAcrossManyCycles() {
        let hours = 20.0 * 1200
        #expect(position(at: hours + 900) == CyclePosition(transitionCount: 41, phase: .rest, secondsRemaining: 300))
    }

    @Test func alertsOnFreshTransition() {
        #expect(cycle.shouldAlert(from: position(at: 899.9), to: position(at: 900.1)))
        #expect(cycle.shouldAlert(from: position(at: 1199.9), to: position(at: 1201.5)))
    }

    @Test func doesNotAlertWithoutTransition() {
        #expect(!cycle.shouldAlert(from: position(at: 10), to: position(at: 11)))
    }

    @Test func doesNotAlertAfterResumingFromSuspension() {
        #expect(!cycle.shouldAlert(from: position(at: 100), to: position(at: 905)))
        #expect(!cycle.shouldAlert(from: position(at: 100), to: position(at: 5000)))
    }

    @Test func listsUpcomingTransitionsInOrder() {
        let transitions = cycle.upcomingTransitions(start: start, now: start.addingTimeInterval(1000), limit: 3)
        #expect(transitions == [
            Transition(date: start.addingTimeInterval(1200), entering: .focus),
            Transition(date: start.addingTimeInterval(2100), entering: .rest),
            Transition(date: start.addingTimeInterval(2400), entering: .focus),
        ])
    }

    @Test func upcomingTransitionsAreAllInTheFuture() {
        let now = start.addingTimeInterval(900)
        let transitions = cycle.upcomingTransitions(start: start, now: now, limit: 64)
        #expect(transitions.count == 64)
        #expect(transitions.allSatisfy { $0.date > now })
    }
}
