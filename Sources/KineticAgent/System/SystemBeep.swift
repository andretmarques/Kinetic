import Darwin

/// The system alert sound. AudioToolbox is only loaded the first time something beeps.
enum SystemBeep {
    private typealias PlayAlertSound = @convention(c) (UInt32) -> Void

    private static let userPreferredAlert: UInt32 = 0x1000
    private static let playAlertSound: PlayAlertSound? = {
        let framework = "/System/Library/Frameworks/AudioToolbox.framework/AudioToolbox"
        guard
            let library = dlopen(framework, RTLD_LAZY),
            let symbol = dlsym(library, "AudioServicesPlayAlertSound")
        else {
            return nil
        }
        return unsafeBitCast(symbol, to: PlayAlertSound.self)
    }()

    static func play() {
        playAlertSound?(userPreferredAlert)
    }
}
