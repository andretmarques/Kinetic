public struct KeyCombo: Codable, Equatable, Hashable, Sendable {
    public static let shift: UInt64 = 0x0002_0000
    public static let control: UInt64 = 0x0004_0000
    public static let option: UInt64 = 0x0008_0000
    public static let command: UInt64 = 0x0010_0000
    public static let fn: UInt64 = 0x0080_0000

    public var keyCode: UInt16
    public var modifiers: UInt64

    public init(keyCode: UInt16, modifiers: UInt64) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public var display: String {
        var symbols = ""
        if modifiers & Self.control != 0 { symbols += "⌃" }
        if modifiers & Self.option != 0 { symbols += "⌥" }
        if modifiers & Self.shift != 0 { symbols += "⇧" }
        if modifiers & Self.command != 0 { symbols += "⌘" }
        return symbols + KeyCodes.name(for: keyCode)
    }
}
