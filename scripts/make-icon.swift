#!/usr/bin/env swift
// Generates FifteenFive/Assets.xcassets/AppIcon.appiconset. Run from the repo root.
import AppKit

let output = URL(fileURLWithPath: "FifteenFive/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let top = NSColor(srgbRed: 0.40, green: 0.36, blue: 0.95, alpha: 1)
let bottom = NSColor(srgbRed: 0.22, green: 0.17, blue: 0.70, alpha: 1)

func drawTile(in rect: NSRect) {
    NSGradient(starting: top, ending: bottom)!.draw(in: rect, angle: -90)
    let base = NSFont.systemFont(ofSize: rect.width * 0.60, weight: .heavy)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: base.pointSize) } ?? base
    let text = NSAttributedString(string: "15", attributes: [.font: font, .foregroundColor: NSColor.white, .kern: -rect.width * 0.015])
    let line = CTLineCreateWithAttributedString(text)
    let glyphs = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    let context = NSGraphicsContext.current!.cgContext
    context.textPosition = CGPoint(x: rect.midX - glyphs.midX, y: rect.midY - glyphs.midY)
    CTLineDraw(line, context)
}

func writePNG(_ name: String, pixels: Int, opaque: Bool, draw: (NSRect) -> Void) throws {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: (opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast).rawValue
    )!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    draw(NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.current = nil
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
}

// iOS applies its own mask, so the tile is opaque and full-bleed.
try writePNG("ios-1024.png", pixels: 1024, opaque: true, draw: drawTile)

// macOS icons carry their own rounded tile: 824/1024 of the canvas with a 22.37% corner radius.
var images: [String] = [#"{"filename":"ios-1024.png","idiom":"universal","platform":"ios","size":"1024x1024"}"#]
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "mac-\(pixels).png"
        try writePNG(name, pixels: pixels, opaque: false) { canvas in
            let tile = canvas.insetBy(dx: canvas.width * 100 / 1024, dy: canvas.width * 100 / 1024)
            NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.2237, yRadius: tile.width * 0.2237).addClip()
            drawTile(in: tile)
        }
        images.append(#"{"filename":"\#(name)","idiom":"mac","scale":"\#(scale)x","size":"\#(points)x\#(points)"}"#)
    }
}

let contents = #"{"images":[\#(images.joined(separator: ","))],"info":{"author":"xcode","version":1}}"#
try Data(contents.utf8).write(to: output.appendingPathComponent("Contents.json"))
