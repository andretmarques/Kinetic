import Foundation

/// Opens apps through `/usr/bin/open`, which needs no AppKit. Failing beeps, like any other action.
enum SystemOpener {
    static func open(bundleIdentifier: String) {
        run(["-b", bundleIdentifier])
    }

    static func open(path: String) {
        run([path])
    }

    private static func run(_ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { finished in
            if finished.terminationStatus != 0 {
                DispatchQueue.main.async {
                    SystemBeep.play()
                }
            }
        }
        do {
            try process.run()
        } catch {
            SystemBeep.play()
        }
    }
}
