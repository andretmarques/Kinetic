import Darwin
import Foundation
import KineticDomain

public enum ConfigImportError: LocalizedError {
    case notKineticSettings
    case newerVersion(Int)

    public var errorDescription: String? {
        switch self {
        case .notKineticSettings:
            "This file isn't a Kinetic settings file."
        case let .newerVersion(version):
            "These settings came from a newer version of Kinetic (format \(version))."
        }
    }
}

/// Stores the settings shared by the app and the agent. Every write is a read-modify-write of the
/// latest file under a cross-process lock, so neither process can overwrite the other's change.
public struct ConfigRepository: Sendable {
    public let directory: URL

    private var configURL: URL { directory.appendingPathComponent("config.json") }
    private var statusURL: URL { directory.appendingPathComponent("status.json") }
    private var lockURL: URL { directory.appendingPathComponent(".config.lock") }
    private var backupURL: URL { directory.appendingPathComponent("config.corrupt.json") }

    public init(directory: URL = ConfigRepository.defaultDirectory) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public static var defaultDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Kinetic", isDirectory: true)
    }

    public func loadConfig() -> KineticConfig {
        guard let data = try? Data(contentsOf: configURL) else { return KineticConfig() }
        if let config = try? JSONDecoder().decode(KineticConfig.self, from: data) {
            return config
        }
        keepUnreadableConfig()
        return KineticConfig()
    }

    @discardableResult
    public func update(_ edit: ConfigEdit) throws -> KineticConfig {
        try withExclusiveLock {
            var config = loadConfig()
            edit.apply(to: &config)
            try Self.encoder.encode(config).write(to: configURL, options: .atomic)
            return config
        }
    }

    public func loadStatus() -> AgentStatus {
        guard
            let data = try? Data(contentsOf: statusURL),
            let status = try? JSONDecoder().decode(AgentStatus.self, from: data)
        else {
            return AgentStatus()
        }
        return status
    }

    public func saveStatus(_ status: AgentStatus) throws {
        try Self.encoder.encode(status).write(to: statusURL, options: .atomic)
    }

    public static func exportData(_ config: KineticConfig) throws -> Data {
        try encoder.encode(config)
    }

    public static func importConfig(from data: Data) throws -> KineticConfig {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let version = root["version"] as? Int,
            root["mice"] is [String: Any]
        else {
            throw ConfigImportError.notKineticSettings
        }
        guard version <= KineticConfig().version else {
            throw ConfigImportError.newerVersion(version)
        }
        return try JSONDecoder().decode(KineticConfig.self, from: data)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func keepUnreadableConfig() {
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.moveItem(at: configURL, to: backupURL)
    }

    private func withExclusiveLock<Result>(_ body: () throws -> Result) throws -> Result {
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, 0o644)
        guard descriptor >= 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        defer { close(descriptor) }
        flock(descriptor, LOCK_EX)
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}
