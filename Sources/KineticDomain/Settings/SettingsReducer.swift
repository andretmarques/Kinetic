public enum AgentRegistration: Equatable, Sendable {
    case enabled, requiresApproval, notRegistered, unavailable
}

public enum SettingsBanner: Equatable, Sendable {
    case turnedOff, needsLoginItemApproval, notRunning, needsPermissions
}

public enum AgentHealth: Equatable, Sendable {
    case notRunning, paused, active, needsPermission
}

/// Brings the agent back when macOS refuses to launch it, which it does for a newly updated
/// agent until the login item is registered again.
public struct AgentRecovery: Equatable, Sendable {
    public static let pollsBeforeRepair = 3
    public static let maxRegistrations = 4

    public var downPolls = 0
    public var registrations = 0
    public var isRepairing = false
    public var wasQuitByUser = false

    public init() {}
}

public struct SettingsState: Equatable, Sendable {
    public var config: KineticConfig
    public var status: AgentStatus
    public var agentRunning = false
    public var registration: AgentRegistration = .notRegistered
    public var recovery = AgentRecovery()
    public var selectedMouseKey = KineticConfig.allMiceKey
    public var isOnboardingPresented = false
    public var askedPermissions: Set<Permission> = []
    public var alertMessage: String?
    public var highlightedButton: Int?
    public var highlightGeneration = 0
    public var detectedButtons: Set<Int> = []
    public var shortcutNames: [String] = []

    public init(config: KineticConfig, status: AgentStatus) {
        self.config = config
        self.status = status
    }

    public var mouse: MouseProfile {
        config.mouseProfile(for: selectedMouseKey == KineticConfig.allMiceKey ? nil : selectedMouseKey)
    }

    public var externalMice: [DeviceInfo] {
        status.devices.filter { $0.kind == .mouse && config.isEnabled($0) }
    }

    public var externalKeyboards: [DeviceInfo] {
        status.devices.filter { $0.kind == .keyboard && config.isEnabled($0) }
    }

    public var savedMouseKeys: [String] {
        let connected = status.devices.filter { $0.kind == .mouse }.map(\.key)
        return config.mice.keys
            .filter { $0 != KineticConfig.allMiceKey && !connected.contains($0) }
            .sorted()
    }

    public var buttonRows: [Int] {
        var rows = Set(MouseButtons.standard)
        rows.formUnion(mouse.buttons.keys.compactMap(Int.init))
        rows.formUnion(detectedButtons.filter { $0 > 1 })
        return rows.sorted()
    }

    public var accessibilityGranted: Bool {
        agentRunning && status.accessibilityGranted
    }

    /// A running tap proves the agent can see input, because macOS also allows that through Accessibility.
    public var inputMonitoringGranted: Bool {
        agentRunning && (status.inputMonitoringGranted || status.eventTapActive)
    }

    /// Setup asks for these in order, and only once the agent is running to receive the request.
    public var nextPermissionToRequest: Permission? {
        guard agentRunning else { return nil }
        if !accessibilityGranted { return .accessibility }
        return inputMonitoringGranted ? nil : .inputMonitoring
    }

    public var isListening: Bool {
        agentRunning && status.eventTapActive
    }

    public var isAgentEnabled: Bool {
        config.agentEnabled
    }

    public var banner: SettingsBanner? {
        if !config.agentEnabled { return .turnedOff }
        if registration == .requiresApproval { return .needsLoginItemApproval }
        if !agentRunning { return .notRunning }
        if !isListening || !accessibilityGranted { return .needsPermissions }
        return nil
    }

    public var health: AgentHealth {
        if !agentRunning { return .notRunning }
        if config.paused { return .paused }
        return status.eventTapActive ? .active : .needsPermission
    }
}

public enum SettingsIntent: Sendable {
    case started
    case edit(ConfigEdit)
    case configLoaded(KineticConfig)
    case statusLoaded(AgentStatus)
    case agentObserved(isRunning: Bool, registration: AgentRegistration)
    case agentQuitByUser
    case repairFinished(didRegister: Bool)

    case selectMouse(String)
    case buttonsScreenAppeared
    case buttonsScreenDisappeared
    case buttonPressed(Int)
    case highlightExpired(generation: Int)

    case presentOnboarding
    case onboardingDismissed
    case finishOnboarding(OnboardingChoices)

    case setAgentEnabled(Bool)
    case restartAgent
    case openLoginItems
    case requestPermission(Permission)
    case askNextPermission
    case permissionsGranted
    case checkStatus
    case reapply

    case exportSettings
    case importSettings
    case imported(KineticConfig)
    case resetToDefaults
    case failed(String)
    case registrationFailed(String)
    case alertDismissed
    case shortcutNamesLoaded([String])
}

public enum SettingsEffect: Equatable, Sendable {
    case startObserving
    case ensureAgentRunning
    case persist(ConfigEdit)
    case setRegistered(Bool)
    case restartAgent
    case repairAgent(mayRelaunch: Bool, mayRegister: Bool)
    case openLoginItems
    case requestPermission(Permission)
    case bringAppForward
    case checkStatus
    case reapply
    case startLearning
    case stopLearning
    case clearHighlight(generation: Int)
    case exportSettings(KineticConfig)
    case importSettings
    case loadShortcutNames
}

