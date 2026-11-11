public struct AgentState: Equatable, Sendable {
    public var config: KineticConfig
    public var devices: [DeviceInfo] = []
    public var accessibilityGranted = false
    public var inputMonitoringGranted = false
    public var tapActive = false
    public var fnLocked = false
    public var publishedStatus: AgentStatus?

    public init(config: KineticConfig) {
        self.config = config
    }

    public var status: AgentStatus {
        AgentStatus(
            eventTapActive: tapActive,
            accessibilityGranted: accessibilityGranted,
            inputMonitoringGranted: inputMonitoringGranted,
            devices: devices,
            fnLocked: fnLocked
        )
    }

    public var inputRules: InputRules {
        InputRules(config: config, devices: devices)
    }

    public var activeMouseKey: String {
        config.activeMouseProfileKey(devices: devices)
    }

    /// Pointer settings apply per mouse, so with several mice a menu change also reaches each connected one with its own profile.
    public var pointerMouseKeys: [String] {
        guard activeMouseKey == KineticConfig.allMiceKey else { return [activeMouseKey] }
        let profiled = devices.filter { $0.kind == .mouse && config.isEnabled($0) && config.mice[$0.key] != nil }
        return [KineticConfig.allMiceKey] + profiled.map(\.key)
    }
}

public enum AgentIntent: Sendable {
    case started
    case configLoaded(KineticConfig)
    case devicesChanged([DeviceInfo])
    case reapplyRequested
    case statusObserved(accessibility: Bool, inputMonitoring: Bool, tapActive: Bool, fnLocked: Bool)
    case permissionRequested(Permission)
    case appRemoved
    case menu(MenuBarCommand)
}

public enum AgentEffect: Equatable, Sendable {
    case applySettings(KineticConfig, keyboards: [DeviceInfo], rules: InputRules, force: Bool)
    case scheduleReapply
    case publish(AgentStatus)
    case persist(ConfigEdit)
    case renderMenu
    case requestPermission(Permission)
    case openSettings
    case relaunch
    case stop
    case quit
}

public enum AgentReducer: Reducer {
    public static func reduce(_ state: inout AgentState, _ intent: AgentIntent) -> [AgentEffect] {
        switch intent {
        case .started:
            return [apply(state, force: true), .renderMenu]

        case let .configLoaded(config):
            guard config != state.config else { return [] }
            let iconChanged = config.showMenuBarIcon != state.config.showMenuBarIcon
            state.config = config
            guard !iconChanged else { return [.relaunch] }
            return [apply(state, force: false), .renderMenu]

        case let .devicesChanged(devices):
            guard devices != state.devices else { return [] }
            state.devices = devices
            return [apply(state, force: false), .scheduleReapply, .renderMenu] + publishIfChanged(&state)

        case .reapplyRequested:
            return [apply(state, force: true)]

        case let .statusObserved(accessibility, inputMonitoring, tapActive, fnLocked):
            state.accessibilityGranted = accessibility
            state.inputMonitoringGranted = inputMonitoring
            let menuChanged = state.tapActive != tapActive || state.fnLocked != fnLocked
            state.tapActive = tapActive
            state.fnLocked = fnLocked
            return (menuChanged ? [.renderMenu] : []) + publishIfChanged(&state)

        case let .permissionRequested(permission):
            return [.requestPermission(permission)]

        case .appRemoved:
            return [.stop]

        case let .menu(command):
            return handleMenu(command, state: &state)
        }
    }

    private static func handleMenu(_ command: MenuBarCommand, state: inout AgentState) -> [AgentEffect] {
        let mouse = state.activeMouseKey
        let profile = state.config.mouseProfile(for: mouse)

        switch command {
        case .togglePause:
            return edit(&state, [.setPaused(!state.config.paused)])
        case .toggleReverseScroll:
            return edit(&state, [.setReverseVertical(mouse: mouse, !profile.scroll.reverseVertical)])
        case .toggleAcceleration:
            let turnsOn = profile.pointer.acceleration == .off
            return edit(&state, state.pointerMouseKeys.map { key in
                .setAcceleration(mouse: key, turnsOn ? onMode(state.config.mouseProfile(for: key).pointer) : .off)
            })
        case .toggleFunctionKeys:
            let mode: FKeyMode = state.config.keyboard.fKeyMode == .mac ? .standard : .mac
            return edit(&state, [.setFKeyMode(mode)])
        case let .setPointerSpeed(speed):
            return edit(&state, state.pointerMouseKeys.map { .setPointerSpeed(mouse: $0, speed) })
        case .openSettings:
            return [.openSettings]
        case .quit:
            return [.quit]
        }
    }

    private static func edit(_ state: inout AgentState, _ edits: [ConfigEdit]) -> [AgentEffect] {
        edits.forEach { $0.apply(to: &state.config) }
        return edits.map(AgentEffect.persist) + [apply(state, force: false), .renderMenu]
    }

    /// The config doesn't keep the mode from before "off", but the curve only moves in Custom mode.
    // shortcut: a macOS-mode profile whose curve was moved comes back as Custom, and a Custom profile at the default curve comes back as macOS; store the last mode if users notice.
    private static func onMode(_ pointer: PointerSettings) -> AccelerationMode {
        guard pointer.acceleration == .off else { return pointer.acceleration }
        return pointer.curve == PointerSettings().curve ? .system : .custom
    }

    private static func apply(_ state: AgentState, force: Bool) -> AgentEffect {
        let keyboards = state.devices.filter { $0.kind == .keyboard && state.config.isEnabled($0) }
        return .applySettings(state.config, keyboards: keyboards, rules: state.inputRules, force: force)
    }

    private static func publishIfChanged(_ state: inout AgentState) -> [AgentEffect] {
        let status = state.status
        guard status != state.publishedStatus else { return [] }
        state.publishedStatus = status
        return [.publish(status)]
    }
}
