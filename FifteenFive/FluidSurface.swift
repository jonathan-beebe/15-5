import SwiftUI

/// One frame of the flowing pattern at a point in shader time.
struct FluidSurface: View {
    /// Shader time per second. Lower is slower.
    static let flowRate = 0.09
    /// The flow is slow enough that 30 fps looks smooth, at half the GPU work of 60.
    static let frameInterval = 1.0 / 30

    let phase: Phase
    let time: Double
    /// From 0 for the full color range to 1 for a flat average color.
    var softness = 0.0
    /// Confines the pattern to a band this wide along the edges, as a share of the shorter side.
    /// Nil fills the whole surface.
    var glowShare: Double?

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .colorEffect(shader(size: proxy.size))
        }
    }

    private func shader(size: CGSize) -> Shader {
        let wash = ShaderLibrary.fluidWash(
            .float2(size),
            .float(time),
            .color(phase.gradientColors[1]),
            .color(phase.gradientColors[0]),
            .color(phase.flowAccent),
            .float(softness)
        )
        guard let glowShare else { return wash }
        return ShaderLibrary.fluidGlow(
            .float2(size),
            .float(time),
            .color(phase.gradientColors[1]),
            .color(phase.gradientColors[0]),
            .color(phase.flowAccent),
            .float(softness),
            .float(min(size.width, size.height) * glowShare)
        )
    }
}

/// The app's default texture: still grain over the system background.
struct GrainBackground: View {
    var body: some View {
        ZStack {
            #if os(iOS)
            // The default iOS background is pure black or white, which hides half the grain or more.
            Color(uiColor: .secondarySystemBackground)
            #endif
            Rectangle()
                .colorEffect(ShaderLibrary.grainOverlay())
        }
        .accessibilityHidden(true)
    }
}
