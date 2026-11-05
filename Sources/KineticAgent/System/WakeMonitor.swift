import Foundation
import IOKit.pwr_mgt

/// Reports when the Mac wakes from sleep, through IOKit rather than NSWorkspace.
final class WakeMonitor {
    private enum Message {
        static let canSystemSleep: UInt32 = 0xE000_0270
        static let systemWillSleep: UInt32 = 0xE000_0280
        static let systemHasPoweredOn: UInt32 = 0xE000_0300
    }

    var onWake: (() -> Void)?

    private var rootPort: io_connect_t = 0
    private var notificationPort: IONotificationPortRef?
    private var notifier: io_object_t = 0

    func start() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        rootPort = IORegisterForSystemPower(context, &notificationPort, { context, _, message, argument in
            guard let context else { return }
            Unmanaged<WakeMonitor>.fromOpaque(context).takeUnretainedValue().handle(message, argument)
        }, &notifier)

        if let notificationPort {
            IONotificationPortSetDispatchQueue(notificationPort, .main)
        }
    }

    private func handle(_ message: UInt32, _ argument: UnsafeMutableRawPointer?) {
        switch message {
        case Message.canSystemSleep, Message.systemWillSleep:
            IOAllowPowerChange(rootPort, Int(bitPattern: argument))
        case Message.systemHasPoweredOn:
            onWake?()
        default:
            break
        }
    }
}
