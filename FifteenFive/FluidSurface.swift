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

    var body: some View {
        GeometryReader { proxy in
            Rectangle()
                .colorEffect(ShaderLibrary.fluidWash(
                    .float2(proxy.size),
                    .float(time),
                    .color(phase.gradientColors[1]),
                    .color(phase.gradientColors[0]),
                    .color(phase.flowAccent),
                    .float(softness)
                ))
        }
    }
}
