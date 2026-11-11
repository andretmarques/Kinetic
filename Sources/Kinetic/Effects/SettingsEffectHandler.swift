import AppKit
import KineticDomain
import KineticInfrastructure
import UniformTypeIdentifiers

/// Performs what the reducer asks for, and reports what happens as new intents.
@MainActor
final class SettingsEffectHandler {
    private unowned let store: SettingsStore
    private let repository: ConfigRepository
    private let agent = AgentService()

    private var observers: [NSObjectProtocol] = []
    private var pollTask: Task<Void, Never>?
    private var learnTask: Task<Void, Never>?

    init(store: SettingsStore, repository: ConfigRepository) {
        self.store = store
        self.repository = repository
    }

    func handle(_ effect: SettingsEffect) {
        switch effect {
        case .startObserving:
            startObserving()
        case .ensureAgentRunning:
            agent.ensureRunning()
            reportAgentState()
        case let .persist(edit):
            persist(edit)
        case let .setRegistered(isRegistered):
            setRegistered(isRegistered)
        case .restartAgent:
            agent.restart()
        case let .repairAgent(mayRelaunch, mayRegister):
            repairAgent(mayRelaunch: mayRelaunch, mayRegister: mayRegister)
        case .openLoginItems:
            agent.openLoginItems()
        case let .requestPermission(permission):
            request(permission)
        case .bringAppForward:
            NSApp.activate()
        case .checkStatus:
            AgentChannel.post(.statusRequested)
        case .reapply:
            AgentChannel.post(.reapplyRequested)
        case .startLearning:
            startLearning()
        case .stopLearning:
            stopLearning()
        case let .clearHighlight(generation):
            clearHighlight(generation: generation)
        case let .exportSettings(config):
            export(config)
        case .importSettings:
            importSettings()
        case .loadShortcutNames:
            loadShortcutNames()
        }
    }

    private func startObserving() {
        observe(.configChanged) { [repository] store, _ in
            store.send(.configLoaded(repository.loadConfig()))
        }
        observe(.statusChanged) { [repository] store, _ in
            store.send(.statusLoaded(repository.loadStatus()))
        }
        observe(.agentQuitByUser) { store, _ in
            store.send(.agentQuitByUser)
        }
        observe(.buttonPressed) { store, payload in
            if let payload, let button = Int(payload) {
                store.send(.buttonPressed(button))
            }
        }

        store.send(.statusLoaded(repository.loadStatus()))
        reportAgentState()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                self?.reportAgentState()
            }
        }
    }

    private func observe(_ message: AgentMessage, handler: @escaping @MainActor (SettingsStore, String?) -> Void) {
        let store = store
        observers.append(
            AgentChannel.observe(message) { payload in
                handler(store, payload)
            }
        )
    }

    private func reportAgentState() {
        store.send(.agentObserved(isRunning: agent.isRunning, registration: agent.registration))
    }

    private func persist(_ edit: ConfigEdit) {
        do {
            let config = try repository.update(edit)
            AgentChannel.post(.configChanged)
            store.send(.configLoaded(config))
        } catch {
            store.send(.failed("Kinetic couldn't save your settings: \(error.localizedDescription)"))
        }
    }

    private func setRegistered(_ isRegistered: Bool) {
        do {
            try agent.setRegistered(isRegistered)
        } catch {
            store.send(.failed("Couldn't change Kinetic Agent: \(error.localizedDescription)"))
        }
        reportAgentState()
    }

    private func repairAgent(mayRelaunch: Bool, mayRegister: Bool) {
        let relaunchFailed = { [store] in store.send(.repairFinished(didRegister: false)) }
        if mayRelaunch && agent.relaunchAppIfAllowed(onFailure: relaunchFailed) {
            return
        }
        guard mayRegister else {
            store.send(.repairFinished(didRegister: false))
            return
        }
        Task {
            await agent.registerAgain()
            store.send(.repairFinished(didRegister: true))
            reportAgentState()
        }
    }

    private func request(_ permission: Permission) {
        AgentChannel.post(.permissionRequested, payload: permission.rawValue)
        let pane = switch permission {
        case .accessibility: "Privacy_Accessibility"
        case .inputMonitoring: "Privacy_ListenEvent"
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Learn mode expires unless renewed, so a crash here can never leave the mouse's side buttons dead.
    private func startLearning() {
        learnTask?.cancel()
        learnTask = Task {
            var isRenewing = false
            while !Task.isCancelled {
                if NSApp.isActive {
                    AgentChannel.post(.learnRenew)
                    isRenewing = true
                } else if isRenewing {
                    AgentChannel.post(.learnStop)
                    isRenewing = false
                }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopLearning() {
        learnTask?.cancel()
        learnTask = nil
        AgentChannel.post(.learnStop)
    }

    private func clearHighlight(generation: Int) {
        let store = store
        Task {
            try? await Task.sleep(for: .seconds(2))
            store.send(.highlightExpired(generation: generation))
        }
    }

    private func export(_ config: KineticConfig) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "Kinetic Settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ConfigRepository.exportData(config).write(to: url)
        } catch {
            store.send(.failed("Export failed: \(error.localizedDescription)"))
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            store.send(.imported(try ConfigRepository.importConfig(from: Data(contentsOf: url))))
        } catch let error as ConfigImportError {
            store.send(.failed(error.localizedDescription))
        } catch {
            store.send(.failed(ConfigImportError.notKineticSettings.localizedDescription))
        }
    }

    private func loadShortcutNames() {
        let store = store
        Task.detached {
            let names = Self.readShortcutNames()
            await store.send(.shortcutNamesLoaded(names))
        }
    }

    private nonisolated static func readShortcutNames() -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        process.arguments = ["list"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").map(String.init)
    }
}
