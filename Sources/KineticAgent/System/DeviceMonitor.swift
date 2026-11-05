import Foundation
import KineticDomain
import IOKit.hid

/// Reports which mice and keyboards are connected.
@MainActor
final class DeviceMonitor {
    private static let debounce: TimeInterval = 0.2

    var onChange: (([DeviceInfo]) -> Void)?

    private var manager: IOHIDManager?
    private var pendingScan: DispatchWorkItem?

    func start() {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        let usages = [kHIDUsage_GD_Mouse, kHIDUsage_GD_Pointer, kHIDUsage_GD_Keyboard]
        let matching: [[String: Any]] = usages.map {
            [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: $0]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)

        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOHIDDeviceCallback = { context, _, _, _ in
            let monitor = Unmanaged<DeviceMonitor>.fromOpaque(context!).takeUnretainedValue()
            MainActor.assumeIsolated {
                monitor.scheduleScan()
            }
        }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, callback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, callback, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))

        self.manager = manager
        scan()
    }

    /// One device plugging in fires a callback per HID interface.
    private func scheduleScan() {
        pendingScan?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.scan()
            }
        }
        pendingScan = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.debounce, execute: work)
    }

    private func scan() {
        guard let manager, let handles = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return }
        let described = Dictionary(
            handles.compactMap(Self.describe).map { ($0.key, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let devices = described.values
            .map { device in
                var device = device
                device.isCompound = described.values.contains {
                    $0.kind != device.kind && $0.vendorID == device.vendorID && $0.productID == device.productID
                }
                return device
            }
            .sorted { ($0.kind.rawValue, $0.name, $0.key) < ($1.kind.rawValue, $1.name, $1.key) }
        onChange?(devices)
    }

    private nonisolated static func describe(_ device: IOHIDDevice) -> DeviceInfo? {
        func integer(_ key: String) -> Int {
            (IOHIDDeviceGetProperty(device, key as CFString) as? Int) ?? 0
        }
        func string(_ key: String) -> String {
            (IOHIDDeviceGetProperty(device, key as CFString) as? String) ?? ""
        }

        guard integer(kIOHIDPrimaryUsagePageKey) == kHIDPage_GenericDesktop else { return nil }
        let kind: DeviceKind
        switch integer(kIOHIDPrimaryUsageKey) {
        case kHIDUsage_GD_Keyboard: kind = .keyboard
        case kHIDUsage_GD_Mouse, kHIDUsage_GD_Pointer: kind = .mouse
        default: return nil
        }

        let vendorID = integer(kIOHIDVendorIDKey)
        let name = string(kIOHIDProductKey)
        let lowercasedName = name.lowercased()
        let transport = string(kIOHIDTransportKey).lowercased()
        let isApple = vendorID == DeviceInfo.appleVendorID
        let isInternal = transport.contains("spi") || transport.contains("internal") || lowercasedName.contains("internal")

        if kind == .mouse && isApple && lowercasedName.contains("trackpad") { return nil }
        guard vendorID != 0 || !name.isEmpty else { return nil }

        return DeviceInfo(
            kind: kind,
            vendorID: vendorID,
            productID: integer(kIOHIDProductIDKey),
            name: name.isEmpty ? "Unknown \(kind.rawValue)" : name,
            isApple: isApple,
            isBuiltIn: isApple && isInternal
        )
    }
}
