import Foundation

public enum MenuBarCommand: Codable, Equatable, Sendable {
    case togglePause
    case toggleReverseScroll
    case toggleAcceleration
    case toggleFunctionKeys
    case setPointerSpeed(Double)
    case openSettings
    case quit
}

public struct MenuBarModel: Codable, Equatable, Sendable {
    public enum Health: Codable, Sendable {
        case good, paused, problem
    }

    public struct Tile: Codable, Equatable, Sendable {
        public let symbol: String
        public let title: String
        public let detail: String
        public let isOn: Bool
        public let command: MenuBarCommand
        public let closesPanel: Bool
    }

    public let health: Health
    public let statusText: String
    public let devicesText: String
    public let tiles: [Tile]
    public let pointerSpeed: Double
    public let showsGain: Bool

    public init(state: AgentState) {
        let config = state.config
        let profile = config.mouseProfile(for: state.activeMouseKey)
        let accelerationIsOff = profile.pointer.acceleration == .off
        let macKeys = config.keyboard.fKeyMode == .mac

        if config.paused {
            health = .paused
            statusText = "Kinetic is paused"
        } else if state.tapActive {
            health = .good
            statusText = "Kinetic is active"
        } else {
            health = .problem
            statusText = "Needs permissions"
        }

        let mice = state.devices.filter { $0.kind == .mouse && config.isEnabled($0) }.count
        let keyboards = state.devices.filter { $0.kind == .keyboard && config.isEnabled($0) }.count
        devicesText = "\(mice) \(mice == 1 ? "mouse" : "mice") · \(keyboards) \(keyboards == 1 ? "keyboard" : "keyboards")"

        pointerSpeed = profile.pointer.speed
        showsGain = accelerationIsOff
        tiles = [
            Tile(
                symbol: config.paused ? "play.fill" : "pause.fill",
                title: "Kinetic",
                detail: config.paused ? "Paused" : "On",
                isOn: !config.paused,
                command: .togglePause,
                closesPanel: false
            ),
            Tile(
                symbol: "arrow.up.arrow.down",
                title: "Reverse Scroll",
                detail: profile.scroll.reverseVertical ? "On" : "Off",
                isOn: profile.scroll.reverseVertical,
                command: .toggleReverseScroll,
                closesPanel: false
            ),
            Tile(
                symbol: "cursorarrow.motionlines",
                title: "Acceleration",
                detail: accelerationIsOff ? "Off" : "On",
                isOn: !accelerationIsOff,
                command: .toggleAcceleration,
                closesPanel: false
            ),
            Tile(
                symbol: "keyboard",
                title: "F-Keys",
                detail: state.fnLocked ? "Flipped" : (macKeys ? "Mac actions" : "Standard"),
                isOn: macKeys,
                command: .toggleFunctionKeys,
                closesPanel: false
            ),
            Tile(
                symbol: "gearshape",
                title: "Settings",
                detail: "Open Kinetic",
                isOn: false,
                command: .openSettings,
                closesPanel: true
            ),
            Tile(
                symbol: "power",
                title: "Quit Agent",
                detail: "Stops Kinetic",
                isOn: false,
                command: .quit,
                closesPanel: true
            ),
        ]
    }

    public func speedDescription(for speed: Double) -> String {
        guard showsGain else { return String(format: "%.0f", speed) }
        return String(format: "%.0f  ·  %.2f×", speed, PointerMath.linearGain(speed: speed))
    }
}
