#if os(macOS)
import AppKit
import SwiftUI

/// Washes every display in a flowing phase-colored gradient, over all apps and Spaces, using
/// click-through windows. One slow pulse stays under the WCAG 2.3.1 limit of 3 flashes per second.
@MainActor
enum ScreenFlash {
    private static var windows: [NSWindow] = []
    private static var dismissal: Task<Void, Never>?

    static func play(entering phase: Phase) {
        cancel()
        let content = FluidGradient(
            phase: phase,
            start: .now,
            flows: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        windows = NSScreen.screens.map { makeWindow(on: $0, content: content) }
        windows.forEach { $0.orderFrontRegardless() }

        dismissal = Task {
            try? await Task.sleep(for: .seconds(FlashEnvelope.duration))
            guard !Task.isCancelled else { return }
            cancel()
        }
    }

    /// Takes the wash down at once. Stop calls this so the wash ends with the chime.
    static func cancel() {
        dismissal?.cancel()
        dismissal = nil
        windows.forEach { $0.orderOut(nil) }
        windows = []
    }

    private static func makeWindow(on screen: NSScreen, content: FluidGradient) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.hasShadow = false
        window.backgroundColor = .clear
        window.contentView = NSHostingView(rootView: content)
        return window
    }
}

/// Opacity over time: ease in, dip once and return, ease out. Without pulsing, the dip is skipped.
enum FlashEnvelope {
    static let duration = 3.8
    static let peakOpacity = 0.85
    static let dipStart = 1.0
    static let dipDuration = 1.0
    /// Share of the peak removed at the bottom of the dip.
    static let dipDepth = 0.65
    private static let fadeIn = 0.7
    private static let fadeOut = 0.9

    static func opacity(at elapsed: TimeInterval, pulsing: Bool) -> Double {
        let rising = smoothstep(elapsed / fadeIn)
        let falling = smoothstep((duration - elapsed) / fadeOut)
        return peakOpacity * min(rising, falling) * (pulsing ? dip(at: elapsed) : 1)
    }

    /// A single raised-cosine cycle: 1 outside the dip, `1 - dipDepth` at its midpoint.
    private static func dip(at elapsed: TimeInterval) -> Double {
        let progress = (elapsed - dipStart) / dipDuration
        guard (0 ... 1).contains(progress) else { return 1 }
        return 1 - dipDepth * (0.5 - 0.5 * cos(2 * .pi * progress))
    }

    private static func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}

private struct FluidGradient: View {
    let phase: Phase
    let start: Date
    let flows: Bool

    /// Starts each wash at a different place in the pattern.
    private let seed = Double.random(in: 0 ..< 50)

    var body: some View {
        TimelineView(.animation(minimumInterval: FluidSurface.frameInterval)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            FluidSurface(phase: phase, time: seed + (flows ? elapsed * FluidSurface.flowRate : 0))
                .opacity(FlashEnvelope.opacity(at: elapsed, pulsing: flows))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
#endif
