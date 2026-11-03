#if os(macOS)
import AppKit

/// Replaces the Dock icon with the phase gradient, name, and time remaining while the timer runs.
@MainActor
enum DockIcon {
    /// macOS icon grid: the tile is 824/1024 of the canvas with a 22.37% corner radius.
    private static let canvasSize = 1024.0
    private static let tileInset = 100.0
    private static let cornerRadiusRatio = 0.2237
    /// Focus matches the app icon gradient in scripts/make-icon.swift.
    private static let focusGradient = NSGradient(
        starting: NSColor(srgbRed: 0.40, green: 0.36, blue: 0.95, alpha: 1),
        ending: NSColor(srgbRed: 0.22, green: 0.17, blue: 0.70, alpha: 1)
    )!
    private static let restGradient = NSGradient(
        starting: NSColor(srgbRed: 0.16, green: 0.62, blue: 0.34, alpha: 1),
        ending: NSColor(srgbRed: 0.06, green: 0.42, blue: 0.22, alpha: 1)
    )!

    /// macOS adds the rim highlight to bundle icons only, so a runtime image has to draw its own.
    private static let rimWidth = 10.0
    private static let rimGradient = NSGradient(
        colors: [
            NSColor(white: 1, alpha: 0.45),
            NSColor(white: 1, alpha: 0),
            NSColor(white: 1, alpha: 0),
            NSColor(white: 1, alpha: 0.3),
        ],
        atLocations: [0, 0.2, 0.8, 1],
        colorSpace: .sRGB
    )!

    /// Passing nil restores the app's bundle icon.
    static func show(_ position: CyclePosition?) {
        NSApplication.shared.applicationIconImage = position.map(image(of:))
    }

    private static func image(of position: CyclePosition) -> NSImage {
        let gradient = position.phase == .focus ? focusGradient : restGradient
        let title = line(position.phase.title, size: 170, weight: .semibold)
        let clock = line(Cycle.clockText(seconds: position.secondsRemaining), size: 250, weight: .heavy)

        return NSImage(size: NSSize(width: canvasSize, height: canvasSize), flipped: false) { canvas in
            let tile = canvas.insetBy(dx: tileInset, dy: tileInset)
            let radius = tile.width * cornerRadiusRatio
            gradient.draw(in: NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius), angle: -90)
            rimGradient.draw(in: rim(of: tile, cornerRadius: radius), angle: -90)
            draw(title, centeredAt: NSPoint(x: tile.midX, y: tile.midY + 130))
            draw(clock, centeredAt: NSPoint(x: tile.midX, y: tile.midY - 90))
            return true
        }
    }

    private static func rim(of tile: NSRect, cornerRadius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath(roundedRect: tile, xRadius: cornerRadius, yRadius: cornerRadius)
        let innerRadius = cornerRadius - rimWidth
        path.append(NSBezierPath(
            roundedRect: tile.insetBy(dx: rimWidth, dy: rimWidth),
            xRadius: innerRadius,
            yRadius: innerRadius
        ))
        path.windingRule = .evenOdd
        return path
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
