import Foundation
import KineticDomain

/// Writes each PC keyboard's `KeyboardMapping` (Alt ⇄ Win, Mac F-keys) into macOS's own key remapping,
/// which works below every event tap at no runtime cost. A mapping outlives this process, so the mapped
/// keyboards are kept on disk to clear them after a crash.
final class KeyMapper {
    private struct KeyboardIDs: Codable {
        var vendor: Int
        var product: Int
    }

    private let storeURL: URL
    private let queue = DispatchQueue(label: "kinetic.hidutil", qos: .userInitiated)
    private var mapped: [String: KeyboardIDs]
    private var sent: [String: [HIDKeyPair]] = [:]

    init(directory: URL) {
        // The file keeps its name from when only Alt ⇄ Win was mapped, so a crash before an update is still cleaned up.
        storeURL = directory.appendingPathComponent("key-swaps.json")
        let data = try? Data(contentsOf: storeURL)
        mapped = data.flatMap { try? JSONDecoder().decode([String: KeyboardIDs].self, from: $0) } ?? [:]
    }

    func apply(config: KineticConfig, keyboards: [KeyboardMapping], force: Bool) {
        for keyboard in keyboards where !keyboard.device.isApple {
            let key = keyboard.device.key
            if !keyboard.pairs.isEmpty {
                if force || sent[key] != keyboard.pairs {
                    let ids = KeyboardIDs(vendor: keyboard.device.vendorID, product: keyboard.device.productID)
                    send(keyboard.pairs, to: ids)
                    mapped[key] = ids
                    sent[key] = keyboard.pairs
                }
            } else if mapped[key] != nil {
                clear(key)
            }
        }

        let visible = Set(keyboards.map(\.device.key))
        for key in mapped.keys where !visible.contains(key) && config.hiddenDevices.contains(key) {
            clear(key)
        }
        save()
    }

    func restore() {
        mapped.keys.forEach(clear)
        save()
        queue.sync {}
    }

    private func clear(_ key: String) {
        sent[key] = nil
        if let ids = mapped.removeValue(forKey: key) {
            send([], to: ids)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(mapped) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    private func send(_ pairs: [HIDKeyPair], to ids: KeyboardIDs) {
        let mapping = pairs.map {
            ["HIDKeyboardModifierMappingSrc": $0.source, "HIDKeyboardModifierMappingDst": $0.destination]
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
