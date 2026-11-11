import Testing
@testable import KineticDomain

@Suite struct SymbolicHotkeyBindingTests {
    @Test func enabledShortcutIsRead() {
        let entry: [String: Any] = ["enabled": true, "value": ["parameters": [65535, 123, 262144], "type": "standard"]]
        #expect(SymbolicHotkeyBinding(plistEntry: entry) == .combo(KeyCombo(keyCode: 123, modifiers: KeyCombo.control)))
    }

    @Test func modifierDoubleTapIsRead() {
        let entry: [String: Any] = ["enabled": 1, "value": ["parameters": [262144], "type": "modifier"]]
        #expect(SymbolicHotkeyBinding(plistEntry: entry) == .doubleTap(keyCode: 59, mask: KeyCombo.control))
    }

    @Test func turnedOffEntryIsDisabled() {
        let value: [String: Any] = ["parameters": [65535, 123, 262144], "type": "standard"]
        let offAsBool: [String: Any] = ["enabled": false, "value": value]
        let offAsInt: [String: Any] = ["enabled": 0, "value": value]
        #expect(SymbolicHotkeyBinding(plistEntry: offAsBool) == .disabled)
        #expect(SymbolicHotkeyBinding(plistEntry: offAsInt) == .disabled)
    }

    @Test func unreadableEntryIsNil() {
        let noFlag: [String: Any] = ["value": ["parameters": [65535, 123, 262144], "type": "standard"]]
        #expect(SymbolicHotkeyBinding(plistEntry: noFlag) == nil)
        #expect(SymbolicHotkeyBinding(plistEntry: "junk") == nil)
    }
}
