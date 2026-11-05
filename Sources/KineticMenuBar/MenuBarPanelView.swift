import AppKit
import KineticDomain

final class MenuBarPanelView: NSView {
    private enum Layout {
        static let padding: CGFloat = 16
        static let tileSize: CGFloat = 92
        static let gap: CGFloat = 10
        static let headerHeight: CGFloat = 20
        static let headerGap: CGFloat = 14
        static let columns = 3
        static let rows = 2
        static let sliderGap: CGFloat = 16
        static let sliderRowHeight: CGFloat = 46
        static let tilesTop = padding + headerHeight + headerGap
    }

    static let size = NSSize(
        width: Layout.padding * 2 + CGFloat(Layout.columns) * Layout.tileSize + CGFloat(Layout.columns - 1) * Layout.gap,
        height: Layout.tilesTop + CGFloat(Layout.rows) * Layout.tileSize + CGFloat(Layout.rows - 1) * Layout.gap
            + Layout.sliderGap + Layout.sliderRowHeight + Layout.padding
    )

    var onCommand: ((MenuBarCommand) -> Void)?
    var onClose: (() -> Void)?
    private(set) var tiles: [MenuBarTileButton] = []

    private let healthDot = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let devicesLabel = NSTextField(labelWithString: "")
    private let speedTitle = NSTextField(labelWithString: "Pointer Speed")
    private let speedValue = NSTextField(labelWithString: "")
    private let speedSlider = NSSlider(value: 10, minValue: 1, maxValue: 20, target: nil, action: nil)
    private var model: MenuBarModel?

    override var isFlipped: Bool { true }

    init() {
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        setUpHeader()
        setUpSpeedRow()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not used")
    }

    func render(_ model: MenuBarModel) {
        self.model = model
        statusLabel.stringValue = model.statusText
        devicesLabel.stringValue = model.devicesText
        healthDot.layer?.backgroundColor = model.health.color.cgColor

        if NSApp.currentEvent?.type != .leftMouseDragged {
            speedSlider.doubleValue = model.pointerSpeed
        }
        speedValue.stringValue = model.speedDescription(for: speedSlider.doubleValue)

        createMissingTiles(count: model.tiles.count)
        for (button, tile) in zip(tiles, model.tiles) {
            button.render(tile) { [weak self] in
                self?.onCommand?(tile.command)
                if tile.closesPanel {
                    self?.onClose?()
                }
            }
        }
    }

    private func setUpHeader() {
        healthDot.wantsLayer = true
        healthDot.layer?.cornerRadius = 4
        healthDot.frame = NSRect(x: Layout.padding, y: Layout.padding + 6, width: 8, height: 8)
        addSubview(healthDot)

        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.frame = NSRect(x: Layout.padding + 15, y: Layout.padding, width: 150, height: Layout.headerHeight)
        addSubview(statusLabel)

        let devicesX = Layout.padding + 165
        devicesLabel.font = .systemFont(ofSize: 11)
        devicesLabel.textColor = .secondaryLabelColor
        devicesLabel.alignment = .right
        devicesLabel.lineBreakMode = .byTruncatingHead
        devicesLabel.frame = NSRect(
            x: devicesX,
            y: Layout.padding + 2,
            width: Self.size.width - Layout.padding - devicesX,
            height: 16
        )
        addSubview(devicesLabel)
    }

    private func setUpSpeedRow() {
        let top = Self.size.height - Layout.padding - Layout.sliderRowHeight
        let width = Self.size.width - Layout.padding * 2

        speedTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        speedTitle.frame = NSRect(x: Layout.padding, y: top, width: 120, height: 17)
        addSubview(speedTitle)

        speedValue.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        speedValue.textColor = .secondaryLabelColor
        speedValue.alignment = .right
        speedValue.frame = NSRect(x: Layout.padding + 120, y: top + 1, width: width - 120, height: 16)
        addSubview(speedValue)

        addSymbol("tortoise", x: Layout.padding, y: top + 22)
        addSymbol("hare", x: Self.size.width - Layout.padding - 22, y: top + 22)

        speedSlider.numberOfTickMarks = 20
        speedSlider.allowsTickMarkValuesOnly = true
        speedSlider.tickMarkPosition = .below
        speedSlider.isContinuous = true
        speedSlider.target = self
        speedSlider.action = #selector(speedSliderMoved)
        speedSlider.setAccessibilityLabel("Pointer speed")
        speedSlider.frame = NSRect(x: Layout.padding + 28, y: top + 20, width: width - 56, height: 26)
        addSubview(speedSlider)
    }

    private func addSymbol(_ name: String, x: CGFloat, y: CGFloat) {
        let view = NSImageView()
        view.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        view.contentTintColor = .secondaryLabelColor
        view.frame = NSRect(x: x, y: y, width: 22, height: 22)
        addSubview(view)
    }

    private func createMissingTiles(count: Int) {
        while tiles.count < count {
            let index = tiles.count
            let tile = MenuBarTileButton()
            tile.frame = NSRect(
                x: Layout.padding + CGFloat(index % Layout.columns) * (Layout.tileSize + Layout.gap),
                y: Layout.tilesTop + CGFloat(index / Layout.columns) * (Layout.tileSize + Layout.gap),
                width: Layout.tileSize,
                height: Layout.tileSize
            )
            addSubview(tile)
            tiles.append(tile)
        }
    }

    @objc private func speedSliderMoved() {
        let speed = speedSlider.doubleValue.rounded()
        speedValue.stringValue = model?.speedDescription(for: speed) ?? ""

        let eventType = NSApp.currentEvent?.type
        let isDragging = eventType == .leftMouseDragged || eventType == .leftMouseDown
        if !isDragging && speed != model?.pointerSpeed {
            onCommand?(.setPointerSpeed(speed))
        }
    }
}

private extension MenuBarModel.Health {
    var color: NSColor {
        switch self {
        case .good: .systemGreen
        case .paused: .systemYellow
        case .problem: .systemOrange
        }
    }
}