public enum SettingsReducer: Reducer {
    public static func reduce(_ state: inout SettingsState, _ intent: SettingsIntent) -> [SettingsEffect] {
        switch intent {
        case .started:
            state.isOnboardingPresented = !state.config.onboardingDone
            return [.startObserving, .loadShortcutNames] + (state.config.agentEnabled ? [.ensureAgentRunning] : [])

        case let .edit(edit):
            return apply(edit, to: &state)

        case let .configLoaded(config):
            guard config != state.config else { return [] }
            state.config = config
            reconcileSelection(&state)
            return []

        case let .statusLoaded(status):
            guard status != state.status else { return [] }
            state.status = status
            reconcileSelection(&state)
            return []

        case let .agentObserved(isRunning, registration):
            state.agentRunning = isRunning
            state.registration = registration
            return recover(&state)

        case .agentQuitByUser:
            state.recovery.wasQuitByUser = true
            return []

        case let .repairFinished(didRegister):
            state.recovery.isRepairing = false
            state.recovery.downPolls = 0
            if didRegister {
                state.recovery.registrations += 1
            }
            return []

        case let .selectMouse(key):
            state.selectedMouseKey = key
            return []

        case .buttonsScreenAppeared:
            return [.startLearning]

        case .buttonsScreenDisappeared:
            return [.stopLearning]

        case let .buttonPressed(button):
            state.detectedButtons.insert(button)
            state.highlightedButton = button
            state.highlightGeneration += 1
            return [.clearHighlight(generation: state.highlightGeneration)]

        case let .highlightExpired(generation):
            if generation == state.highlightGeneration {
                state.highlightedButton = nil
            }
            return []

        case .presentOnboarding:
            state.isOnboardingPresented = true
            return []

        case .onboardingDismissed:
            state.isOnboardingPresented = false
            state.askedPermissions = []
            return []

        case let .finishOnboarding(choices):
            state.isOnboardingPresented = false
            state.askedPermissions = []
            // Choices only count on first run, so "Show setup again" can't overwrite later changes.
            return apply(.completeOnboarding(state.config.onboardingDone ? nil : choices), to: &state)

        case let .setAgentEnabled(isEnabled):
            state.recovery.wasQuitByUser = false
            return apply(.setAgentEnabled(isEnabled), to: &state) + [.setRegistered(isEnabled)]

        case .restartAgent:
            guard state.registration == .enabled else {
                return reduce(&state, .setAgentEnabled(true))
            }
            state.recovery.wasQuitByUser = false
            return [.restartAgent]

        case .openLoginItems:
            return [.openLoginItems]

        case let .requestPermission(permission):
            return [.requestPermission(permission)]

        case .askNextPermission:
            guard let next = state.nextPermissionToRequest, state.askedPermissions.insert(next).inserted else {
                return []
            }
            return [.requestPermission(next)]

        case .permissionsGranted:
            return state.askedPermissions.isEmpty ? [] : [.bringAppForward]

        case .checkStatus:
            return [.checkStatus]

        case .reapply:
            return [.reapply]

        case .exportSettings:
            return [.exportSettings(state.config)]

        case .importSettings:
            return [.importSettings]

        case let .imported(config):
            var imported = config
            imported.onboardingDone = true
            imported.agentEnabled = state.config.agentEnabled // this Mac's login item, not part of the file
            state.selectedMouseKey = KineticConfig.allMiceKey
            return apply(.replaceAll(imported), to: &state)

        case .resetToDefaults:
            return reduce(&state, .imported(KineticConfig()))

        case let .failed(message):
            state.alertMessage = message
            return []

        case let .registrationFailed(message):
            state.alertMessage = message
            // The switch follows the login item the handler just read; apply, not reduce, so no .setRegistered goes out.
            let isRegistered = state.registration == .enabled || state.registration == .requiresApproval
            guard isRegistered != state.config.agentEnabled else { return [] }
            return apply(.setAgentEnabled(isRegistered), to: &state)

        case .alertDismissed:
            state.alertMessage = nil
            return []

        case let .shortcutNamesLoaded(names):
            state.shortcutNames = names
            return []
        }
    }

    private static func apply(_ edit: ConfigEdit, to state: inout SettingsState) -> [SettingsEffect] {
        edit.apply(to: &state.config)
        reconcileSelection(&state)
        return [.persist(edit)]
    }

    private static func reconcileSelection(_ state: inout SettingsState) {
        let key = state.selectedMouseKey
        guard key != KineticConfig.allMiceKey else { return }
        let isSelectable = state.externalMice.contains { $0.key == key } || state.config.mice[key] != nil
        let isHidden = state.config.hiddenDevices.contains(key)
        if !isSelectable || isHidden {
            state.selectedMouseKey = KineticConfig.allMiceKey
        }
    }

    private static func recover(_ state: inout SettingsState) -> [SettingsEffect] {
        if state.agentRunning {
            state.recovery = AgentRecovery()
            return []
        }
        let isExpectedDown = !state.config.agentEnabled
            || state.registration != .enabled
            || state.recovery.wasQuitByUser
        guard !isExpectedDown else {
            state.recovery.downPolls = 0
            return []
        }

        state.recovery.downPolls += 1
        guard state.recovery.downPolls >= AgentRecovery.pollsBeforeRepair, !state.recovery.isRepairing else {
            return []
        }
        state.recovery.isRepairing = true
        return [
            .repairAgent(
                mayRelaunch: state.recovery.registrations >= 1,
                mayRegister: state.recovery.registrations < AgentRecovery.maxRegistrations
            ),
        ]
    }
}
