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
    static let minuteRange = 1 ... 60

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

    /// A copy with the phase's length changed by whole minutes, kept within `minuteRange`.
    func adjusting(_ phase: Phase, byMinutes delta: Int) -> Cycle {
        let current = Int((duration(of: phase) / 60).rounded())
        let minutes = min(max(current + delta, Self.minuteRange.lowerBound), Self.minuteRange.upperBound)
        let seconds = TimeInterval(minutes * 60)
        return phase == .focus ? Cycle(focus: seconds, rest: rest) : Cycle(focus: focus, rest: seconds)
    }

    /// Time from the start of a cycle to the start of a phase.
    func offset(of phase: Phase) -> TimeInterval {
        phase == .focus ? 0 : focus
    }

    func position(start: Date, now: Date) -> CyclePosition {
        position(elapsed: now.timeIntervalSince(start))
    }

    /// The position `elapsed` seconds into a session that began at the start of a focus phase.
    func position(elapsed: TimeInterval) -> CyclePosition {
        let total = focus + rest
        let elapsed = max(0, elapsed)
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
