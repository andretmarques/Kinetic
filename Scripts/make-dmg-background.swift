// Usage: swift Scripts/make-dmg-background.swift Packaging/dmg-background.tiff
//
// Finder draws icon labels in black or white depending on light or dark mode, and a DMG can't choose.
// The blue stays in the mid-tones so both stay readable on it.
import AppKit

let size = CGSize(width: 640, height: 400)

func render(scale: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width) * scale,
        pixelsHigh: Int(size.height) * scale,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = size

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    drawBackground()
    drawArrow()
    drawTitle()
    NSGraphicsContext.restoreGraphicsState()

    return bitmap.representation(using: .png, properties: [:])!
}

func drawBackground() {
    let rect = NSRect(origin: .zero, size: size)
    NSGradient(
        starting: NSColor(srgbRed: 0.27, green: 0.42, blue: 0.82, alpha: 1),
        ending: NSColor(srgbRed: 0.37, green: 0.54, blue: 0.93, alpha: 1)
    )!.draw(in: rect, angle: 90)
    NSGradient(
        starting: NSColor(white: 1, alpha: 0.14),
        ending: NSColor(white: 1, alpha: 0)
    )!.draw(in: rect, relativeCenterPosition: NSPoint(x: 0, y: 0.5))
}

/// The brand's tamed curve, settling into the arrowhead. Icons sit at y=200 from the top, so y=215 from the bottom here.
func drawArrow() {
    let curve = NSBezierPath()
    curve.move(to: NSPoint(x: 248, y: 188))
    curve.curve(to: NSPoint(x: 322, y: 232), controlPoint1: NSPoint(x: 284, y: 188), controlPoint2: NSPoint(x: 288, y: 232))
    curve.curve(to: NSPoint(x: 392, y: 212), controlPoint1: NSPoint(x: 352, y: 232), controlPoint2: NSPoint(x: 362, y: 212))
    curve.lineWidth = 7
    curve.lineCapStyle = .round

    let head = NSBezierPath()
    head.move(to: NSPoint(x: 376, y: 232))
    head.line(to: NSPoint(x: 396, y: 212))
    head.line(to: NSPoint(x: 376, y: 192))
    head.lineWidth = 7
    head.lineCapStyle = .round
    head.lineJoinStyle = .round

    let glow = NSShadow()
    glow.shadowColor = NSColor(srgbRed: 0.1, green: 0.18, blue: 0.5, alpha: 0.45)
    glow.shadowBlurRadius = 10
    glow.shadowOffset = NSSize(width: 0, height: -2)
    glow.set()

    NSColor.white.setStroke()
    curve.stroke()
    head.stroke()
    NSShadow().set()
}

func drawTitle() {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: paragraph,
    ]
    NSAttributedString(string: "Drag Kinetic to Applications", attributes: attributes)
        .draw(in: NSRect(x: 0, y: size.height - 76, width: size.width, height: 34))
}

let output = CommandLine.arguments[1]
let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }

let standard = directory.appendingPathComponent("background.png")
let retina = directory.appendingPathComponent("background@2x.png")
try render(scale: 1).write(to: standard)
try render(scale: 2).write(to: retina)

let combine = Process()
combine.executableURL = URL(fileURLWithPath: "/usr/bin/tiffutil")
combine.arguments = ["-cathidpicheck", standard.path, retina.path, "-out", output]
try combine.run()
combine.waitUntilExit()
exit(combine.terminationStatus)
