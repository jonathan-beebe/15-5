import SwiftUI

struct ContentView: View {
    private static let fadeDuration = 0.3
    private static let space = KeyboardShortcut(.space, modifiers: [])
    #if os(iOS)
    // A constant from UIKit, so it always parses.
    private static let notificationSettings = URL(string: UIApplication.openNotificationSettingsURLString)!
    #endif

    let timer: CycleTimer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    #if os(iOS)
    /// True once the background has fully covered the window, so its color change stays hidden.
    @State private var isBackgroundCovering = false
    #endif

    private var phase: Phase { timer.position?.phase ?? timer.selectedPhase }
    private var secondsRemaining: Int {
        timer.position?.secondsRemaining ?? Int(timer.cycle.duration(of: phase))
    }

    var body: some View {
        VStack(spacing: 24) {
            // A plain label while active, so it neither dims nor reads as a button that does nothing.
            if timer.isActive {
                title
            } else {
                Button(action: timer.flipSelectedPhase) {
                    title.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Switches between Focus and Break")
            }

            Text(Cycle.clockText(seconds: secondsRemaining))
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(clockColor)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText(value: Double(secondsRemaining)))
                .animation(reduceMotion ? nil : .snappy, value: secondsRemaining)
                .sensoryFeedback(.selection, trigger: selectedDuration)
                .adjustsMinutes(isEnabled: !timer.isActive, onChange: timer.adjustSelectedPhase)
                .accessibilityRepresentation { clockAccessibility }

            HStack(spacing: 12) {
                // Space belongs to whichever of Play and Pause is enabled. Two controls with the
                // same shortcut leave the choice to SwiftUI, which is undefined for disabled ones.
                control("Play", systemImage: "play.fill", action: timer.play)
                    .disabled(timer.isRunning)
                    .keyboardShortcut(timer.isRunning ? nil : Self.space)
                control("Pause", systemImage: "pause.fill", action: timer.pause)
                    .disabled(!timer.isRunning)
                    .keyboardShortcut(timer.isRunning ? Self.space : nil)
                control("Stop", systemImage: "stop.fill", action: timer.stop)
                    .disabled(!timer.isActive)
            }

            #if os(iOS)
            if timer.isActive && timer.notificationsDenied {
                VStack(spacing: 4) {
                    Text("Notifications are off, so alerts stay silent while the app is in the background.")
                    Link("Open Settings", destination: Self.notificationSettings)
                }
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(titleColor)
                .tint(clockColor)
            }
            #endif
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            GrainBackground()
                .ignoresSafeArea()
                .allowsHitTesting(false)
            if timer.isActive {
                // A new identity per phase crossfades the colors, which shader arguments can't animate.
                FlowingBackground(phase: phase, timer: timer)
                    .id(phase)
                    // Extends under the hidden title bar.
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            #if os(macOS)
            WindowDragArea()
                .ignoresSafeArea()
            #endif
        }
        .animation(.easeInOut(duration: Self.fadeDuration), value: timer.position?.phase)
        #if os(iOS)
        // Light status bar text over the full-color background. Switching to dark changes the window
        // color at once, so it waits for the fade in. Switching back happens at once on stop, while
        // the background still covers the window.
        .preferredColorScheme(timer.isActive && isBackgroundCovering ? .dark : nil)
        .task(id: timer.isActive) {
            guard timer.isActive else {
                isBackgroundCovering = false
                return
            }
            try? await Task.sleep(for: .seconds(Self.fadeDuration))
            if !Task.isCancelled {
                isBackgroundCovering = true
            }
        }
        .overlay {
            FlashOverlay(flashCount: timer.flashCount, tint: phase.tint)
        }
        #else
        .frame(minWidth: 340, minHeight: 320)
        #endif
    }

    private var title: some View {
        Text(phase.title)
            .font(.title.weight(.semibold))
            .foregroundStyle(titleColor)
    }

    /// Stopped, the clock is the selected phase's length and VoiceOver can adjust it. Active, it
    /// is the time remaining, read-only, and changing on its own while running.
    @ViewBuilder private var clockAccessibility: some View {
        if timer.isActive {
            Text(spokenTime)
                .accessibilityLabel(phase.title)
                .accessibilityValue(spokenTime + " remaining")
                .accessibilityAddTraits(timer.isRunning ? .updatesFrequently : [])
        } else {
            Text(spokenTime)
                .accessibilityLabel("\(phase.title) length")
                .accessibilityValue(spokenTime)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: timer.adjustSelectedPhase(byMinutes: 1)
                    case .decrement: timer.adjustSelectedPhase(byMinutes: -1)
                    @unknown default: break
                    }
                }
        }
    }

    private var selectedDuration: TimeInterval {
        timer.cycle.duration(of: timer.selectedPhase)
    }

    private func control(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title2)
                // At least the HIG's 44 pt minimum target, on both platforms.
                .frame(width: 56)
                .frame(minHeight: 44)
                // Keeps the whole area clickable with no background.
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(clockColor)
        .help(title)
    }

    private var titleColor: Color {
        // Full white: at 85% the title fell under 3:1 on the brightest parts of the Break surface.
        timer.isActive ? .white : .secondary
    }

    private var clockColor: Color {
        // The full-color background stays dark in Light mode too.
        timer.isActive ? .white : .primary
    }

    private var spokenTime: String {
        Duration.seconds(secondsRemaining).formatted(.units(allowed: [.minutes, .seconds], width: .wide))
    }
}

#if os(macOS)
/// Moves the window when a drag starts here. The window's `isMovableByWindowBackground` setting
/// had no effect over this SwiftUI content, so this handles the drag directly.
private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowDragView()
    }

    func updateNSView(_ view: NSView, context: Context) {}
}

class WindowDragView: NSView {
    /// Lets the first click on an inactive window start a drag.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }
}
#endif

/// The screen wash's gradient, at full color.
private struct FlowingBackground: View {
    let phase: Phase
    let timer: CycleTimer

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var seed = Double.random(in: 0 ..< 50)

    var body: some View {
        TimelineView(.animation(minimumInterval: FluidSurface.frameInterval, paused: timer.isPaused || reduceMotion)) { context in
            FluidSurface(
                phase: phase,
                time: seed + flowElapsed * FluidSurface.flowRate,
                // Increase Contrast flattens the surface toward its average color.
                softness: contrast == .increased ? 0.8 : 0.5
            )
        }
        .accessibilityHidden(true)
    }

    /// Follows the timer, so the flow holds during a pause and continues without a jump. Wrapping
    /// each cycle keeps shader time small for float precision, and the wrap lands on a crossfade.
    private var flowElapsed: TimeInterval {
        let cycle = timer.cycle
        return timer.elapsed().truncatingRemainder(dividingBy: cycle.focus + cycle.rest)
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
