import AppKit
import KineticDomain
import KineticInfrastructure
import ServiceManagement

/// Starts, stops and repairs the agent login item.
@MainActor
final class AgentService {
    private enum RelaunchKey {
        static let version = "repairRelaunchVersion"
        static let count = "repairRelaunchCount"
        static let lastAttempt = "repairRelaunchAt"
    }

    private static let maxRelaunchesPerVersion = 3
    private static let minimumRelaunchSpacing: TimeInterval = 40

    private let service = SMAppService.agent(plistName: KineticIdentifiers.agentPlist)
    private var launchdTarget: String { "gui/\(getuid())/\(KineticIdentifiers.agent)" }

    var isRunning: Bool {
        !RunningProcesses.identifiers(named: KineticIdentifiers.agentExecutable).isEmpty
    }

    var registration: AgentRegistration {
        switch service.status {
        case .enabled: .enabled
        case .requiresApproval: .requiresApproval
        case .notRegistered: .notRegistered
        default: .unavailable
        }
    }

    func ensureRunning() {
        guard service.status == .enabled else {
            try? service.register()
            return
        }
        if isRunning {
            adoptIfOutsideLaunchd()
        } else {
            kickstart(restarting: false)
        }
    }

    func setRegistered(_ isRegistered: Bool) throws {
        if isRegistered {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    func restart() {
        kickstart(restarting: true)
    }

    func registerAgain() async {
        try? await service.unregister()
        try? await Task.sleep(for: .seconds(1))
        try? service.register()
    }

    func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    /// Registering soon after an update can keep failing, while a fresh launch a little later works.
    func relaunchAppIfAllowed() -> Bool {
        let defaults = UserDefaults.standard
        let version = installedVersionStamp()
        if defaults.double(forKey: RelaunchKey.version) != version {
            defaults.set(version, forKey: RelaunchKey.version)
            defaults.set(0, forKey: RelaunchKey.count)
            defaults.set(0.0, forKey: RelaunchKey.lastAttempt)
        }

        let now = Date.now.timeIntervalSince1970
        let count = defaults.integer(forKey: RelaunchKey.count)
        let lastAttempt = defaults.double(forKey: RelaunchKey.lastAttempt)
        guard count < Self.maxRelaunchesPerVersion, now - lastAttempt >= Self.minimumRelaunchSpacing else {
            return false
        }
        defaults.set(count + 1, forKey: RelaunchKey.count)
        defaults.set(now, forKey: RelaunchKey.lastAttempt)

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
        return true
    }

    private func installedVersionStamp() -> TimeInterval {
        let attributes = Bundle.main.executablePath.flatMap {
            try? FileManager.default.attributesOfItem(atPath: $0)
        }
        return (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
    }

    private func kickstart(restarting: Bool) {
        let arguments = ["kickstart"] + (restarting ? ["-k"] : []) + [launchdTarget]
        Task.detached {
            _ = Self.runLaunchctl(arguments)
        }
    }

    /// After "Quit & Reopen" the agent runs outside launchd, so nothing would restart it after a crash.
    private func adoptIfOutsideLaunchd() {
        let target = launchdTarget
        Task.detached { [weak self] in
            let output = Self.runLaunchctl(["print", target])
            if !output.contains("state = running") {
                await self?.restart()
            }
        }
    }

    private nonisolated static func runLaunchctl(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return "" }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
