import SwiftUI
import WidgetKit

/// What an entry shows, derived once so every family reads the session the same way.
enum TimerDisplay {
    /// `countdown` spans the whole phase, so the bar's zero is the phase's start and the text
    /// counts down to its end.
    case running(phase: Phase, countdown: ClosedRange<Date>, next: Transition)
    case paused(position: CyclePosition)
    case stopped

    /// Stopped uses the focus colors, which match the app icon.
    var phase: Phase {
        switch self {
        case .running(let phase, _, _): phase
        case .paused(let position): position.phase
        case .stopped: .focus
        }
    }
}

extension TimerEntry {
    /// A timeline entry sits exactly on a transition, and Date arithmetic can leave its date a few
    /// nanoseconds short of it, which would show the old phase with 0:00 left until the next entry.
    /// Reading the position a tenth of a second ahead steps over that.
    private static let transitionTolerance: TimeInterval = 0.1

    var display: TimerDisplay {
        switch state {
        case .running(let start):
            let probe = date.addingTimeInterval(Self.transitionTolerance)
            let phase = cycle.position(start: start, now: probe).phase
            // Limit 1 always yields one transition.
            let next = cycle.upcomingTransitions(start: start, now: probe, limit: 1).first!
            let phaseStart = next.date.addingTimeInterval(-cycle.duration(of: phase))
            return .running(phase: phase, countdown: phaseStart ... next.date, next: next)
        case .paused(let elapsed):
            return .paused(position: cycle.position(elapsed: elapsed))
        case .stopped:
            return .stopped
        }
    }
}

struct TimerWidgetView: View {
    let entry: TimerEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryCircular:
            CircularView(entry: entry)
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .accessoryInline:
            InlineView(entry: entry)
        #endif
        default:
            SystemView(entry: entry, family: family)
        }
    }
}

/// The widget's display name, shown while stopped.
private let appName = "15-5"

private func minutes(_ seconds: TimeInterval) -> Int {
    Int((seconds / 60).rounded())
}

/// The lengths as the app shows them when stopped, e.g. "15 / 5".
private func lengthsText(_ cycle: Cycle) -> String {
    "\(minutes(cycle.focus)) / \(minutes(cycle.rest))"
}

/// Home Screen: white text on the phase gradient, the countdown as the hero.
private struct SystemView: View {
    let entry: TimerEntry
    let family: WidgetFamily

