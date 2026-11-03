#if os(macOS)
import AppKit
import SwiftUI

/// Flashes every display, over all apps and Spaces, using click-through windows.
@MainActor
enum ScreenFlash {
    static func play(entering phase: Phase) {
        let windows = NSScreen.screens.map { makeWindow(on: $0, color: NSColor(phase.tint)) }
        windows.forEach { $0.orderFrontRegardless() }

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let pulses = reduceMotion ? 1 : FlashTiming.pulses
        let halfPeriod = reduceMotion ? FlashTiming.reducedHalfPeriod : FlashTiming.halfPeriod

        Task {
            for _ in 0 ..< pulses {
                windows.forEach { $0.alphaValue = FlashTiming.peakOpacity }
                try? await Task.sleep(for: .seconds(halfPeriod))
                windows.forEach { $0.alphaValue = 0 }
                try? await Task.sleep(for: .seconds(halfPeriod))
            }
            windows.forEach { $0.orderOut(nil) }
        }
    }

    private static func makeWindow(on screen: NSScreen, color: NSColor) -> NSWindow {
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.animationBehavior = .none
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isOpaque = false
        window.hasShadow = false
        window.backgroundColor = color
        window.alphaValue = 0
        return window
    }
}
#endif
