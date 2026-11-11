import ApplicationServices
import Foundation
import KineticDomain
import KineticInfrastructure

/// Turns a `KineticAction` into something macOS does. Always runs on the main thread.
/// An action that has nothing to trigger beeps instead of failing invisibly.
final class ActionRunner: @unchecked Sendable {
    private enum MediaKey: Int32 {
        case soundUp = 0, soundDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7
        case play = 16, next = 17, previous = 18
    }

    /// `NX_SYSDEFINED` events aren't covered by CGEvent's public fields. These match what
    /// AppKit's NSEvent writes for the media keys, byte for byte.
    private enum SystemEvent {
        static let type = CGEventType(rawValue: 14)
        static let subtypeField = CGEventField(rawValue: 83)
        static let data1Field = CGEventField(rawValue: 149)
        static let data2Field = CGEventField(rawValue: 150)
        static let mediaKeySubtype: Int64 = 8
    }

    private static let arrowModifiers = KeyCombo.control | KeyCombo.fn

    private let hotkeys = SymbolicHotkeys()
    private let shortcuts = ShortcutRunner()

    func run(_ action: KineticAction, at location: CGPoint?) {
        if !perform(action, at: location) {
            SystemBeep.play()
        }
    }

    private func perform(_ action: KineticAction, at location: CGPoint?) -> Bool {
        switch action {
        case .desktopPrevious:
            return hotkeys.fire(.moveLeftASpace, fallback: arrow(KeyCodes.leftArrow))
        case .desktopNext:
            return hotkeys.fire(.moveRightASpace, fallback: arrow(KeyCodes.rightArrow))
        case let .desktop(number):
            // System Settings only has "Switch to Desktop" 1 to 16; other numbers would hit other shortcuts' ids.
            guard (1...16).contains(number) else { return false }
            return hotkeys.fire(.switchToDesktop(number), fallback: nil)
        case .missionControl:
            return hotkeys.fire(.missionControl, fallback: arrow(KeyCodes.upArrow))
        case .appExpose:
            return hotkeys.fire(.applicationWindows, fallback: arrow(KeyCodes.downArrow))
        case .showDesktop:
            return hotkeys.fire(.showDesktop, fallback: KeyCombo(keyCode: KeyCodes.f11, modifiers: 0))
        case .notificationCenter:
            return hotkeys.fire(.notificationCenter, fallback: nil) || Self.pressMenuBarClock()
        case .spotlight:
            return hotkeys.fire(.spotlight, fallback: KeyCombo(keyCode: KeyCodes.space, modifiers: KeyCombo.command))
        case .launchpad:
            return hotkeys.fire(.launchpad, fallback: nil) || Self.openAppsLauncher()
        case .dictation:
            return hotkeys.fire(.dictation, fallback: nil)
        case .lockScreen:
            EventPoster.press(KeyCombo(keyCode: KeyCodes.q, modifiers: KeyCombo.control | KeyCombo.command))
        case .screenshotArea:
            EventPoster.press(KeyCombo(keyCode: KeyCodes.digit4, modifiers: KeyCombo.shift | KeyCombo.command))
        case .screenshotOptions:
            EventPoster.press(KeyCombo(keyCode: KeyCodes.digit5, modifiers: KeyCombo.shift | KeyCombo.command))
        case .back:
            EventPoster.press(KeyCombo(keyCode: KeyCodes.leftBracket, modifiers: KeyCombo.command))
        case .forward:
            EventPoster.press(KeyCombo(keyCode: KeyCodes.rightBracket, modifiers: KeyCombo.command))
        case .nextTab:
            EventPoster.press(KeyCombo(keyCode: KeyCodes.tab, modifiers: KeyCombo.control))
        case .previousTab:
            EventPoster.press(KeyCombo(keyCode: KeyCodes.tab, modifiers: KeyCombo.control | KeyCombo.shift))
        case .closeWindow:
            EventPoster.press(KeyCombo(keyCode: KeyCodes.w, modifiers: KeyCombo.command))
        case .quitApp:
            EventPoster.press(KeyCombo(keyCode: KeyCodes.q, modifiers: KeyCombo.command))
        case .doubleClick:
            EventPoster.doubleClick(at: location ?? Self.currentMouseLocation())
        case .playPause:
            post(.play)
        case .nextTrack:
            post(.next)
        case .previousTrack:
            post(.previous)
        case .volumeUp:
            post(.soundUp)
        case .volumeDown:
            post(.soundDown)
        case .mute:
            post(.mute)
        case .brightnessUp:
            post(.brightnessUp)
        case .brightnessDown:
            post(.brightnessDown)
        case let .keyCombo(combo):
            EventPoster.press(combo)
        case let .openApp(bundleID, _):
            SystemOpener.open(bundleIdentifier: bundleID)
        case let .runShortcut(name):
            shortcuts.run(name)
        case .middleClick, .rightClick:
            // Mouse buttons are remapped by the event tap; only a key can get here, and it can't hold a click.
            return false
        case .none, .passThrough:
            break
        }
        return true
    }

    private func arrow(_ keyCode: UInt16) -> KeyCombo {
        KeyCombo(keyCode: keyCode, modifiers: Self.arrowModifiers)
    }

    private func post(_ key: MediaKey) {
        postMediaEvent(key, isDown: true)
        postMediaEvent(key, isDown: false)
    }

    private func postMediaEvent(_ key: MediaKey, isDown: Bool) {
        let state: Int32 = isDown ? 0x0A00 : 0x0B00
        guard
            let event = CGEvent(source: nil),
            let type = SystemEvent.type,
            let subtypeField = SystemEvent.subtypeField,
            let data1Field = SystemEvent.data1Field,
            let data2Field = SystemEvent.data2Field
        else {
            return
        }
        event.type = type
        event.flags = CGEventFlags(rawValue: UInt64(state))
        event.setIntegerValueField(subtypeField, value: SystemEvent.mediaKeySubtype)
        event.setIntegerValueField(data1Field, value: Int64((key.rawValue << 16) | state))
        event.setIntegerValueField(data2Field, value: -1)
        EventPoster.post(event)
    }

    /// macOS has no default Notification Center shortcut. Clicking the menu bar clock is what opens it.
    private static func pressMenuBarClock() -> Bool {
        guard let controlCenter = RunningProcesses.identifiers(named: "ControlCenter").first else { return false }

        let application = AXUIElementCreateApplication(controlCenter)
        guard
            let menuBar = attribute(of: application, "AXExtrasMenuBar"),
            CFGetTypeID(menuBar) == AXUIElementGetTypeID(),
            let items = attribute(of: menuBar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement],
            let clock = items.first(where: { (attribute(of: $0, "AXIdentifier") as? String)?.contains("clock") == true })
        else {
            return false
        }
        return AXUIElementPerformAction(clock, kAXPressAction as CFString) == .success
    }

    private static func attribute(of element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
        return result == .success ? value : nil
    }

    private static func openAppsLauncher() -> Bool {
        let launchers = ["/System/Applications/Apps.app", "/System/Applications/Launchpad.app"]
        guard let path = launchers.first(where: FileManager.default.fileExists(atPath:)) else {
            return false
        }
        SystemOpener.open(path: path)
        return true
    }

    private static func currentMouseLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? .zero
    }
}
