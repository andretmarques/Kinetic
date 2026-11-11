import Foundation

extension KeyedDecodingContainer {
    func decode<T: Decodable>(_ key: Key, or fallback: @autoclosure () -> T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback()
    }

    /// Drops entries that fail to decode, so one bad entry can't wipe the whole dictionary.
    func decodeLossyDictionary<T: Decodable>(_ key: Key) -> [String: T] {
        let raw = (try? decodeIfPresent([String: Lossy<T>].self, forKey: key)) ?? [:]
        return raw.compactMapValues(\.value)
    }

    func decodeActions(_ key: Key) -> [String: KineticAction] {
        decodeLossyDictionary(key)
    }
}

private struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: Decoder) throws { value = try? T(from: decoder) }
}
public enum AccelerationMode: String, Codable, CaseIterable, Sendable {
    case off, system, custom

    public var title: String {
        switch self {
        case .off: "Off"
        case .system: "macOS"
        case .custom: "Custom"
        }
    }
}

public struct PointerSettings: Codable, Equatable, Sendable {
    public var speed: Double
    public var acceleration: AccelerationMode
    public var curve: Double

    public init(speed: Double = 10, acceleration: AccelerationMode = .system, curve: Double = 0.6875) {
        self.speed = speed
        self.acceleration = acceleration
        self.curve = curve
    }

    enum CodingKeys: String, CodingKey { case speed, acceleration, curve }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = PointerSettings()
        speed = max(1, min(20, c.decode(.speed, or: d.speed)))
        acceleration = c.decode(.acceleration, or: d.acceleration)
        curve = max(0, min(3, c.decode(.curve, or: d.curve)))
    }
}

public struct ScrollSettings: Codable, Equatable, Sendable {
    public var reverseVertical: Bool
    public var reverseHorizontal: Bool
    public var linesPerNotch: Int?

    public init(reverseVertical: Bool = false, reverseHorizontal: Bool = false, linesPerNotch: Int? = nil) {
        self.reverseVertical = reverseVertical
        self.reverseHorizontal = reverseHorizontal
        self.linesPerNotch = linesPerNotch
    }

    enum CodingKeys: String, CodingKey { case reverseVertical, reverseHorizontal, linesPerNotch }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reverseVertical = c.decode(.reverseVertical, or: false)
        reverseHorizontal = c.decode(.reverseHorizontal, or: false)
        let lines: Int? = c.decode(.linesPerNotch, or: nil)
        linesPerNotch = lines.map { max(1, min(10, $0)) }
    }
}

public struct MouseProfile: Codable, Equatable, Sendable {
    public var pointer: PointerSettings
    public var scroll: ScrollSettings
    public var buttons: [String: KineticAction]

    public init(pointer: PointerSettings = .init(), scroll: ScrollSettings = .init(), buttons: [String: KineticAction] = [:]) {
        self.pointer = pointer
        self.scroll = scroll
        self.buttons = buttons
    }

    enum CodingKeys: String, CodingKey { case pointer, scroll, buttons }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pointer = c.decode(.pointer, or: PointerSettings())
        scroll = c.decode(.scroll, or: ScrollSettings())
        buttons = c.decodeActions(.buttons)
    }
}
public enum FKeyMode: String, Codable, CaseIterable, Sendable {
    case mac, standard

    public var title: String {
        switch self {
        case .mac: "Mac actions"
        case .standard: "Standard F1–F12"
        }
    }
}
public enum FnSubstitute: String, Codable, CaseIterable, Sendable {
    case rightControl, rightOption, rightCommand, none

    public var title: String {
        switch self {
        case .rightControl: "Right Control"
        case .rightOption: "Right Option"
        case .rightCommand: "Right Command"
        case .none: "None"
        }
    }
}

public struct KeyboardDeviceSettings: Codable, Equatable, Sendable {
    public var swapAltWin: Bool
    public var macFunctionKeys: Bool

    public init(swapAltWin: Bool = false, macFunctionKeys: Bool = false) {
        self.swapAltWin = swapAltWin
        self.macFunctionKeys = macFunctionKeys
    }

