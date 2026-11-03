import SwiftUI

/// Converts a stream of gesture deltas into whole steps, carrying the remainder between deltas.
struct StepAccumulator {
    private var remainder = 0.0

    mutating func add(_ delta: Double, stepSize: Double) -> Int {
        remainder += delta
        let steps = Int((remainder / stepSize).rounded(.towardZero))
        remainder -= Double(steps) * stepSize
        return steps
    }

    mutating func reset() {
        remainder = 0
    }
}

/// Distance of a continuous drag or trackpad swipe per minute.
private let pointsPerMinute = 28.0

extension View {
    /// Up adds minutes and down removes them: a finger drag on iOS, a scroll on macOS.
    func adjustsMinutes(isEnabled: Bool, onChange: @escaping (Int) -> Void) -> some View {
        modifier(AdjustsMinutes(isEnabled: isEnabled, onChange: onChange))
    }
}

private struct AdjustsMinutes: ViewModifier {
    let isEnabled: Bool
    let onChange: (Int) -> Void

    #if os(iOS)
    @State private var accumulator = StepAccumulator()
    @State private var lastTranslation = 0.0

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    // Screen coordinates grow downward, so an upward drag is a positive delta.
                    let delta = lastTranslation - value.translation.height
                    lastTranslation = value.translation.height
                    let steps = accumulator.add(delta, stepSize: pointsPerMinute)
                    if steps != 0 { onChange(steps) }
                }
                .onEnded { _ in
                    lastTranslation = 0
                    accumulator.reset()
                },
            including: isEnabled ? .all : .none
        )
    }
    #else
    func body(content: Content) -> some View {
        content.overlay {
            if isEnabled {
                ScrollCatcher(onChange: onChange)
            }
        }
    }
    #endif
}

#if os(macOS)
private struct ScrollCatcher: NSViewRepresentable {
    let onChange: (Int) -> Void

    func makeNSView(context: Context) -> ScrollCatcherView {
        ScrollCatcherView()
    }

    func updateNSView(_ view: ScrollCatcherView, context: Context) {
        view.onChange = onChange
    }
}

private final class ScrollCatcherView: NSView {
    var onChange: ((Int) -> Void)?
    private var accumulator = StepAccumulator()

    override func scrollWheel(with event: NSEvent) {
        // Momentum continues after the fingers lift, which would overshoot the chosen value.
        guard event.momentumPhase.isEmpty else { return }
        if event.phase == .began { accumulator.reset() }

        // The sign flips with the Natural Scrolling setting. Undoing that makes a physical upward
        // gesture add minutes under either setting.
        let upward = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
        // A trackpad reports points. A mouse wheel reports notches, and each notch is a minute.
        let stepSize = event.hasPreciseScrollingDeltas ? pointsPerMinute : 1
        let steps = accumulator.add(upward, stepSize: stepSize)
        if steps != 0 { onChange?(steps) }
    }
}
#endif
