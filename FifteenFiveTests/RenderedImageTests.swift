#if os(macOS)
import AppKit
import Testing
@testable import FifteenFive

@MainActor
struct RenderedImageTests {
    @Test func drawsIntoABitmapAtTheGivenScale() throws {
        let image = NSImage.rendered(size: NSSize(width: 10, height: 10), scale: 2) { rect in
            NSColor.red.setFill()
            rect.insetBy(dx: 2, dy: 2).fill()
        }
        let bitmap = try #require(image.representations.first as? NSBitmapImageRep)

        #expect(image.size == NSSize(width: 10, height: 10))
        #expect(bitmap.pixelsWide == 20)
        #expect(bitmap.pixelsHigh == 20)
        // Drawing scales with the bitmap: the 2 pt inset fill starts 4 pixels in.
        #expect(bitmap.colorAt(x: 10, y: 10)?.alphaComponent == 1)
        #expect(bitmap.colorAt(x: 3, y: 3)?.alphaComponent == 0)
        #expect(bitmap.colorAt(x: 5, y: 5)?.alphaComponent == 1)
    }
}
#endif
