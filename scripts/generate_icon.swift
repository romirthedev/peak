#!/usr/bin/env swift
import AppKit
import CoreGraphics

func generateIcon(pixelSize: Int) -> Data {
    let s = CGFloat(pixelSize)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    let gctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = gctx
    let ctx = gctx.cgContext

    let rect = CGRect(x: 0, y: 0, width: s, height: s)

    // Rounded rect background
    let cr = s * 0.22
    let bgPath = CGPath(roundedRect: rect, cornerWidth: cr, cornerHeight: cr, transform: nil)
    ctx.addPath(bgPath)
    ctx.clip()

    // Solid peach gradient fill
    let cs = CGColorSpaceCreateDeviceRGB()
    let gradColors = [
        CGColor(red: 1.0, green: 0.92, blue: 0.84, alpha: 1.0),
        CGColor(red: 0.98, green: 0.80, blue: 0.66, alpha: 1.0),
    ] as CFArray
    if let grad = CGGradient(colorsSpace: cs, colors: gradColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: s/2, y: s), end: CGPoint(x: s/2, y: 0), options: [])
    }

    // Draw the brain SF Symbol
    let fontSize = s * 0.45
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .thin)
    if let symbol = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {

        let symbolSize = symbol.size

        // Create a tinted version
        let tinted = NSImage(size: symbolSize)
        tinted.lockFocus()

        // Draw the symbol
        symbol.draw(in: NSRect(origin: .zero, size: symbolSize),
                     from: .zero, operation: .sourceOver, fraction: 1.0)

        // Tint it with the accent color
        NSColor(red: 0.55, green: 0.25, blue: 0.12, alpha: 0.9).set()
        NSRect(origin: .zero, size: symbolSize).fill(using: .sourceAtop)

        tinted.unlockFocus()

        // Center it
        let x = (s - symbolSize.width) / 2
        let y = (s - symbolSize.height) / 2

        tinted.draw(in: NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height),
                      from: .zero, operation: .sourceOver, fraction: 1.0)
    }

    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

// Sizes needed
let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

let dir = "Peak/Assets.xcassets/AppIcon.appiconset"

print("Generating icons...")
for e in entries {
    let data = generateIcon(pixelSize: e.pixels)
    let path = "\(dir)/\(e.name)"
    try! data.write(to: URL(fileURLWithPath: path))
    print("  \(e.name) (\(e.pixels)px)")
}
print("Done!")
