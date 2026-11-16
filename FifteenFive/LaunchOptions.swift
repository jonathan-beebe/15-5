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
            cycle: SessionStore.shared.cycle,
            saveCycle: { SessionStore.shared.save($0) }
        )
    }
}
