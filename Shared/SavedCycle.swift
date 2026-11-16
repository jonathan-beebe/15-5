import Foundation

/// iOS restores a running session after a relaunch, and its position depends on these lengths.
enum SavedCycle {
    private static let focusKey = "focusSeconds"
    private static let restKey = "restSeconds"

    static func load(from defaults: UserDefaults) -> Cycle? {
        let focus = defaults.double(forKey: focusKey)
        let rest = defaults.double(forKey: restKey)
        guard focus > 0, rest > 0 else { return nil }
        return Cycle(focus: focus, rest: rest)
    }

    static func save(_ cycle: Cycle, to defaults: UserDefaults) {
        defaults.set(cycle.focus, forKey: focusKey)
        defaults.set(cycle.rest, forKey: restKey)
    }
}