    enum CodingKeys: String, CodingKey { case swapAltWin, macFunctionKeys }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        swapAltWin = c.decode(.swapAltWin, or: false)
        macFunctionKeys = c.decode(.macFunctionKeys, or: false)
    }
}

public struct KeyboardSettings: Codable, Equatable, Sendable {
    public var fKeyMode: FKeyMode
    public var fnSubstitute: FnSubstitute
    public var fKeyOverrides: [String: KineticAction]

    public init(fKeyMode: FKeyMode = .mac, fnSubstitute: FnSubstitute = .rightControl, fKeyOverrides: [String: KineticAction] = [:]) {
        self.fKeyMode = fKeyMode
        self.fnSubstitute = fnSubstitute
        self.fKeyOverrides = fKeyOverrides
    }
    public static func defaultMacAction(for fKey: Int) -> KineticAction {
        switch fKey {
        case 1: .brightnessDown
        case 2: .brightnessUp
        case 3: .missionControl
        case 4: .spotlight
        case 5: .dictation
        case 6: .passThrough // macOS has no reliable way to toggle Do Not Disturb, so F6 stays F6.
        case 7: .previousTrack
        case 8: .playPause
        case 9: .nextTrack
        case 10: .mute
        case 11: .volumeDown
        case 12: .volumeUp
        default: .none
        }
    }

    public func action(for fKey: Int) -> KineticAction {
        fKeyOverrides[String(fKey)] ?? Self.defaultMacAction(for: fKey)
    }

    enum CodingKeys: String, CodingKey { case fKeyMode, fnSubstitute, fKeyOverrides }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fKeyMode = c.decode(.fKeyMode, or: .mac)
        fnSubstitute = c.decode(.fnSubstitute, or: .rightControl)
        fKeyOverrides = c.decodeActions(.fKeyOverrides)
    }
}
public struct KineticConfig: Codable, Equatable, Sendable {
    public static let allMiceKey = "*"

    public var version: Int
    public var paused: Bool
    public var showMenuBarIcon: Bool
    public var onboardingDone: Bool
    public var mice: [String: MouseProfile]
    public var keyboards: [String: KeyboardDeviceSettings]
    public var keyboard: KeyboardSettings
    public var hiddenDevices: Set<String>
    public var agentEnabled: Bool

    public init() {
        version = 1
        paused = false
        showMenuBarIcon = true
        onboardingDone = false
        mice = [Self.allMiceKey: MouseProfile()]
        keyboards = [:]
        keyboard = KeyboardSettings()
        hiddenDevices = []
        agentEnabled = true
    }

    enum CodingKeys: String, CodingKey { case version, paused, showMenuBarIcon, onboardingDone, mice, keyboards, keyboard, hiddenDevices, agentEnabled }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KineticConfig()
        version = c.decode(.version, or: d.version)
        paused = c.decode(.paused, or: d.paused)
        showMenuBarIcon = c.decode(.showMenuBarIcon, or: d.showMenuBarIcon)
        onboardingDone = c.decode(.onboardingDone, or: d.onboardingDone)
        mice = c.decodeLossyDictionary(.mice)
        if mice[Self.allMiceKey] == nil { mice[Self.allMiceKey] = MouseProfile() }
        keyboards = c.decodeLossyDictionary(.keyboards)
        keyboard = c.decode(.keyboard, or: d.keyboard)
        hiddenDevices = c.decode(.hiddenDevices, or: [])
        agentEnabled = c.decode(.agentEnabled, or: true)
    }

    public func isEnabled(_ device: DeviceInfo) -> Bool { !device.isBuiltIn && !hiddenDevices.contains(device.key) }
    /// Events don't say which mouse they came from, so per-mouse scroll and button settings apply only to a lone mouse.
    public func activeMouseProfileKey(devices: [DeviceInfo]) -> String {
        let mice = devices.filter { $0.kind == .mouse && isEnabled($0) }
        if mice.count == 1, self.mice[mice[0].key] != nil { return mice[0].key }
        return Self.allMiceKey
    }
    public func mouseProfile(for deviceKey: String?) -> MouseProfile {
        if let deviceKey, let own = mice[deviceKey] {
            return own
        }
        return mice[Self.allMiceKey] ?? MouseProfile()
    }
}
