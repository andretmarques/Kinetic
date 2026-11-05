import CoreGraphics
import KineticDomain

/// Everything Kinetic synthesizes carries `tag`, so the event tap lets it pass instead of remapping it again.
enum EventPoster {
    static let tag: Int64 = 0x4B4E_5443

    static func post(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: tag)
        event.post(tap: .cghidEventTap)
    }

    static func press(_ combo: KeyCombo) {
        let source = makeSource()
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: combo.keyCode, keyDown: false)
        else {
            return
        }
        let flags = CGEventFlags(rawValue: combo.modifiers)
        down.flags = flags
        up.flags = flags
        post(down)
        post(up)
    }

    static func tapModifier(keyCode: CGKeyCode, mask: UInt64) {
        let source = makeSource()
        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return
        }
        down.type = .flagsChanged
        down.flags = CGEventFlags(rawValue: mask)
        up.type = .flagsChanged
        up.flags = []
        post(down)
        post(up)
    }

    static func doubleClick(at point: CGPoint) {
        let source = makeSource()
        for click in 1...2 {
            guard
                let down = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left),
                let up = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)
            else {
                return
            }
            down.setIntegerValueField(.mouseEventClickState, value: Int64(click))
            up.setIntegerValueField(.mouseEventClickState, value: Int64(click))
            post(down)
            post(up)
        }
    }

    private static func makeSource() -> CGEventSource? {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.userData = tag
        return source
    }
}
