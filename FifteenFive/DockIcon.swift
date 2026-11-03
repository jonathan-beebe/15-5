#if os(macOS)
import AppKit
import SwiftUI

/// Replaces the Dock icon with the phase color, name, and time remaining while the timer runs.
@MainActor
enum DockIcon {
    /// macOS icon grid: the tile is 824/1024 of the canvas with a 22.37% corner radius.
    private static let canvasSize = 1024.0
    private static let tileInset = 100.0
    private static let cornerRadiusRatio = 0.2237
    /// Darkens the tint so white text stays legible on green.
    private static let tileShadowLevel = 0.3

    /// Passing nil restores the app's bundle icon.
    static func show(_ position: CyclePosition?) {
        NSApplication.shared.applicationIconImage = position.map(image(of:))
    }

    private static func image(of position: CyclePosition) -> NSImage {
        let tint = NSColor(position.phase.tint).usingColorSpace(.sRGB)
        let fill = tint?.shadow(withLevel: tileShadowLevel) ?? .darkGray
        let title = line(position.phase.title, size: 170, weight: .semibold)
        let clock = line(Cycle.clockText(seconds: position.secondsRemaining), size: 250, weight: .heavy)

        return NSImage(size: NSSize(width: canvasSize, height: canvasSize), flipped: false) { canvas in
            let tile = canvas.insetBy(dx: tileInset, dy: tileInset)
            let radius = tile.width * cornerRadiusRatio
            fill.setFill()
            NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius).fill()
            draw(title, centeredAt: NSPoint(x: tile.midX, y: tile.midY + 130))
            draw(clock, centeredAt: NSPoint(x: tile.midX, y: tile.midY - 90))
            return true
        }
    }

    private static func line(_ text: String, size: CGFloat, weight: NSFont.Weight) -> NSAttributedString {
        let base = NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.white])
    }

    private static func draw(_ text: NSAttributedString, centeredAt center: NSPoint) {
        let size = text.size()
        text.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
    }
}
#endif
