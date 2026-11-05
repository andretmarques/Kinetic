import Foundation
import KineticDomain

/// Swaps Alt ⇄ Win on PC keyboards using macOS's own key remapping, which works everywhere at no runtime cost.
/// A swap outlives this process, so the swapped keyboards are kept on disk to clear them after a crash.
final class KeySwapper {
    private struct KeyboardIDs: Codable {
        var vendor: Int
        var product: Int
    }

    private static let swappedPairs: [(UInt64, UInt64)] = [
        (0x7000000E2, 0x7000000E3),
        (0x7000000E3, 0x7000000E2),
        (0x7000000E6, 0x7000000E7),
        (0x7000000E7, 0x7000000E6),
    ]

    private let storeURL: URL
    private let queue = DispatchQueue(label: "kinetic.hidutil", qos: .userInitiated)
    private var swapped: [String: KeyboardIDs]

    init(directory: URL) {
        storeURL = directory.appendingPathComponent("key-swaps.json")
        let data = try? Data(contentsOf: storeURL)
        swapped = data.flatMap { try? JSONDecoder().decode([String: KeyboardIDs].self, from: $0) } ?? [:]
    }

    func apply(config: KineticConfig, keyboards: [DeviceInfo], force: Bool) {
        for keyboard in keyboards where !keyboard.isApple {
            let isWanted = !config.paused && config.keyboards[keyboard.key]?.swapAltWin == true
            let isOn = swapped[keyboard.key] != nil

            if isWanted && (!isOn || force) {
                let ids = KeyboardIDs(vendor: keyboard.vendorID, product: keyboard.productID)
                send(swap: true, to: ids)
                swapped[keyboard.key] = ids
            } else if !isWanted && isOn {
                clear(keyboard.key)
            }
        }

        let visible = Set(keyboards.map(\.key))
        for key in swapped.keys where !visible.contains(key) && config.hiddenDevices.contains(key) {
            clear(key)
        }
        save()
    }

    func restore() {
        swapped.keys.forEach(clear)
        save()
        queue.sync {}
    }

    private func clear(_ key: String) {
        if let ids = swapped.removeValue(forKey: key) {
            send(swap: false, to: ids)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(swapped) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    private func send(swap: Bool, to ids: KeyboardIDs) {
        let mappings = swap ? Self.swappedPairs : []
        let mapping = mappings.map {
            ["HIDKeyboardModifierMappingSrc": $0.0, "HIDKeyboardModifierMappingDst": $0.1]
        }
        guard
            let matching = Self.json(["VendorID": ids.vendor, "ProductID": ids.product]),
            let setting = Self.json(["UserKeyMapping": mapping])
        else {
            return
        }

        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
            process.arguments = ["property", "--matching", matching, "--set", setting]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }

    private static func json(_ object: Any) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
