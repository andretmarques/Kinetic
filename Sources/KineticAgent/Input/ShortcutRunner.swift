import Foundation

/// Runs Shortcuts.app shortcuts one at a time, so a stuck one can't pile up threads and processes.
final class ShortcutRunner: @unchecked Sendable {
    private static let timeout: TimeInterval = 60

    private let queue = DispatchQueue(label: "kinetic.shortcuts", qos: .userInitiated)

    func run(_ name: String) {
        queue.async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            process.arguments = ["run", name]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else {
                Self.beep()
                return
            }

            let terminator = DispatchWorkItem {
                if process.isRunning {
                    process.terminate()
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + Self.timeout, execute: terminator)
            process.waitUntilExit()
            terminator.cancel()

            if process.terminationStatus != 0 {
                Self.beep()
            }
        }
    }

    private static func beep() {
        DispatchQueue.main.async {
            SystemBeep.play()
        }
    }
}
