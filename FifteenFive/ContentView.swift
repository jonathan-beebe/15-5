import SwiftUI

struct ContentView: View {
    let timer: CycleTimer

    private var phase: Phase { timer.position?.phase ?? .focus }
    private var secondsRemaining: Int {
        timer.position?.secondsRemaining ?? Int(timer.cycle.focus)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(phase.title)
                .font(.title.weight(.semibold))
                .foregroundStyle(titleColor)

            Text(Cycle.clockText(seconds: secondsRemaining))
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(clockColor)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .accessibilityLabel(spokenTime)

            HStack(spacing: 12) {
                control("Play", systemImage: "play.fill", action: timer.play)
                    .disabled(timer.isRunning)
                    .keyboardShortcut(.space, modifiers: [])
                control("Pause", systemImage: "pause.fill", action: timer.pause)
                    .disabled(!timer.isRunning)
                    .keyboardShortcut(.space, modifiers: [])
                control("Stop", systemImage: "stop.fill", action: timer.stop)
                    .disabled(!timer.isActive)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            #if os(macOS)
            if timer.isActive {
                // A new identity per phase crossfades the colors, which shader arguments can't animate.
                FlowingBackground(phase: phase, timer: timer)
                    .id(phase)
                    // Extends under the hidden title bar.
                    .ignoresSafeArea()
            }
            #else
            if timer.isActive {
                phase.tint.opacity(0.12)
                    .ignoresSafeArea()
            }
            #endif
        }
        .animation(.easeInOut(duration: 0.3), value: timer.position?.phase)
        #if os(iOS)
        .overlay {
            FlashOverlay(flashCount: timer.flashCount, tint: phase.tint)
        }
        #else
        .frame(minWidth: 340, minHeight: 320)
        #endif
    }

    private func control(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title2)
                .frame(width: 56)
                .padding(.vertical, 6)
                // Keeps the whole area clickable with no background.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(clockColor)
        .help(title)
    }

    private var titleColor: Color {
        guard timer.isActive else { return .secondary }
        #if os(macOS)
        return .white.opacity(0.85)
        #else
        return phase.tint
        #endif
    }

    private var clockColor: Color {
        #if os(macOS)
        // The full-color background stays dark in Light mode too.
        return timer.isActive ? .white : .primary
        #else
        return .primary
        #endif
    }

    private var spokenTime: String {
        let duration = Duration.seconds(secondsRemaining)
        return duration.formatted(.units(allowed: [.minutes, .seconds], width: .wide)) + " remaining"
    }
}

#if os(macOS)
/// The screen wash's gradient, at full color.
private struct FlowingBackground: View {
    let phase: Phase
    let timer: CycleTimer

    @State private var seed = Double.random(in: 0 ..< 50)

    var body: some View {
        TimelineView(.animation(minimumInterval: FluidSurface.frameInterval, paused: timer.isPaused)) { context in
            FluidSurface(
                phase: phase,
                time: seed + flowElapsed(at: context.date) * FluidSurface.flowRate,
                softness: 0.5
            )
        }
        .accessibilityHidden(true)
    }

    /// Follows the timer, so the flow holds during a pause and continues without a jump. Wrapping
    /// each cycle keeps shader time small for float precision, and the wrap lands on a crossfade.
    private func flowElapsed(at date: Date) -> TimeInterval {
        let cycle = timer.cycle
        return timer.elapsed(at: date).truncatingRemainder(dividingBy: cycle.focus + cycle.rest)
    }
}
#endif

#if os(iOS)
private struct FlashOverlay: View {
    let flashCount: Int
    let tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity = 0.0

    var body: some View {
        tint
            .opacity(opacity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task(id: flashCount) {
                guard flashCount > 0 else { return }
                let pulses = reduceMotion ? 1 : FlashTiming.pulses
                let halfPeriod = reduceMotion ? FlashTiming.reducedHalfPeriod : FlashTiming.halfPeriod
                for _ in 0 ..< pulses {
                    withAnimation(.linear(duration: halfPeriod)) { opacity = FlashTiming.peakOpacity }
                    try? await Task.sleep(for: .seconds(halfPeriod))
                    withAnimation(.linear(duration: halfPeriod)) { opacity = 0 }
                    try? await Task.sleep(for: .seconds(halfPeriod))
                }
            }
    }
}
#endif
