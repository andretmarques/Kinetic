import AppKit
import KineticDomain

final class MenuBarTileButton: NSButton {
    private let glass = NSGlassEffectView()
    private let content = FlippedView()
    private let icon = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let detailLabel = NSTextField(labelWithString: "")
    private var isOn = false
    private var onPress: () -> Void = {}
    private var isHovering = false {
        didSet { updateTint() }
    }

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: .zero)
        title = ""
        isBordered = false
        target = self
        action = #selector(pressed)

        glass.cornerRadius = 18
        glass.contentView = content
        addSubview(glass)

        icon.symbolConfiguration = .init(pointSize: 20, weight: .medium)
        icon.imageAlignment = .alignCenter
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        detailLabel.font = .systemFont(ofSize: 10)
        for label in [titleLabel, detailLabel] {
            label.alignment = .center
            label.lineBreakMode = .byTruncatingTail
        }
        [icon, titleLabel, detailLabel].forEach(content.addSubview)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not used")
    }

    func render(_ tile: MenuBarModel.Tile, onPress: @escaping () -> Void) {
        isOn = tile.isOn
        self.onPress = onPress
        setAccessibilityLabel("\(tile.title): \(tile.detail)")

        icon.image = NSImage(systemSymbolName: tile.symbol, accessibilityDescription: nil)
        icon.contentTintColor = isOn ? .white : .labelColor
        titleLabel.stringValue = tile.title
        titleLabel.textColor = isOn ? .white : .labelColor
        detailLabel.stringValue = tile.detail
        detailLabel.textColor = isOn ? NSColor.white.withAlphaComponent(0.85) : .secondaryLabelColor
        updateTint()
    }

    override func layout() {
        super.layout()
        glass.frame = bounds
        content.frame = bounds

        let inset: CGFloat = 2
        let width = bounds.width - inset * 2
        let contentHeight: CGFloat = 62
        let top = (bounds.height - contentHeight) / 2
        icon.frame = NSRect(x: inset, y: top, width: width, height: 26)
        titleLabel.frame = NSRect(x: inset, y: top + 33, width: width, height: 15)
        detailLabel.frame = NSRect(x: inset, y: top + 48, width: width, height: 14)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
    }

    private func updateTint() {
        if isOn {
            glass.tintColor = NSColor.controlAccentColor.withAlphaComponent(isHovering ? 0.65 : 0.8)
        } else {
            glass.tintColor = isHovering ? NSColor.labelColor.withAlphaComponent(0.1) : nil
        }
    }

    @objc private func pressed() {
        onPress()
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
