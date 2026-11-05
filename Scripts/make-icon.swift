// Usage: swift Scripts/make-icon.swift Branding/icon-a-tamed-curve.svg build/AppIcon.iconset
//
// macOS 26 puts any icon that isn't Apple's rounded square on a grey plate, so the artwork gets
// rendered without its own shape and cut to the standard grid: 824 of 1024, with a 185.4 corner radius.
import AppKit
import WebKit

let gridSide = 824.0
let cornerRadius = 185.4
let canvasSide = 1024.0

@MainActor
func renderArtwork(svg: String) async throws -> CGImage {
    let unclipped = svg.replacingOccurrences(of: #"clip-path="url(#squircle)""#, with: "")
    let side = Int(canvasSide)
    let view = WKWebView(frame: NSRect(x: 0, y: 0, width: side, height: side))
    let delegate = LoadDelegate()
    view.navigationDelegate = delegate
    await withCheckedContinuation { continuation in
        delegate.onFinish = { continuation.resume() }
        view.loadHTMLString("<!doctype html><style>html,body{margin:0;overflow:hidden}svg{display:block}</style>\(unclipped)", baseURL: nil)
    }
    let configuration = WKSnapshotConfiguration()
    configuration.rect = NSRect(x: 0, y: 0, width: side, height: side)
    configuration.snapshotWidth = NSNumber(value: side)
    let snapshot = try await view.takeSnapshot(configuration: configuration)
    return snapshot.cgImage(forProposedRect: nil, context: nil, hints: nil)!
}

final class LoadDelegate: NSObject, WKNavigationDelegate {
    var onFinish: (() -> Void)?
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { onFinish?() }
}

func render(artwork: CGImage, pixels: Int) -> Data {
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

    let scale = Double(pixels) / canvasSide
    let side = gridSide * scale
    let inset = (Double(pixels) - side) / 2
    let shape = NSRect(x: inset, y: inset, width: side, height: side)
    NSBezierPath(roundedRect: shape, xRadius: cornerRadius * scale, yRadius: cornerRadius * scale).addClip()
    NSImage(cgImage: artwork, size: .zero).draw(in: shape)

    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}

let sizes = [
    ("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64), ("128x128", 128),
    ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512), ("512x512", 512), ("512x512@2x", 1024),
]

_ = NSApplication.shared
Task { @MainActor in
    do {
        let svg = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        let output = URL(fileURLWithPath: CommandLine.arguments[2])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let artwork = try await renderArtwork(svg: svg)
        for (name, pixels) in sizes {
            try render(artwork: artwork, pixels: pixels).write(to: output.appendingPathComponent("icon_\(name).png"))
        }
        exit(EXIT_SUCCESS)
    } catch {
        FileHandle.standardError.write(Data("make-icon failed: \(error)\n".utf8))
        exit(EXIT_FAILURE)
    }
}
RunLoop.main.run()
