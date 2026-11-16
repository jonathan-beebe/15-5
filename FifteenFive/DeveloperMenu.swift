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

/// Shows the screen glow's gradient flowing at full opacity, with no fades, chime, or timer.
/// "Edges" shows it confined to the band the glow uses, over a clear middle.
struct GradientPreview: View {
    static let windowID = "gradient-preview"

    @State private var phase = Phase.focus
    @State private var edgesOnly = false
    @State private var start = Date.now

    var body: some View {
        TimelineView(.animation(minimumInterval: FluidSurface.frameInterval)) { context in
            FluidSurface(
                phase: phase,
                time: context.date.timeIntervalSince(start) * FluidSurface.flowRate,
                glowShare: edgesOnly ? ScreenFlash.glowShare : nil
            )
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 16) {
                Picker("Phase", selection: $phase) {
                    Text(Phase.focus.title).tag(Phase.focus)
                    Text(Phase.rest.title).tag(Phase.rest)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Toggle("Edges", isOn: $edgesOnly)
            }
            .padding(12)
        }
    }
}
#endif
