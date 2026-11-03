#if os(macOS)
import SwiftUI

/// The main menu's Timer commands, so every action has a discoverable name and shortcut.
struct TimerCommands: Commands {
    let timer: CycleTimer

    var body: some Commands {
        CommandMenu("Timer") {
            if timer.isRunning {
                Button("Pause", action: timer.pause)
                    .keyboardShortcut("p")
            } else {
                Button("Play", action: timer.play)
                    .keyboardShortcut("p")
            }
            Button("Stop", action: timer.stop)
                .keyboardShortcut(".")
                .disabled(!timer.isActive)

            Divider()

            Button("Switch Phase", action: timer.flipSelectedPhase)
                .keyboardShortcut("t")
                .disabled(timer.isActive)
            Button("Add a Minute") { timer.adjustSelectedPhase(byMinutes: 1) }
                .keyboardShortcut(.upArrow)
                .disabled(timer.isActive)
            Button("Remove a Minute") { timer.adjustSelectedPhase(byMinutes: -1) }
                .keyboardShortcut(.downArrow)
                .disabled(timer.isActive)
        }
    }
}
#endif
