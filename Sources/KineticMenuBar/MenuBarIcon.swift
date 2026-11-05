import AppKit

/// The menu bar version of the logo, from Branding/menubar-glyph.svg. macOS tints template images to suit the bar.
enum MenuBarIcon {
    private static let artworkSide: CGFloat = 36
    private static let displaySide: CGFloat = 18

    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: displaySide, height: displaySide), flipped: true) { _ in
            let scale = displaySide / artworkSide
            NSGraphicsContext.current?.cgContext.scaleBy(x: scale, y: scale)

            let curve = NSBezierPath()
            curve.move(to: NSPoint(x: 5, y: 27))
            curve.curve(to: NSPoint(x: 18, y: 10), controlPoint1: NSPoint(x: 11, y: 27), controlPoint2: NSPoint(x: 12, y: 10))
            curve.curve(to: NSPoint(x: 31, y: 10), controlPoint1: NSPoint(x: 24, y: 10), controlPoint2: NSPoint(x: 25, y: 17))
            curve.lineWidth = 3.2
            curve.lineCapStyle = .round

            NSColor.black.set()
            curve.stroke()
            NSBezierPath(ovalIn: NSRect(x: 27.8, y: 6.8, width: 6.4, height: 6.4)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Kinetic"
        return image
    }
}
