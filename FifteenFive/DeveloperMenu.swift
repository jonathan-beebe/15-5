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

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 12) {
            Button("Skip to Zero", action: timer.advanceToPhaseEnd)
                .disabled(!timer.isRunning)
            Button("Preview Gradient") {
                openWindow(id: GradientPreview.windowID)
            }
        }
        .padding(24)
    }
}

/// Shows the screen wash's gradient flowing at full opacity, with no fades, chime, or timer.
struct GradientPreview: View {
    static let windowID = "gradient-preview"

    @State private var phase = Phase.focus
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation(minimumInterval: FluidSurface.frameInterval)) { context in
            FluidSurface(
                phase: phase,
                time: context.date.timeIntervalSince(start) * FluidSurface.flowRate
            )
        }
        .safeAreaInset(edge: .bottom) {
            Picker("Phase", selection: $phase) {
                Text(Phase.focus.title).tag(Phase.focus)
                Text(Phase.rest.title).tag(Phase.rest)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(12)
        }
    }
}
#endif
