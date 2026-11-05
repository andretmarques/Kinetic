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
            return edit(&state, .setPaused(!state.config.paused))
        case .toggleReverseScroll:
            return edit(&state, .setReverseVertical(mouse: mouse, !profile.scroll.reverseVertical))
        case .toggleAcceleration:
            let mode: AccelerationMode = profile.pointer.acceleration == .off ? .system : .off
            return edit(&state, .setAcceleration(mouse: mouse, mode))
        case .toggleFunctionKeys:
            let mode: FKeyMode = state.config.keyboard.fKeyMode == .mac ? .standard : .mac
            return edit(&state, .setFKeyMode(mode))
        case let .setPointerSpeed(speed):
            return edit(&state, .setPointerSpeed(mouse: mouse, speed))
        case .openSettings:
            return [.openSettings]
        case .quit:
            return [.quit]
        }
    }

    private static func edit(_ state: inout AgentState, _ edit: ConfigEdit) -> [AgentEffect] {
        edit.apply(to: &state.config)
        return [.persist(edit), apply(state, force: false), .renderMenu]
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
