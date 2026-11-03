import Foundation

struct LaunchOptions {
    var cycle = Cycle.standard
    var autostart = false
    /// Tests and demo runs keep the default, so they never overwrite the user's lengths.
    var saveCycle: (Cycle) -> Void = { _ in }

    /// Debug builds launched with `-demo` start on launch with a 6s/4s cycle.
    static var current: LaunchOptions {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-demo") {
            return LaunchOptions(cycle: Cycle(focus: 6, rest: 4), autostart: true)
        }
        #endif
        return LaunchOptions(
            cycle: SavedCycle.load(from: .standard) ?? .standard,
            saveCycle: { SavedCycle.save($0, to: .standard) }
        )
    }
}

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
