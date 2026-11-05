// Usage: swift Scripts/make-icon.swift Branding/kinetic-icon-1024.png build/AppIcon.iconset
import AppKit

let artwork = NSImage(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))!
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2])
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

// Apple's icon grid puts the shape at 824 of 1024, so the icon sits level with others in the Dock.
let artworkScale = 824.0 / 1024.0

func render(pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.current?.imageInterpolation = .high

    let side = CGFloat(pixels) * artworkScale
    let inset = (CGFloat(pixels) - side) / 2
    artwork.draw(in: NSRect(x: inset, y: inset, width: side, height: side))

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

let sizes = [
    ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
    ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024),
]
for (name, pixels) in sizes {
    try render(pixels: pixels).write(to: outputDirectory.appendingPathComponent("icon_\(name).png"))
}