    private var display: TimerDisplay { entry.display }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                title
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if case .paused = display {
                    Image(systemName: "pause.fill")
                        .font(.caption.weight(.bold))
                        .accessibilityLabel("Paused")
                }
            }
            Spacer(minLength: 0)
            if family == .systemMedium {
                HStack(alignment: .lastTextBaseline) {
                    hero
                    Spacer(minLength: 8)
                    detail
                }
            } else {
                hero
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .containerBackground(for: .widget) {
            LinearGradient(colors: display.phase.gradientColors, startPoint: .top, endPoint: .bottom)
        }
    }

    private var title: Text {
        switch display {
        case .running(let phase, _, _): Text(phase.title)
        case .paused(let position): Text(position.phase.title)
        case .stopped: Text(appName)
        }
    }

    @ViewBuilder private var hero: some View {
        Group {
            switch display {
            case .running(_, let countdown, _):
                Text(timerInterval: countdown, countsDown: true, showsHours: false)
            case .paused(let position):
                Text(Cycle.clockText(seconds: position.secondsRemaining))
            case .stopped:
                Text(lengthsText(entry.cycle))
            }
        }
        // Sized so "60:00" fits the small family. A scale factor would make WidgetKit bake the
        // live timer text into a static image.
        .font(.system(size: family == .systemMedium ? 52 : 40, weight: .bold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The medium family's right column.
    @ViewBuilder private var detail: some View {
        VStack(alignment: .trailing, spacing: 2) {
            switch display {
            case .running(_, _, let next):
                Text("Next")
                    .font(.caption)
                Text(next.entering.title)
                    .font(.headline)
                Text(next.date, style: .time)
                    .font(.subheadline)
            case .paused:
                Text("Paused")
                    .font(.headline)
            case .stopped:
                Text("Focus \(minutes(entry.cycle.focus)) min")
                Text("Break \(minutes(entry.cycle.rest)) min")
            }
        }
        .font(.subheadline)
        .lineLimit(1)
        .multilineTextAlignment(.trailing)
    }

    @ViewBuilder private var footer: some View {
        switch display {
        case .running(_, let countdown, _):
            // Fills left to right as the phase passes.
            ProgressView(timerInterval: countdown, countsDown: false, label: {}, currentValueLabel: {})
                .tint(.white)
        case .paused(let position):
            ProgressView(value: entry.cycle.fractionElapsed(of: position))
                .tint(.white)
        case .stopped:
            Text("Focus / Break")
                .font(.caption)
        }
    }
}

#if os(iOS)
/// Lock Screen circle: a ring filling through the phase around the time left.
private struct CircularView: View {
    let entry: TimerEntry

    var body: some View {
        Group {
            switch entry.display {
            case .running(_, let countdown, _):
                ProgressView(timerInterval: countdown, countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    Text(timerInterval: countdown, countsDown: true, showsHours: false)
                        .multilineTextAlignment(.center)
                }
            case .paused(let position):
                ProgressView(value: entry.cycle.fractionElapsed(of: position)) {
                    EmptyView()
                } currentValueLabel: {
                    VStack(spacing: 0) {
                        Image(systemName: "pause.fill")
                            .font(.caption2)
                            .accessibilityLabel("Paused")
                        Text(Cycle.clockText(seconds: position.secondsRemaining))
                    }
                }
            case .stopped:
                VStack(spacing: 2) {
                    Image(systemName: "timer")
                        .font(.title3)
                        .widgetAccentable()
                    Text(lengthsText(entry.cycle))
                        .font(.caption2)
                }
            }
        }
        .progressViewStyle(.circular)
        .font(.system(.caption, design: .rounded).weight(.bold))
        .monospacedDigit()
        .lineLimit(1)
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }
}

/// Lock Screen rectangle: the phase above the time left.
private struct RectangularView: View {
    let entry: TimerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                title
                    .font(.headline)
                    .widgetAccentable()
                if case .paused = entry.display {
                    Image(systemName: "pause.fill")
                        .font(.caption2)
                        .accessibilityLabel("Paused")
                }
            }
            hero
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .multilineTextAlignment(.leading)
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }

    private var title: Text {
        switch entry.display {
        case .running(let phase, _, _): Text(phase.title)
        case .paused(let position): Text(position.phase.title)
        case .stopped: Text(appName)
        }
    }

    private var hero: Text {
        switch entry.display {
        case .running(_, let countdown, _): Text(timerInterval: countdown, countsDown: true, showsHours: false)
        case .paused(let position): Text(Cycle.clockText(seconds: position.secondsRemaining))
        case .stopped: Text("\(lengthsText(entry.cycle)) min")
        }
    }
}

/// Lock Screen inline: one line beside the date.
private struct InlineView: View {
    let entry: TimerEntry

    var body: some View {
        Label {
            text
        } icon: {
            Image(systemName: "timer")
        }
        .containerBackground(for: .widget) {
            AccessoryWidgetBackground()
        }
    }

    private var text: Text {
        switch entry.display {
        case .running(let phase, let countdown, _):
            Text("\(phase.title) \(Text(timerInterval: countdown, countsDown: true, showsHours: false))")
        case .paused(let position):
            Text("\(position.phase.title) \(Cycle.clockText(seconds: position.secondsRemaining)) · Paused")
        case .stopped:
            Text("\(appName) · \(lengthsText(entry.cycle))")
        }
    }
}
#endif

// MARK: - Previews

extension TimerEntry {
    /// Focus with 15:00 left, Break with 4:00 left, Focus paused at 10:33, and stopped.
    @MainActor static var previews: [TimerEntry] {
        let now = Date()
        return [
            .sample(at: now),
            TimerEntry(date: now, state: .running(start: now.addingTimeInterval(-16 * 60)), cycle: .standard),
            TimerEntry(date: now, state: .paused(elapsed: 4 * 60 + 27), cycle: .standard),
            TimerEntry(date: now, state: .stopped, cycle: .standard),
        ]
    }
}

#Preview("Small", as: .systemSmall) {
    TimerWidget()
} timeline: {
    for entry in TimerEntry.previews { entry }
}

#Preview("Medium", as: .systemMedium) {
    TimerWidget()
} timeline: {
    for entry in TimerEntry.previews { entry }
}

#if os(iOS)
#Preview("Circular", as: .accessoryCircular) {
    TimerWidget()
} timeline: {
    for entry in TimerEntry.previews { entry }
}

#Preview("Rectangular", as: .accessoryRectangular) {
    TimerWidget()
} timeline: {
    for entry in TimerEntry.previews { entry }
}

#Preview("Inline", as: .accessoryInline) {
    TimerWidget()
} timeline: {
    for entry in TimerEntry.previews { entry }
}
#endif
