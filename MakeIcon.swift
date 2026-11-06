import AppKit
import Foundation

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        let background = NSBezierPath(roundedRect: NSRect(x: 60, y: 60, width: 904, height: 904), xRadius: 204, yRadius: 204)
        NSColor(calibratedRed: 0.04, green: 0.56, blue: 0.58, alpha: 1).setFill()
        background.fill()
        NSColor.white.withAlphaComponent(0.94).setFill()
        NSBezierPath(roundedRect: NSRect(x: 183, y: 285, width: 658, height: 415), xRadius: 60, yRadius: 60).fill()
        NSColor(calibratedRed: 0.04, green: 0.56, blue: 0.58, alpha: 1).setFill()
        for row in 0..<3 {
            for col in 0..<7 {
                NSBezierPath(roundedRect: NSRect(x: 232 + col * 83, y: 426 + row * 78, width: 60, height: 53), xRadius: 12, yRadius: 12).fill()
            }
        }
        NSBezierPath(roundedRect: NSRect(x: 341, y: 341, width: 342, height: 48), xRadius: 14, yRadius: 14).fill()
        // A pause badge makes the mark distinguishable from a generic keyboard icon.
        let badge = NSBezierPath(ovalIn: NSRect(x: 667, y: 631, width: 210, height: 210))
        NSColor.white.setStroke()
        badge.lineWidth = 18
        badge.stroke()
        NSColor(calibratedRed: 0.98, green: 0.81, blue: 0.39, alpha: 1).setFill()
        badge.fill()
        NSColor(calibratedRed: 0.05, green: 0.30, blue: 0.32, alpha: 1).setFill()
        for x in [728, 786] {
            NSBezierPath(roundedRect: NSRect(x: x, y: 685, width: 30, height: 103), xRadius: 10, yRadius: 10).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = URL(fileURLWithPath: destination).appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try rep.representation(using: .png, properties: [:])!.write(to: url)
    }
}
