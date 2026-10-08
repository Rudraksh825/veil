// Renders the Veil app icon (a stack of translucent frames with a play glyph)
// into an .iconset folder. Usage: make-icon <output.iconset>
import AppKit

let outputDir = CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset"
try FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

func render(pixels: Int) -> Data {
    let s = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("bitmap") }
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true

    // Body: macOS icon grid leaves ~10% margin for the shadow.
    let inset = s * 0.09
    let body = NSRect(x: inset, y: inset + s * 0.01, width: s - inset * 2, height: s - inset * 2)
    let corner = body.width * 0.225
    let shape = NSBezierPath(roundedRect: body, xRadius: corner, yRadius: corner)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = s * 0.025
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [
        NSColor(srgbRed: 0.11, green: 0.09, blue: 0.30, alpha: 1),
        NSColor(srgbRed: 0.36, green: 0.23, blue: 0.82, alpha: 1),
    ])!.draw(in: body, angle: 90)

    let glowCenter = NSPoint(x: body.midX - body.width * 0.28, y: body.maxY - body.height * 0.12)
    NSGradient(colorsAndLocations:
        (NSColor(srgbRed: 0.70, green: 0.60, blue: 1.0, alpha: 0.55), 0),
        (NSColor(srgbRed: 0.70, green: 0.60, blue: 1.0, alpha: 0.0), 1)
    )!.draw(fromCenter: glowCenter, radius: 0, toCenter: glowCenter, radius: body.width * 0.85, options: [])

    func frame(_ rect: NSRect, alpha: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.09, yRadius: rect.width * 0.09)
        NSColor.white.withAlphaComponent(alpha).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(min(alpha + 0.18, 1)).setStroke()
        path.lineWidth = max(1, s * 0.007)
        path.stroke()
    }

    let fw = body.width * 0.52
    let fh = fw * 0.66
    let step = body.width * 0.05
    let front = NSRect(x: body.midX - fw / 2 + step * 0.9, y: body.midY - fh / 2 - step * 0.9, width: fw, height: fh)
    frame(front.offsetBy(dx: -step * 2, dy: step * 2), alpha: 0.10)
    frame(front.offsetBy(dx: -step, dy: step), alpha: 0.15)
    frame(front, alpha: 0.22)

    let triangle = NSBezierPath()
    let th = fh * 0.46
    let tw = th * 0.92
    let cx = front.midX + tw * 0.08
    let cy = front.midY
    triangle.move(to: NSPoint(x: cx - tw / 2, y: cy - th / 2))
    triangle.line(to: NSPoint(x: cx - tw / 2, y: cy + th / 2))
    triangle.line(to: NSPoint(x: cx + tw / 2, y: cy))
    triangle.close()
    triangle.lineJoinStyle = .round
    triangle.lineWidth = max(1, s * 0.02)
    NSColor.white.withAlphaComponent(0.94).setFill()
    NSColor.white.withAlphaComponent(0.94).setStroke()
    triangle.fill()
    triangle.stroke()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
    return png
}

for entry in entries {
    let url = URL(fileURLWithPath: outputDir).appendingPathComponent("\(entry.name).png")
    try render(pixels: entry.pixels).write(to: url)
}
print("Wrote \(entries.count) icon sizes to \(outputDir)")
