#if DEBUG && os(macOS)
import AppKit
import SwiftUI

struct DeveloperCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    private static let f12 = KeyEquivalent(Character(UnicodeScalar(UInt32(NSF12FunctionKey))!))

    var body: some Commands {
        CommandMenu("Developer") {
            Button("Developer Menu") {
                openWindow(id: DeveloperMenu.windowID)
            }
            .keyboardShortcut(Self.f12, modifiers: [])
        }
    }
}

struct DeveloperMenu: View {
    static let windowID = "developer"

    let timer: CycleTimer

    var body: some View {
        Button("Skip to Zero", action: timer.advanceToPhaseEnd)
            .disabled(!timer.isRunning)
            .padding(24)
    }
}
#endif
