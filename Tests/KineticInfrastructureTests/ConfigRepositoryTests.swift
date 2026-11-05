import Foundation
import KineticDomain
import Testing
@testable import KineticInfrastructure

@Suite struct ConfigRepositoryTests {
    private func makeRepository() -> ConfigRepository {
        ConfigRepository(directory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
    }

    @Test func missingFileLoadsDefaults() {
        #expect(makeRepository().loadConfig() == KineticConfig())
    }

    @Test func updatesPersist() throws {
        let repository = makeRepository()
        try repository.update(.setPaused(true))
        #expect(repository.loadConfig().paused)
    }

    @Test func twoWritersDoNotOverwriteEachOther() throws {
        let settingsApp = makeRepository()
        let agent = ConfigRepository(directory: settingsApp.directory)
        try settingsApp.update(.setPaused(true))
        try agent.update(.setFKeyMode(.standard))
        let config = settingsApp.loadConfig()
        #expect(config.paused)
        #expect(config.keyboard.fKeyMode == .standard)
    }

    @Test func concurrentEditsAreAllKept() async throws {
        let repository = makeRepository()
        let keys = (0..<200).map { "keyboard:\($0)" }
        await withTaskGroup(of: Void.self) { group in
            for key in keys {
                group.addTask {
                    try? repository.update(.setDeviceHidden(key: key, true))
                }
            }
        }
        #expect(repository.loadConfig().hiddenDevices == Set(keys))
    }

    @Test func unreadableConfigIsKeptAsABackup() throws {
        let repository = makeRepository()
        let configURL = repository.directory.appendingPathComponent("config.json")
        try Data("not json".utf8).write(to: configURL)
        #expect(repository.loadConfig() == KineticConfig())
        let backup = repository.directory.appendingPathComponent("config.corrupt.json")
        #expect(FileManager.default.fileExists(atPath: backup.path))
    }

    @Test func statusRoundTrips() throws {
        let repository = makeRepository()
        let status = AgentStatus(eventTapActive: true, fnLocked: true)
        try repository.saveStatus(status)
        #expect(repository.loadStatus() == status)
    }

    @Test func importRejectsThingsThatAreNotKineticSettings() {
        for invalid in ["{}", #"{"foo":1}"#, "not json", "[]", #"{"version":1}"#] {
            #expect(throws: (any Error).self) {
                try ConfigRepository.importConfig(from: Data(invalid.utf8))
            }
        }
    }

    @Test func importRejectsNewerVersions() {
        #expect(throws: ConfigImportError.self) {
            try ConfigRepository.importConfig(from: Data(#"{"version":99,"mice":{}}"#.utf8))
        }
    }

    @Test func everyActionSurvivesExportAndImport() throws {
        var config = KineticConfig()
        let actions = KineticAction.catalog + [
            .passThrough,
            .keyCombo(KeyCombo(keyCode: 1, modifiers: KeyCombo.command)),
            .openApp(bundleID: "a.b", name: "B"),
            .runShortcut(name: "S"),
        ]
        for (index, action) in actions.enumerated() {
            config.mice["*"]?.buttons[String(index + 2)] = action
        }
        config.hiddenDevices = ["keyboard:046d:c54d"]
        let restored = try ConfigRepository.importConfig(from: ConfigRepository.exportData(config))
        #expect(restored == config)
    }
}
