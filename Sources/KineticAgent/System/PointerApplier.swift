import Foundation
import KineticDomain
import IOKit.hid

/// Sets pointer speed and acceleration per mouse through the HID event system. It's a private API, loaded
/// dynamically so the app still launches if it goes away, in which case the global default is used instead.
final class PointerApplier {
    // Objects cross the C boundary as raw pointers, so every toolchain accepts these as C function types.
    private typealias RawObject = UnsafeMutableRawPointer
    private typealias CreateClient = @convention(c) (CFAllocator?, Int32, CFDictionary?) -> RawObject?
    private typealias SetMatching = @convention(c) (RawObject, CFDictionary?) -> Void
    private typealias CopyServices = @convention(c) (RawObject) -> RawObject?
    private typealias CopyProperty = @convention(c) (RawObject, CFString) -> RawObject?
    private typealias SetProperty = @convention(c) (RawObject, CFString, RawObject) -> Bool

    private struct API {
        let createClient: CreateClient
        let setMatching: SetMatching
        let copyServices: CopyServices
        let copyProperty: CopyProperty
        let setProperty: SetProperty
    }

    private enum Key {
        static let linear = "HIDUseLinearScalingMouseAcceleration"
        static let resolution = "HIDPointerResolution"
        static let pointerAcceleration = "HIDPointerAcceleration"
        static let accelerationType = "HIDPointerAccelerationType"
        static let mouseAcceleration = "HIDMouseAcceleration"
        static let scalingPreference = "com.apple.mouse.scaling"
        static let linearPreference = "com.apple.mouse.linear"
    }

    private static let passiveClientType: Int32 = 2

    private let api: API?
    private let baselineURL: URL
    private var baselines: [String: Int]
    private var writtenLinearModes: [String: Bool] = [:]

    init(directory: URL) {
        api = Self.loadAPI()
        baselineURL = directory.appendingPathComponent("pointer-baseline.json")
        let data = try? Data(contentsOf: baselineURL)
        baselines = data.flatMap { try? JSONDecoder().decode([String: Int].self, from: $0) } ?? [:]
    }

    func apply(config: KineticConfig, force: Bool) {
        write(force: force, fallback: config.paused ? PointerSettings() : config.mouseProfile(for: nil).pointer) { key in
            guard !config.paused, !config.hiddenDevices.contains(key) else { return PointerSettings() }
            return config.mouseProfile(for: key).pointer
        }
    }

    func restore() {
        write(force: false, fallback: PointerSettings()) { _ in PointerSettings() }
    }

    private func write(force: Bool, fallback: PointerSettings, settings: (String) -> PointerSettings) {
        // A client's service list is a snapshot, so each apply asks a fresh one to see reconnected devices.
        guard
            let api,
            let client = makeClient(api),
            let copiedServices = api.copyServices(Self.raw(client))
        else {
            applyGlobalFallback(fallback)
            return
        }

        // Writing to a service whose client has been released crashes.
        let services = Unmanaged<CFArray>.fromOpaque(copiedServices).takeRetainedValue()
        withExtendedLifetime(client) {
            let scaling = Self.preference(Key.scalingPreference) as? Double ?? PointerMath.macOSDefaultScaling
            let linear = Self.preference(Key.linearPreference) as? Bool ?? false
            for index in 0..<CFArrayGetCount(services) {
                guard let element = CFArrayGetValueAtIndex(services, index) else { continue }
                let service = UnsafeMutableRawPointer(mutating: element)
                write(to: service, api: api, force: force, systemScaling: scaling, systemLinear: linear, settings: settings)
            }
        }
    }

