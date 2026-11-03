#if os(macOS)
import AppKit

extension NSImage {
    /// Draws once, now, into a bitmap. The drawing-handler initializer runs its closure on whatever
    /// thread later draws the image, and a closure formed on the main actor traps off it.
    @MainActor
    static func rendered(size: NSSize, scale: CGFloat = 1, draw: (NSRect) -> Void) -> NSImage {
        // The initializer returns nil only for an unsupported format. 8-bit RGBA is always supported.
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        // The context draws in points and maps them onto the pixels, so this sets the scale.
        bitmap.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        draw(NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }
}
#endif
