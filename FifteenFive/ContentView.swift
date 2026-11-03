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
                .foregroundStyle(timer.isRunning ? phase.tint : .secondary)

            Text(clockText)
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .accessibilityLabel(spokenTime)

            Button(action: toggle) {
                Text(timer.isRunning ? "Stop" : "Start")
                    .font(.title2.weight(.semibold))
                    .frame(minWidth: 140)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(timer.isRunning ? .red : .indigo)
            .keyboardShortcut(.space, modifiers: [])
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(timer.isRunning ? phase.tint.opacity(0.12) : .clear)
        .animation(.easeInOut(duration: 0.3), value: timer.position?.phase)
        #if os(iOS)
        .overlay {
            FlashOverlay(flashCount: timer.flashCount, tint: phase.tint)
        }
        #else
        .frame(minWidth: 340, minHeight: 320)
        #endif
    }

    private var clockText: String {
        String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }

    private var spokenTime: String {
        let duration = Duration.seconds(secondsRemaining)
        return duration.formatted(.units(allowed: [.minutes, .seconds], width: .wide)) + " remaining"
    }

    private func toggle() {
        if timer.isRunning {
            timer.stop()
        } else {
            timer.start()
        }
    }
}

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
