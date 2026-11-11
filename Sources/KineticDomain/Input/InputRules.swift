public struct InputRules: Equatable, Sendable {
    public var isEnabled = true
    public var reverseVertical = false
    public var reverseHorizontal = false
    public var scrollMultiplier: Double?
    public var buttonActions: [Int: KineticAction] = [:]
    public var usesMacFunctionKeys = false
    public var functionKeyMode: FKeyMode = .mac
    public var substituteKeyCode: UInt16? = KeyCodes.rightControl
    public var functionKeyActions: [Int: KineticAction] = [:]

    public init() {}

    public init(config: KineticConfig, devices: [DeviceInfo]) {
        isEnabled = !config.paused

        let profile = config.mouseProfile(for: config.activeMouseProfileKey(devices: devices))
        reverseVertical = profile.scroll.reverseVertical
        reverseHorizontal = profile.scroll.reverseHorizontal
        scrollMultiplier = profile.scroll.linesPerNotch.map { Double($0) / 3 }
        for (button, action) in profile.buttons {
            if let number = Int(button) {
                buttonActions[number] = action
            }
        }

        usesMacFunctionKeys = devices.contains {
            $0.kind == .keyboard && config.isEnabled($0) && config.keyboards[$0.key]?.macFunctionKeys == true
        }
        functionKeyMode = config.keyboard.fKeyMode
        substituteKeyCode = config.keyboard.fnSubstitute.keyCode
        for key in 1...12 {
            functionKeyActions[key] = config.keyboard.action(for: key)
        }
    }

    /// The substitute key while it does anything: nil when paused, when no keyboard uses Mac F-keys, or when there is none.
    public var activeSubstitute: UInt16? {
        isEnabled && usesMacFunctionKeys ? substituteKeyCode : nil
    }

    func functionKeysAreMac(substituteHeld: Bool, locked: Bool) -> Bool {
        var isMac = functionKeyMode == .mac
        if substituteHeld {
            isMac.toggle()
        }
        if locked {
            isMac.toggle()
        }
        return isMac
    }
}

extension FnSubstitute {
    var keyCode: UInt16? {
        switch self {
        case .rightControl: KeyCodes.rightControl
        case .rightOption: KeyCodes.rightOption
        case .rightCommand: KeyCodes.rightCommand
        case .none: nil
        }
    }
}

/// CGEvent flag bits for the modifier keys. The per-side bits are what tell left from right.
enum ModifierFlags {
    static func rightBit(for keyCode: UInt16) -> UInt64 {
        switch keyCode {
        case KeyCodes.rightControl: 0x2000
        case KeyCodes.rightOption: 0x0040
        default: 0x0010
        }
    }

    static func removingSubstitute(from flags: UInt64, keyCode: UInt16) -> UInt64 {
        let (general, leftBit): (UInt64, UInt64) = switch keyCode {
        case KeyCodes.rightControl: (KeyCombo.control, 0x0001)
        case KeyCodes.rightOption: (KeyCombo.option, 0x0020)
        default: (KeyCombo.command, 0x0008)
        }
        let withoutRight = flags & ~rightBit(for: keyCode)
        return withoutRight & leftBit == 0 ? withoutRight & ~general : withoutRight
    }
}
