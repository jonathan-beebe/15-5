#if os(macOS)
import AppKit
import SwiftUI

/// Replaces the Dock icon with the phase gradient, name, and time remaining while the timer runs.
/// While stopped, it shows the focus length, or the bundle icon at the standard length.
@MainActor
enum DockIcon {
    /// macOS icon grid: the tile is 824/1024 of the canvas with a 22.37% corner radius.
    private static let canvasSize = 1024.0
    private static let tileInset = 100.0
    private static let cornerRadiusRatio = 0.2237
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
    // NSGradient returns nil only for an empty color list. Every list here has at least two colors.
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

    /// nil shows the app's bundle icon.
    private static var current: NSImage?

    /// AppKit resets the icon as it finishes launching, which would drop one set before that.
    private static let reapplyAfterLaunch: Void = {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { _ in
            // The observer is queued on main, so this runs on the main actor.
            MainActor.assumeIsolated { apply() }
        }
    }()

    static func show(_ position: CyclePosition?, cycle: Cycle) {
        _ = reapplyAfterLaunch
        if let position {
            current = image(of: position, cycle: cycle)
        } else if cycle.focus == Cycle.standard.focus {
            current = nil
        } else {
            current = idleImage(focusMinutes: Int((cycle.focus / 60).rounded()))
        }
        apply()
    }

    private static func apply() {
        NSApplication.shared.applicationIconImage = current
    }

    /// Matches the layout of the bundle icon in scripts/make-icon.swift.
    private static func idleImage(focusMinutes: Int) -> NSImage {
        // Phase.gradientColors always has two colors, so NSGradient cannot return nil.
        let gradient = NSGradient(colors: Phase.focus.gradientColors.map { NSColor($0) })!
        return NSImage.rendered(size: NSSize(width: canvasSize, height: canvasSize)) { canvas in
            let tile = canvas.insetBy(dx: tileInset, dy: tileInset)
            let radius = tile.width * cornerRadiusRatio
            gradient.draw(in: NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius), angle: -90)
            rimGradient.draw(in: rim(of: tile, cornerRadius: radius), angle: -90)
            drawCentered("\(focusMinutes)", in: tile)
        }
    }

    private static func drawCentered(_ text: String, in tile: NSRect) {
        let base = NSFont.systemFont(ofSize: tile.width * 0.60, weight: .heavy)
        let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: base.pointSize) } ?? base
        let string = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor.white,
            .kern: -tile.width * 0.015,
            .shadow: textShadow,
        ])
        let line = CTLineCreateWithAttributedString(string)
        let glyphs = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.textPosition = CGPoint(x: tile.midX - glyphs.midX, y: tile.midY - glyphs.midY)
        CTLineDraw(line, context)
    }

    private static func image(of position: CyclePosition, cycle: Cycle) -> NSImage {
        let elapsed = cycle.fractionElapsed(of: position)
        // Phase.gradientColors always has two colors, so NSGradient cannot return nil.
        let gradient = NSGradient(colors: position.phase.gradientColors.map { NSColor($0) })!
        let title = line(position.phase.title, size: 170, weight: .semibold)
        let clock = line(Cycle.clockText(seconds: position.secondsRemaining), size: 250, weight: .heavy)

        return NSImage.rendered(size: NSSize(width: canvasSize, height: canvasSize)) { canvas in
            let tile = canvas.insetBy(dx: tileInset, dy: tileInset)
            let radius = tile.width * cornerRadiusRatio
            gradient.draw(in: NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius), angle: -90)
            drawRemainingOverlay(elapsed: elapsed, in: tile, cornerRadius: radius)
            rimGradient.draw(in: rim(of: tile, cornerRadius: radius), angle: -90)
            draw(title, centeredAt: NSPoint(x: tile.midX, y: tile.midY + 130))
            draw(clock, centeredAt: NSPoint(x: tile.midX, y: tile.midY - 90))
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
