import Foundation

/// A session as seen from outside the process: enough for the widget to show it and the app to
/// restore it.
enum SessionState: Equatable, Sendable {
    case stopped
    /// `start` is virtual: now minus elapsed time excluding pauses. Phase comes from
    /// `Cycle.position(start:now:)`.
    case running(start: Date)
    case paused(elapsed: TimeInterval)
}

extension UserDefaults {
    /// The app group suite shared with the widget, or `.standard` where there is none. The
    /// identifier comes from Info.plist so the entitlement and this string cannot drift apart.
    /// The macOS app has no widget and no app group entitlement, so it keeps `.standard`.
    /// UserDefaults is thread-safe, so the unsafe marker is only for the compiler.
    nonisolated(unsafe) static let appGroup: UserDefaults = {
        #if os(macOS)
        return .standard
        #else
        guard let identifier = Bundle.main.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
              let suite = UserDefaults(suiteName: identifier)
        else { return .standard }
        return suite
        #endif
    }()
}

/// Persists the session and the cycle lengths in UserDefaults. Keys: "startDate" (Date),
/// "pausedElapsed" (Double), and SavedCycle's "focusSeconds"/"restSeconds". Only one of
/// startDate/pausedElapsed is set at a time, so a relaunch never sees both a running and a
/// paused session.
struct SessionStore: @unchecked Sendable {
    private static let startKey = "startDate"
    private static let pausedElapsedKey = "pausedElapsed"
    /// Every key the store owns, including SavedCycle's, for the one-time move between suites.
    private static let allKeys = [startKey, pausedElapsedKey, "focusSeconds", "restSeconds"]

    /// UserDefaults is thread-safe, which is what the unchecked conformance stands on.
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// The shipped app kept these keys in `.standard`, so the first access moves them to the
    /// app group suite where the widget can read them.
    static let shared: SessionStore = {
        let store = SessionStore(defaults: .appGroup)
        store.migrate(from: .standard)
        return store
    }()

    var cycle: Cycle {
        SavedCycle.load(from: defaults) ?? .standard
    }

    func save(_ cycle: Cycle) {
        SavedCycle.save(cycle, to: defaults)
    }

    var state: SessionState {
        if let start = defaults.object(forKey: Self.startKey) as? Date {
            return .running(start: start)
        }
        if let elapsed = defaults.object(forKey: Self.pausedElapsedKey) as? TimeInterval {
            return .paused(elapsed: elapsed)
        }
        return .stopped
    }

    func save(_ state: SessionState) {
        switch state {
        case .stopped:
            defaults.removeObject(forKey: Self.startKey)
            defaults.removeObject(forKey: Self.pausedElapsedKey)
        case .running(let start):
            defaults.set(start, forKey: Self.startKey)
            defaults.removeObject(forKey: Self.pausedElapsedKey)
        case .paused(let elapsed):
            defaults.set(elapsed, forKey: Self.pausedElapsedKey)
            defaults.removeObject(forKey: Self.startKey)
        }
    }

    /// Moves the keys from `source` when this store has none of them. Runs once in effect: after
    /// the move the source is empty. A store backed by `source` itself has nothing to move.
    func migrate(from source: UserDefaults) {
        guard source !== defaults else { return }
        guard Self.allKeys.allSatisfy({ defaults.object(forKey: $0) == nil }) else { return }
        for key in Self.allKeys {
            guard let value = source.object(forKey: key) else { continue }
            defaults.set(value, forKey: key)
            source.removeObject(forKey: key)
        }
    }
}
