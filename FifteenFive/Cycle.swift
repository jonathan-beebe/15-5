import Foundation

enum Phase: Equatable, Sendable {
    case focus
    case rest
}

struct CyclePosition: Equatable, Sendable {
    /// Number of phase changes since the start date.
    let transitionCount: Int
    let phase: Phase
    let secondsRemaining: Int
}

struct Transition: Equatable, Sendable {
    let date: Date
    let entering: Phase
}

/// Derives all timer state from a start date, so suspension and tick jitter cannot cause drift.
struct Cycle: Equatable, Sendable {
    let focus: TimeInterval
    let rest: TimeInterval

    static let standard = Cycle(focus: 15 * 60, rest: 5 * 60)

    static func clockText(seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    func duration(of phase: Phase) -> TimeInterval {
        phase == .focus ? focus : rest
    }

    /// Share of the current phase that has passed, from 0 at its start.
    func fractionElapsed(of position: CyclePosition) -> Double {
        1 - Double(position.secondsRemaining) / duration(of: position.phase)
    }

    func position(start: Date, now: Date) -> CyclePosition {
        let total = focus + rest
        let elapsed = max(0, now.timeIntervalSince(start))
        let completedCycles = (elapsed / total).rounded(.down)
        let offset = elapsed - completedCycles * total
        let phase: Phase = offset < focus ? .focus : .rest
        let phaseEnd = phase == .focus ? focus : total
        return CyclePosition(
            transitionCount: Int(completedCycles) * 2 + (phase == .focus ? 0 : 1),
            phase: phase,
            secondsRemaining: Int((phaseEnd - offset).rounded(.up))
        )
    }

    #if DEBUG
    /// The earlier start date that puts `now` at the beginning of the next phase.
    func startAdvancedToPhaseEnd(start: Date, now: Date) -> Date {
        start.addingTimeInterval(-Double(position(start: start, now: now).secondsRemaining))
    }
    #endif

    func upcomingTransitions(start: Date, now: Date, limit: Int) -> [Transition] {
        let current = position(start: start, now: now).transitionCount
        return (current + 1 ..< current + 1 + limit).map { count in
            let completedCycles = Double(count / 2)
            let enteringRest = count % 2 == 1
            let offset = completedCycles * (focus + rest) + (enteringRest ? focus : 0)
            return Transition(date: start.addingTimeInterval(offset), entering: enteringRest ? .rest : .focus)
        }
    }

    /// True when the phase changed within the last two seconds. A larger gap means the process
    /// was suspended or asleep through the transition, and the alert would arrive late.
    func shouldAlert(from old: CyclePosition, to new: CyclePosition) -> Bool {
        new.transitionCount > old.transitionCount
            && Double(new.secondsRemaining) > duration(of: new.phase) - 2
    }
}
