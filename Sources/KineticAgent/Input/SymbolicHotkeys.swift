import CoreGraphics
import Foundation
import KineticDomain

/// Reads the user's real shortcuts from System Settings, so "Next Desktop" does whatever they set.
final class SymbolicHotkeys {
    enum Hotkey {
        case missionControl, applicationWindows, showDesktop, moveLeftASpace, moveRightASpace
        case switchToDesktop(Int), spotlight, notificationCenter, launchpad, dictation

        var id: Int {
            switch self {
            case .missionControl: 32
            case .applicationWindows: 33
            case .showDesktop: 36
            case .moveLeftASpace: 79
            case .moveRightASpace: 81
            case let .switchToDesktop(number): 117 + number
            case .spotlight: 64
            case .notificationCenter: 163
            case .launchpad: 160
            case .dictation: 164
            }
        }
    }

    private enum Binding {
        case combo(KeyCombo)
        case doubleTap(keyCode: CGKeyCode, mask: UInt64)
    }

    private static let cacheLifetime: TimeInterval = 30
    private static let doubleTapDelay: TimeInterval = 0.08
    private static let modifierMask = KeyCombo.shift | KeyCombo.control | KeyCombo.option | KeyCombo.command | KeyCombo.fn

    private var cache: [Int: Binding] = [:]
    private var cachedAt = Date.distantPast

    /// Returns false when there's nothing to send, so the caller can try something else.
    @discardableResult
    func fire(_ hotkey: Hotkey, fallback: KeyCombo?) -> Bool {
        if Date.now.timeIntervalSince(cachedAt) > Self.cacheLifetime {
            reload()
        }
        switch cache[hotkey.id] {
        case let .combo(combo):
            EventPoster.press(combo)
        case let .doubleTap(keyCode, mask):
            EventPoster.tapModifier(keyCode: keyCode, mask: mask)
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.doubleTapDelay) {
                EventPoster.tapModifier(keyCode: keyCode, mask: mask)
            }
        case nil:
            guard let fallback else { return false }
            EventPoster.press(fallback)
        }
        return true
    }

    private func reload() {
        cachedAt = .now
        let defaults = UserDefaults(suiteName: "com.apple.symbolichotkeys")
        let entries = defaults?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
        cache = entries.reduce(into: [:]) { result, entry in
            if let id = Int(entry.key), let binding = Self.binding(from: entry.value) {
                result[id] = binding
            }
        }
    }

    private static func binding(from entry: Any) -> Binding? {
        guard
            let entry = entry as? [String: Any],
            (entry["enabled"] as? Bool) ?? (entry["enabled"] as? Int == 1),
            let value = entry["value"] as? [String: Any],
            let parameters = value["parameters"] as? [Int]
        else {
            return nil
        }

        if value["type"] as? String == "modifier",
           let mask = parameters.first,
           let keyCode = modifierKeyCode(mask: mask) {
            return .doubleTap(keyCode: keyCode, mask: UInt64(mask))
        }
        guard parameters.count >= 3, (0..<0xFFFF).contains(parameters[1]), parameters[2] >= 0 else {
            return nil
        }
        return .combo(KeyCombo(keyCode: UInt16(parameters[1]), modifiers: UInt64(parameters[2]) & modifierMask))
    }

    private static func modifierKeyCode(mask: Int) -> CGKeyCode? {
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
