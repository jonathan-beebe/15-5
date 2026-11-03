#if os(macOS)
import AppKit
import SwiftUI

/// Running: the phase and time remaining. Idle: an icon.
struct MenuBarLabel: View {
    let timer: CycleTimer

    var body: some View {
        if let position = timer.position {
            let text = "\(position.phase.title) \(Cycle.clockText(seconds: position.secondsRemaining))"
            Image(nsImage: Self.image(of: text))
                .accessibilityLabel(text)
        } else {
            Image(systemName: "timer")
                .accessibilityLabel("15-5")
        }
    }

    /// MenuBarExtra ignores `.monospacedDigit()` on Text, so the item's width changes with the
    /// digits and shifts its neighbors. A template image keeps the digit widths fixed.
    private static func image(of text: String) -> NSImage {
        let font = NSFont.monospacedDigitSystemFont(
            ofSize: NSFont.menuBarFont(ofSize: 0).pointSize,
            weight: .regular
        )
        let string = NSAttributedString(string: text, attributes: [.font: font])
        let size = string.size()
        let image = NSImage(size: size, flipped: false) { rect in
            string.draw(in: rect)
            return true
        }
        image.isTemplate = true
        return image
    }
}

struct MenuBarMenu: View {
    let timer: CycleTimer

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if timer.isRunning {
            Button("Pause", action: timer.pause)
        } else {
            Button("Play", action: timer.play)
        }
        if timer.isActive {
            Button("Stop", action: timer.stop)
        }

        Button("Show Window") {
            openWindow(id: FifteenFiveApp.mainWindowID)
            NSApp.activate()
        }

        Divider()

        Button("Quit 15-5") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
#endif
