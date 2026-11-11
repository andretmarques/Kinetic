/// One entry of System Settings' keyboard shortcuts, read from the `com.apple.symbolichotkeys` plist.
public enum SymbolicHotkeyBinding: Equatable, Sendable {
    case combo(KeyCombo)
    case doubleTap(keyCode: UInt16, mask: UInt64)
    /// Turned off in System Settings: suppresses only the default key combo. Callers that use `fire(...) || fallback` still run their fallback.
    case disabled

    private static let modifierMask = KeyCombo.shift | KeyCombo.control | KeyCombo.option | KeyCombo.command | KeyCombo.fn

    /// Nil when the entry can't be read, so the caller keeps its fallback.
    public init?(plistEntry: Any) {
        guard
            let entry = plistEntry as? [String: Any],
            let isEnabled = (entry["enabled"] as? Bool) ?? (entry["enabled"] as? Int).map({ $0 == 1 })
        else {
            return nil
        }
        guard isEnabled else {
            self = .disabled
            return
        }
        guard
            let value = entry["value"] as? [String: Any],
            let parameters = value["parameters"] as? [Int]
        else {
            return nil
        }

        if value["type"] as? String == "modifier",
           let mask = parameters.first,
           let keyCode = Self.modifierKeyCode(mask: mask) {
            self = .doubleTap(keyCode: keyCode, mask: UInt64(mask))
            return
        }
        guard parameters.count >= 3, (0..<0xFFFF).contains(parameters[1]), parameters[2] >= 0 else {
            return nil
        }
        self = .combo(KeyCombo(keyCode: UInt16(parameters[1]), modifiers: UInt64(parameters[2]) & Self.modifierMask))
    }

    private static func modifierKeyCode(mask: Int) -> UInt16? {
        switch UInt64(mask) {
        case KeyCombo.shift: 56
        case KeyCombo.control: 59
        case KeyCombo.option: 58
        case KeyCombo.command: 55
        case KeyCombo.fn: 63
        default: nil
        }
    }
}
