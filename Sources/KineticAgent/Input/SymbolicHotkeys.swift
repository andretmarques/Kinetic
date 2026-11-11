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

    private static let cacheLifetime: TimeInterval = 30
    private static let doubleTapDelay: TimeInterval = 0.08

    private var cache: [Int: SymbolicHotkeyBinding] = [:]
    private var cachedAt = Date.distantPast

    /// Returns false when there's nothing to send, so the caller can try something else.
    /// A `.disabled` entry suppresses only the default combo; callers using `fire(...) || fallback` still run the fallback.
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
        case .disabled:
            return false
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
            if let id = Int(entry.key), let binding = SymbolicHotkeyBinding(plistEntry: entry.value) {
                result[id] = binding
            }
        }
    }
}