    private func write(
        to service: RawObject,
        api: API,
        force: Bool,
        systemScaling: Double,
        systemLinear: Bool,
        settings: (String) -> PointerSettings
    ) {
        func property(_ key: String) -> CFTypeRef? {
            api.copyProperty(service, key as CFString).map {
                Unmanaged<CFTypeRef>.fromOpaque($0).takeRetainedValue()
            }
        }
        func integer(_ key: String) -> Int? {
            property(key) as? Int
        }
        func set(_ key: String, _ value: Int) {
            let number = value as CFNumber
            withExtendedLifetime(number) {
                _ = api.setProperty(service, key as CFString, Self.raw(number))
            }
        }

        let vendor = integer(kIOHIDVendorIDKey) ?? 0
        guard vendor != DeviceInfo.appleVendorID else { return }
        let key = DeviceInfo.key(kind: .mouse, vendorID: vendor, productID: integer(kIOHIDProductIDKey) ?? 0)

        let wanted = PointerMath.values(
            for: settings(key),
            systemScaling: systemScaling,
            systemLinear: systemLinear,
            baselineResolution: baseline(for: key, current: integer(Key.resolution))
        )

        let accelerationKey = property(Key.accelerationType) as? String ?? Key.mouseAcceleration
        let accelerationKeys = accelerationKey == Key.pointerAcceleration
            ? [accelerationKey]
            : [accelerationKey, Key.pointerAcceleration]

        let isCurrent = writtenLinearModes[key] == wanted.linear
            && integer(Key.resolution) == wanted.resolution
            && accelerationKeys.allSatisfy { integer($0) == wanted.acceleration }
        guard force || !isCurrent else { return }

        // The driver only picks up the linear mode and resolution when the acceleration value changes,
        // so those are written first and acceleration is then nudged to count as a change.
        set(Key.linear, wanted.linear ? 1 : 0)
        writtenLinearModes[key] = wanted.linear
        set(Key.resolution, wanted.resolution)
        for accelerationKey in accelerationKeys {
            set(accelerationKey, wanted.acceleration + 1)
            set(accelerationKey, wanted.acceleration)
        }
    }

    private func baseline(for key: String, current: Int?) -> Int {
        if let known = baselines[key] {
            return known
        }
        let baseline = current ?? PointerMath.defaultResolution
        baselines[key] = baseline
        if let data = try? JSONEncoder().encode(baselines) {
            try? data.write(to: baselineURL, options: .atomic)
        }
        return baseline
    }

    private func makeClient(_ api: API) -> CFTypeRef? {
        guard let created = api.createClient(kCFAllocatorDefault, Self.passiveClientType, nil) else {
            return nil
        }
        let client = Unmanaged<CFTypeRef>.fromOpaque(created).takeRetainedValue()
        let matching: [String: Int] = [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse]
        api.setMatching(Self.raw(client), matching as CFDictionary)
        return client
    }

    private func applyGlobalFallback(_ settings: PointerSettings) {
        let value: CFNumber? = switch settings.acceleration {
        case .off: -1.0 as CFNumber
        case .system: nil
        case .custom: settings.curve as CFNumber
        }
        CFPreferencesSetValue(
            Key.scalingPreference as CFString,
            value,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        CFPreferencesSynchronize(kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private static func raw(_ object: CFTypeRef) -> RawObject {
        Unmanaged.passUnretained(object).toOpaque()
    }

    private static func preference(_ key: String) -> CFPropertyList? {
        CFPreferencesCopyValue(key as CFString, kCFPreferencesAnyApplication, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
    }

    private static func loadAPI() -> API? {
        let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW)
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let handle, let pointer = dlsym(handle, name) else { return nil }
            return unsafeBitCast(pointer, to: T.self)
        }
        guard
            let createClient = symbol("IOHIDEventSystemClientCreateWithType", as: CreateClient.self),
            let setMatching = symbol("IOHIDEventSystemClientSetMatching", as: SetMatching.self),
            let copyServices = symbol("IOHIDEventSystemClientCopyServices", as: CopyServices.self),
            let copyProperty = symbol("IOHIDServiceClientCopyProperty", as: CopyProperty.self),
            let setProperty = symbol("IOHIDServiceClientSetProperty", as: SetProperty.self)
        else {
            return nil
        }
        return API(
            createClient: createClient,
            setMatching: setMatching,
            copyServices: copyServices,
            copyProperty: copyProperty,
            setProperty: setProperty
        )
    }
}
