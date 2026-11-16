import SwiftUI
import WidgetKit

@main
struct FifteenFiveWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerWidget()
    }
}

/// The current phase and the time left in it, on the Home Screen and the Lock Screen.
struct TimerWidget: Widget {
    static let kind = "timer"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TimerProvider()) { entry in
            TimerWidgetView(entry: entry)
        }
        .configurationDisplayName("Timer")
        .description("The current phase and the time left in it.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct TimerEntry: TimelineEntry {
    let date: Date
    let state: SessionState
    let cycle: Cycle

    /// A running focus phase with the full 15 minutes left: the gallery and the placeholder.
    static func sample(at date: Date = Date()) -> TimerEntry {
        TimerEntry(date: date, state: .running(start: date), cycle: .standard)
    }
}

/// Reads the session the app saved to the app group. The entries carry the whole session, so a
/// view can derive its phase and countdown from its own date without the process running.
struct TimerProvider: TimelineProvider {
    /// How many transitions a running timeline schedules before WidgetKit asks again.
    static let transitionLimit = 32

    func placeholder(in context: Context) -> TimerEntry {
        .sample()
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (TimerEntry) -> Void) {
        completion(.sample())
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<TimerEntry>) -> Void) {
        let store = SessionStore.shared
        completion(Self.timeline(state: store.state, cycle: store.cycle, now: Date()))
    }

    /// Running: an entry now and one at each upcoming transition, so the phase flips on time.
    /// Paused and stopped: one entry that stays until the app reloads the timeline on its next change.
    static func timeline(state: SessionState, cycle: Cycle, now: Date) -> Timeline<TimerEntry> {
        switch state {
        case .running(let start):
            let dates = [now] + cycle.upcomingTransitions(start: start, now: now, limit: transitionLimit).map(\.date)
            let entries = dates.map { TimerEntry(date: $0, state: state, cycle: cycle) }
            return Timeline(entries: entries, policy: .atEnd)
        case .paused, .stopped:
            return Timeline(entries: [TimerEntry(date: now, state: state, cycle: cycle)], policy: .never)
        }
    }
}
