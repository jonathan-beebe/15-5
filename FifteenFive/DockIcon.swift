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

    /// A light frost, so the uncovered gradient reads as the full-color state. A dark overlay reads
    /// the other way around: the brighter uncovered area looks like a layer growing over the icon.
    private static let remainingOverlay = NSColor(white: 1, alpha: 0.25)
    /// Keeps the white text legible on the frost.
    private static let textShadow: NSShadow = {
        let shadow = NSShadow()
        shadow.shadowColor = NSColor(white: 0, alpha: 0.45)
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.shadowBlurRadius = 14
        return shadow
    }()

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
    static func show(_ position: CyclePosition?, cycle: Cycle) {
        NSApplication.shared.applicationIconImage = position.map { image(of: $0, cycle: cycle) }
    }

    private static func image(of position: CyclePosition, cycle: Cycle) -> NSImage {
        let elapsed = cycle.fractionElapsed(of: position)
        let gradient = position.phase == .focus ? focusGradient : restGradient
        let title = line(position.phase.title, size: 170, weight: .semibold)
        let clock = line(Cycle.clockText(seconds: position.secondsRemaining), size: 250, weight: .heavy)

        return NSImage(size: NSSize(width: canvasSize, height: canvasSize), flipped: false) { canvas in
            let tile = canvas.insetBy(dx: tileInset, dy: tileInset)
            let radius = tile.width * cornerRadiusRatio
            gradient.draw(in: NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius), angle: -90)
            drawRemainingOverlay(elapsed: elapsed, in: tile, cornerRadius: radius)
            rimGradient.draw(in: rim(of: tile, cornerRadius: radius), angle: -90)
            draw(title, centeredAt: NSPoint(x: tile.midX, y: tile.midY + 130))
            draw(clock, centeredAt: NSPoint(x: tile.midX, y: tile.midY - 90))
            return true
        }
    }

    /// Covers the tile, then uncovers it clockwise from 12 o'clock as the phase elapses, so the
    /// remaining share stays dimmed and the elapsed share shows the full gradient.
    private static func drawRemainingOverlay(elapsed: Double, in tile: NSRect, cornerRadius: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: tile, xRadius: cornerRadius, yRadius: cornerRadius).addClip()
        remainingOverlay.setFill()
        if elapsed > 0 {
            remainingWedge(elapsed: elapsed, in: tile).fill()
        } else {
            // An arc whose start and end angles coincide draws nothing.
            tile.fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func remainingWedge(elapsed: Double, in tile: NSRect) -> NSBezierPath {
        let center = NSPoint(x: tile.midX, y: tile.midY)
        let wedge = NSBezierPath()
        wedge.move(to: center)
        wedge.appendArc(
            withCenter: center,
            // Reaches the tile's corners, so the clip sets the wedge's outer edge.
            radius: hypot(tile.width, tile.height) / 2,
            startAngle: 90 - 360 * elapsed,
            endAngle: 90 - 360,
            clockwise: true
        )
        wedge.close()
        return wedge
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
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor.white,
            .shadow: textShadow,
        ])
    }

    private static func draw(_ text: NSAttributedString, centeredAt center: NSPoint) {
        let size = text.size()
        text.draw(at: NSPoint(x: center.x - size.width / 2, y: center.y - size.height / 2))
    }
}
#endif
