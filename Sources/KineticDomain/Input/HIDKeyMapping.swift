/// One `hidutil` UserKeyMapping entry: a HID usage (page << 32 | usage) the keyboard sends, and what macOS sees instead.
public struct HIDKeyPair: Equatable, Sendable {
    public let source: UInt64
    public let destination: UInt64
}

/// What macOS's own key remapping does for one PC keyboard. Remapping there works below every event
/// tap, so it keeps working while an app holds Secure Input and the tap sees no keys at all.
public struct KeyboardMapping: Equatable, Sendable {
    public let device: DeviceInfo
    public let pairs: [HIDKeyPair]

    private static let altWinSwap: [HIDKeyPair] = [
        HIDKeyPair(source: 0x7_0000_00E2, destination: 0x7_0000_00E3),
        HIDKeyPair(source: 0x7_0000_00E3, destination: 0x7_0000_00E2),
        HIDKeyPair(source: 0x7_0000_00E6, destination: 0x7_0000_00E7),
        HIDKeyPair(source: 0x7_0000_00E7, destination: 0x7_0000_00E6),
    ]

    /// F1 is keyboard usage 0x3A, and F1–F12 follow it in order.
    private static func functionKeyUsage(_ key: Int) -> UInt64 {
        0x7_0000_0039 + UInt64(key)
    }

    public init(device: DeviceInfo, config: KineticConfig, fnLocked: Bool) {
        self.device = device
        let settings = config.keyboards[device.key] ?? KeyboardDeviceSettings()
        guard !config.paused else {
            pairs = []
            return
        }

        var pairs = settings.swapAltWin ? Self.altWinSwap : []
        let macMode = (config.keyboard.fKeyMode == .mac) != fnLocked
        if settings.macFunctionKeys && macMode {
            pairs += (1...12).compactMap { key in
                config.keyboard.action(for: key).hidUsage.map {
                    HIDKeyPair(source: Self.functionKeyUsage(key), destination: $0)
                }
            }
        }
        self.pairs = pairs
    }
}

extension KineticAction {
    /// The consumer-page usage a keyboard can send for this action, so macOS performs it without Kinetic seeing the key.
    var hidUsage: UInt64? {
        switch self {
        case .brightnessUp: 0xC_0000_006F
        case .brightnessDown: 0xC_0000_0070
        case .nextTrack: 0xC_0000_00B5
        case .previousTrack: 0xC_0000_00B6
        case .playPause: 0xC_0000_00CD
        case .mute: 0xC_0000_00E2
        case .volumeUp: 0xC_0000_00E9
        case .volumeDown: 0xC_0000_00EA
        default: nil
        }
    }

    /// The action behind an `NX_SYSDEFINED` media key event. macOS reports the track keys as either NEXT/PREVIOUS or FAST/REWIND.
    init?(mediaKeyType: Int) {
        switch mediaKeyType {
        case 0: self = .volumeUp
        case 1: self = .volumeDown
        case 2: self = .brightnessUp
        case 3: self = .brightnessDown
        case 7: self = .mute
        case 16: self = .playPause
        case 17, 19: self = .nextTrack
        case 18, 20: self = .previousTrack
        default: return nil
        }
    }
}
