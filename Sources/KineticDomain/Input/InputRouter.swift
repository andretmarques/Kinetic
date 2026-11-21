import Foundation

public enum ButtonPhase: Sendable {
    case down, dragged, up
}

public enum ButtonRoute: Equatable, Sendable {
    case pass, swallow, asMiddle, asRight
}

public enum KeyRoute: Equatable, Sendable {
    case pass, swallow
    case passWithFlags(UInt64)
}

/// What to do with a media key event, which is what an F-key sends once its Mac action lives in the keyboard's HID mapping.
public enum MediaKeyRoute: Equatable, Sendable {
    case pass
    /// Swallow the media event and post this F-key instead.
    case asFunctionKey(code: UInt16, isDown: Bool, flags: UInt64)
}

public enum InputCommand: Equatable, Sendable {
    case run(KineticAction)
    case reportButton(Int)
}

public struct InputContext: Sendable {
    public var rules: InputRules
    public var isLearning: Bool
    public var isLocked: Bool

    public init(rules: InputRules, isLearning: Bool, isLocked: Bool) {
        self.rules = rules
        self.isLearning = isLearning
        self.isLocked = isLocked
    }
}

/// Decides what happens to each input event. Holds only the state needed to keep a press and its
/// release consistent, so nothing is ever left stuck down when settings change mid-press.
public struct InputRouter: Sendable {
    private static let doubleTapWindow: TimeInterval = 0.35

    private var heldButtons: [Int: ButtonRoute] = [:]
    private var swallowedKeys: Set<UInt16> = []
    private var substituteIsDown = false
    private var convertedMediaKeys: [Int: UInt16] = [:]
    private var lastSubstituteTap: TimeInterval = 0

    public init() {}

    public mutating func routeButton(
        _ button: Int,
        phase: ButtonPhase,
        context: InputContext
    ) -> (route: ButtonRoute, command: InputCommand?) {
        switch phase {
        case .down:
            let (route, command) = decideButton(button, context: context)
            heldButtons[button] = route
            return (route, command)
        case .dragged:
            return (heldButtons[button] ?? .pass, nil)
        case .up:
            return (heldButtons.removeValue(forKey: button) ?? .pass, nil)
        }
    }

    /// Returns whether a double-tap just flipped the F-key mode.
    public mutating func routeFlags(keyCode: UInt16, flags: UInt64, now: TimeInterval, context: InputContext) -> Bool {
        let rules = context.rules
        guard let substitute = rules.activeSubstitute else {
            substituteIsDown = false
            return false
        }
        guard keyCode == substitute else { return false }

        let isDown = flags & ModifierFlags.rightBit(for: substitute) != 0
        defer { substituteIsDown = isDown }
        guard isDown && !substituteIsDown else { return false }

        if now - lastSubstituteTap < Self.doubleTapWindow {
            lastSubstituteTap = 0
            return true
        }
        lastSubstituteTap = now
        return false
    }

    public mutating func routeKey(
        code: UInt16,
        isDown: Bool,
        isRepeat: Bool,
        flags: UInt64,
        context: InputContext
    ) -> (route: KeyRoute, command: InputCommand?) {
        if isDown {
            lastSubstituteTap = 0
        }
        guard let functionKey = KeyCodes.functionKeys[code] else { return (.pass, nil) }
        if !isDown && swallowedKeys.remove(code) != nil {
            return (.swallow, nil)
        }

        let rules = context.rules
        let activeSubstitute = rules.activeSubstitute
        let substituteHeld = activeSubstitute.map { flags & ModifierFlags.rightBit(for: $0) != 0 } ?? false

        if isDown {
            if !isRepeat {
                updateOwnership(of: code, functionKey: functionKey, substituteHeld: substituteHeld, context: context)
            }
            if swallowedKeys.contains(code) {
                return (.swallow, command(forFunctionKey: functionKey, isRepeat: isRepeat, rules: rules))
            }
        }

        if substituteHeld, let substitute = activeSubstitute {
            return (.passWithFlags(ModifierFlags.removingSubstitute(from: flags, keyCode: substitute)), nil)
        }
        return (.pass, nil)
    }

    /// Holding the substitute asks for the standard F-key, but a HID-mapped F-key reaches the tap as a media key.
    /// The press and its release are converted together, even if the substitute is let go in between.
    /// shortcut: a media event doesn't say which key sent it, so a real media key pressed with the substitute held is
    /// converted too, and two F-keys with the same action both post the lower one. Fixing it needs per-device events.
    public mutating func routeMediaKey(type: Int, isDown: Bool, flags: UInt64, context: InputContext) -> MediaKeyRoute {
        let substitute = context.rules.activeSubstitute
        let cleanFlags = substitute.map { ModifierFlags.removingSubstitute(from: flags, keyCode: $0) } ?? flags

        guard isDown else {
            guard let code = convertedMediaKeys.removeValue(forKey: type) else { return .pass }
            return .asFunctionKey(code: code, isDown: false, flags: cleanFlags)
        }
        lastSubstituteTap = 0
        if let code = convertedMediaKeys[type] {
            return .asFunctionKey(code: code, isDown: true, flags: cleanFlags)
        }

        let rules = context.rules
        guard
            let substitute,
            flags & ModifierFlags.rightBit(for: substitute) != 0,
            rules.functionKeysAreMac(substituteHeld: false, locked: context.isLocked),
            let action = KineticAction(mediaKeyType: type),
            let functionKey = (1...12).first(where: { rules.functionKeyActions[$0] == action }),
            let code = KeyCodes.functionKeys.first(where: { $0.value == functionKey })?.key
        else {
            return .pass
        }
        convertedMediaKeys[type] = code
        return .asFunctionKey(code: code, isDown: true, flags: cleanFlags)
    }

    public mutating func tapWasReenabled() {
        substituteIsDown = false
        // A release may have been lost while the tap was off.
        convertedMediaKeys.removeAll()
    }

    private func decideButton(_ button: Int, context: InputContext) -> (ButtonRoute, InputCommand?) {
        if context.isLearning {
            return (.swallow, .reportButton(button))
        }
        guard context.rules.isEnabled, let action = context.rules.buttonActions[button] else {
            return (.pass, nil)
        }
        switch action {
        case .middleClick: return (.asMiddle, nil)
        case .rightClick: return (.asRight, nil)
        case .passThrough: return (.pass, nil)
        default: return (.swallow, .run(action))
        }
    }

    private mutating func updateOwnership(
        of code: UInt16,
        functionKey: Int,
        substituteHeld: Bool,
        context: InputContext
    ) {
        let rules = context.rules
        let action = rules.functionKeyActions[functionKey]
        let isTakenOver = rules.isEnabled
            && rules.usesMacFunctionKeys
            && rules.functionKeysAreMac(substituteHeld: substituteHeld, locked: context.isLocked)
            && action != nil
            && action != .passThrough

        if isTakenOver {
            swallowedKeys.insert(code)
        } else {
            swallowedKeys.remove(code)
        }
    }

    private func command(forFunctionKey key: Int, isRepeat: Bool, rules: InputRules) -> InputCommand? {
        guard rules.isEnabled, let action = rules.functionKeyActions[key] else { return nil }
        guard !isRepeat || action.repeatsWhileHeld else { return nil }
        return .run(action)
    }
}

private extension KineticAction {
    var repeatsWhileHeld: Bool {
        switch self {
        case .volumeUp, .volumeDown, .brightnessUp, .brightnessDown: true
        default: false
        }
    }
}
