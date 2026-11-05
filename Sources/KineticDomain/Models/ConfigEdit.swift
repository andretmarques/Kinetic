/// One change to the config. Edits are small and independent, so the settings app and the agent
/// can each apply theirs to the latest file on disk without overwriting the other's.
public enum ConfigEdit: Equatable, Sendable {
    case setPointerSpeed(mouse: String, Double)
    case setAcceleration(mouse: String, AccelerationMode)
    case setCurve(mouse: String, Double)
    case resetPointer(mouse: String)
    case setReverseVertical(mouse: String, Bool)
    case setReverseHorizontal(mouse: String, Bool)
    case setLinesPerNotch(mouse: String, Int?)
    case setButtonAction(mouse: String, button: Int, KineticAction?)
    case removeMouseProfile(String)
    case setSwapAltWin(keyboard: String, Bool)
    case setMacFunctionKeys(keyboard: String, Bool)
    case setFKeyMode(FKeyMode)
    case setFnSubstitute(FnSubstitute)
    case setFKeyOverride(key: Int, KineticAction?)
    case setPaused(Bool)
    case setShowMenuBarIcon(Bool)
    case setAgentEnabled(Bool)
    case setDeviceHidden(key: String, Bool)
    case completeOnboarding(OnboardingChoices?)
    case replaceAll(KineticConfig)

    public func apply(to config: inout KineticConfig) {
        switch self {
        case let .setPointerSpeed(mouse, speed):
            config.editMouse(mouse) { $0.pointer.speed = speed }
        case let .setAcceleration(mouse, mode):
            config.editMouse(mouse) { $0.pointer.acceleration = mode }
        case let .setCurve(mouse, curve):
            config.editMouse(mouse) { $0.pointer.curve = curve }
        case let .resetPointer(mouse):
            config.editMouse(mouse) { $0.pointer = PointerSettings() }
        case let .setReverseVertical(mouse, isOn):
            config.editMouse(mouse) { $0.scroll.reverseVertical = isOn }
        case let .setReverseHorizontal(mouse, isOn):
            config.editMouse(mouse) { $0.scroll.reverseHorizontal = isOn }
        case let .setLinesPerNotch(mouse, lines):
            config.editMouse(mouse) { $0.scroll.linesPerNotch = lines }
        case let .setButtonAction(mouse, button, action):
            config.editMouse(mouse) { $0.buttons[String(button)] = action }
        case let .removeMouseProfile(key):
            config.mice.removeValue(forKey: key)
        case let .setSwapAltWin(keyboard, isOn):
            config.keyboards[keyboard, default: KeyboardDeviceSettings()].swapAltWin = isOn
        case let .setMacFunctionKeys(keyboard, isOn):
            config.keyboards[keyboard, default: KeyboardDeviceSettings()].macFunctionKeys = isOn
        case let .setFKeyMode(mode):
            config.keyboard.fKeyMode = mode
        case let .setFnSubstitute(substitute):
            config.keyboard.fnSubstitute = substitute
        case let .setFKeyOverride(key, action):
            config.keyboard.fKeyOverrides[String(key)] = action
        case let .setPaused(isPaused):
            config.paused = isPaused
        case let .setShowMenuBarIcon(isShown):
            config.showMenuBarIcon = isShown
        case let .setAgentEnabled(isEnabled):
            config.agentEnabled = isEnabled
        case let .setDeviceHidden(key, isHidden):
            if isHidden {
                config.hiddenDevices.insert(key)
            } else {
                config.hiddenDevices.remove(key)
            }
        case let .completeOnboarding(choices):
            choices?.apply(to: &config)
            config.onboardingDone = true
        case let .replaceAll(replacement):
            config = replacement
        }
    }
}

public struct OnboardingChoices: Equatable, Sendable {
    public var accelerationOff: Bool
    public var reverseScroll: Bool
    public var desktopButtons: Bool
    public var keyboards: Set<String>

    public init(accelerationOff: Bool, reverseScroll: Bool, desktopButtons: Bool, keyboards: Set<String>) {
        self.accelerationOff = accelerationOff
        self.reverseScroll = reverseScroll
        self.desktopButtons = desktopButtons
        self.keyboards = keyboards
    }

    func apply(to config: inout KineticConfig) {
        config.editMouse(KineticConfig.allMiceKey) { profile in
            if accelerationOff {
                profile.pointer.acceleration = .off
            }
            profile.scroll.reverseVertical = reverseScroll
            if desktopButtons && profile.buttons.isEmpty {
                profile.buttons = ["3": .desktopPrevious, "4": .desktopNext]
            }
        }
        for keyboard in keyboards {
            config.keyboards[keyboard] = KeyboardDeviceSettings(swapAltWin: true, macFunctionKeys: true)
        }
    }
}

extension KineticConfig {
    /// A mouse with no profile yet starts from a copy of "All Mice".
    mutating func editMouse(_ key: String, _ change: (inout MouseProfile) -> Void) {
        var profile = mouseProfile(for: key)
        change(&profile)
        mice[key] = profile
    }
}
