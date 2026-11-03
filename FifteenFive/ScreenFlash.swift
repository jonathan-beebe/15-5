#if os(macOS)
import AppKit
import SwiftUI

/// Washes every display in a flowing phase-colored gradient, over all apps and Spaces, using
/// click-through windows. One slow pulse stays under the WCAG 2.3.1 limit of 3 flashes per second.
@MainActor
enum ScreenFlash {
    static func play(entering phase: Phase) {
        let content = FluidGradient(
            phase: phase,
            start: .now,
            flows: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        let windows = NSScreen.screens.map { makeWindow(on: $0, content: content) }
        windows.forEach { $0.orderFrontRegardless() }

        Task {
            try? await Task.sleep(for: .seconds(FlashEnvelope.duration))
            windows.forEach { $0.orderOut(nil) }
        }
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

    /// Each blob traces its own path, and the differing rates keep the pattern from repeating.
    private struct Blob {
        let color: Color
        let xRate, yRate, xOffset, yOffset: Double
    }

    private var blobs: [Blob] {
        let colors = phase.gradientColors
        return [
            Blob(color: phase.tint, xRate: 1.1, yRate: 1.5, xOffset: 0, yOffset: 1.2),
            Blob(color: colors[0], xRate: 1.4, yRate: 0.9, xOffset: 2.1, yOffset: 0.3),
            Blob(color: colors[1], xRate: 0.8, yRate: 1.3, xOffset: 4.2, yOffset: 3.4),
            Blob(color: .white.opacity(0.35), xRate: 1.7, yRate: 1.1, xOffset: 5.3, yOffset: 5.0),
        ]
    }

    var body: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(start)
            Canvas { graphics, size in
                draw(in: &graphics, size: size, time: flows ? elapsed : 0)
            }
            .drawingGroup()
            .opacity(FlashEnvelope.opacity(at: elapsed, pulsing: flows))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func draw(in graphics: inout GraphicsContext, size: CGSize, time: Double) {
        let bounds = CGRect(origin: .zero, size: size)
        graphics.fill(Path(bounds), with: .linearGradient(
            Gradient(colors: phase.gradientColors),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height)
        ))

        let radius = max(size.width, size.height) * 0.6
        for blob in blobs {
            let center = CGPoint(
                x: size.width * (0.5 + 0.4 * sin(time * blob.xRate + blob.xOffset)),
                y: size.height * (0.5 + 0.4 * sin(time * blob.yRate + blob.yOffset))
            )
            graphics.fill(Path(bounds), with: .radialGradient(
                Gradient(colors: [blob.color, blob.color.opacity(0)]),
                center: center,
                startRadius: 0,
                endRadius: radius
            ))
        }
    }
}
#endif
