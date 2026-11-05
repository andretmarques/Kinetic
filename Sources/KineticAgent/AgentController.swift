import ApplicationServices
import Foundation
import KineticDomain
import KineticInfrastructure

/// Connects the agent's store to the system: observations become intents, effects become system calls.
@MainActor
final class AgentController {
    private static let statusCheckInterval: TimeInterval = 10
    private static let reapplyDelay: TimeInterval = 1
    private static let replacementTimeout: TimeInterval = 3

    private let repository = ConfigRepository()
    private let store: Store<AgentReducer>
    private let actions = ActionRunner()
    private let tap: EventTap
    private let deviceMonitor = DeviceMonitor()
    private let pointer: PointerApplier
    private let keySwapper: KeySwapper
    private let wakeMonitor = WakeMonitor()
    private let menuBar: MenuBarModule?
    private let removalCheck = AppRemovalCheck()

    private var observers: [NSObjectProtocol] = []
    private var statusTimer: Timer?
    private var terminationSource: DispatchSourceSignal?

    init() {
        let config = repository.loadConfig()
        store = Store(initialState: AgentState(config: config))
        menuBar = config.showMenuBarIcon ? MenuBarModule() : nil
        tap = EventTap(actions: actions)
        pointer = PointerApplier(directory: repository.directory)
        keySwapper = KeySwapper(directory: repository.directory)
    }

    /// Never returns: the main thread goes to AppKit if the menu bar is loaded, or a plain run loop if not.
    func run() {
        store.effectHandler = { [weak self] effect in
            self?.handle(effect)
        }
        quitNormallyOnSIGTERM()
        observeAppRemoval()
        replaceOtherInstances()
        start()
        if let menuBar {
            menuBar.run()
        } else {
            RunLoop.main.run()
        }
    }

    private func start() {
        menuBar?.start { [weak self] command in
            self?.store.send(.menu(command))
        }
        tap.onStateChange = { [weak self] in
            Task { @MainActor in
                self?.observeStatus()
            }
        }
        deviceMonitor.onChange = { [weak self] devices in
            self?.store.send(.devicesChanged(devices))
        }

        observeMessages()
        deviceMonitor.start()
        wakeMonitor.onWake = { [weak self] in
            self?.store.send(.reapplyRequested)
        }
        wakeMonitor.start()
        tap.start()
        store.send(.started)
        observeStatus()
        startStatusTimer()
    }

    private func quit() {
        pointer.restore()
        keySwapper.restore()
        exit(EXIT_SUCCESS)
    }

    /// launchd only restarts the agent after a crash, so the normal exit this leads to stops it for good.
    private func observeAppRemoval() {
        if removalCheck.isAppRemoved {
            store.send(.appRemoved)
        }
    }

    /// launchd stops the agent with SIGTERM, and settings only get restored on a normal quit.
    private func quitNormallyOnSIGTERM() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.quit()
            }
        }
        source.resume()
        terminationSource = source
    }

    /// Two agents would mean two event taps, applying every remap twice. System Settings can start a
    /// second one through "Quit & Reopen". The newest wins, once the old one has restored settings.
    private func replaceOtherInstances() {
        let others = RunningProcesses.identifiers(named: KineticIdentifiers.agentExecutable).filter { $0 != getpid() }
        guard !others.isEmpty else { return }

        others.forEach { kill($0, SIGTERM) }
        let deadline = Date.now.addingTimeInterval(Self.replacementTimeout)
        while others.contains(where: { kill($0, 0) == 0 }) && Date.now < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        others.filter { kill($0, 0) == 0 }.forEach { kill($0, SIGKILL) }
    }

    /// AppKit can't be unloaded, and the icon setting decides whether it gets loaded at all,
    /// so changing it starts this same process over.
    private func relaunch() -> Never {
        if let path = Bundle.main.executablePath {
            var arguments: [UnsafeMutablePointer<CChar>?] = [strdup(path), nil]
            execv(path, &arguments)
        }
        exit(EXIT_FAILURE)
    }

    private func handle(_ effect: AgentEffect) {
        switch effect {
        case let .applySettings(config, keyboards, rules, force):
            pointer.apply(config: config, force: force)
            keySwapper.apply(config: config, keyboards: keyboards, force: force)
            tap.update(rules: rules)
        case .scheduleReapply:
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.reapplyDelay) { [weak self] in
                MainActor.assumeIsolated {
                    self?.store.send(.reapplyRequested)
                }
            }
        case let .publish(status):
            try? repository.saveStatus(status)
            AgentChannel.post(.statusChanged)
        case let .persist(edit):
            persist(edit)
        case .renderMenu:
            menuBar?.render(MenuBarModel(state: store.state))
        case let .requestPermission(permission):
            request(permission)
            observeStatus()
        case .openSettings:
            openSettingsApp()
        case .relaunch:
            relaunch()
        case .stop:
            quit()
        case .quit:
            AgentChannel.post(.agentQuitByUser)
            quit()
        }
    }

    private func persist(_ edit: ConfigEdit) {
        guard let config = try? repository.update(edit) else { return }
        AgentChannel.post(.configChanged)
        store.send(.configLoaded(config))
    }

    private func observeMessages() {
        observe(.configChanged) { controller, _ in
            controller.store.send(.configLoaded(controller.repository.loadConfig()))
        }
        observe(.reapplyRequested) { controller, _ in
            controller.store.send(.reapplyRequested)
        }
        observe(.statusRequested) { controller, _ in
            controller.observeStatus()
        }
        observe(.permissionRequested) { controller, payload in
            if let payload, let permission = Permission(rawValue: payload) {
                controller.store.send(.permissionRequested(permission))
            }
        }
        observe(.learnRenew) { controller, _ in
            controller.tap.renewLearnMode()
        }
        observe(.learnStop) { controller, _ in
            controller.tap.stopLearnMode()
        }
    }

    private func observe(_ message: AgentMessage, handler: @escaping @MainActor (AgentController, String?) -> Void) {
        observers.append(
            AgentChannel.observe(message) { [weak self] payload in
                if let self {
                    handler(self, payload)
                }
            }
        )
    }

    private func startStatusTimer() {
        let timer = Timer(timeInterval: Self.statusCheckInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.observeAppRemoval()
                self?.tap.reviveIfDisabled()
                self?.observeStatus()
            }
        }
        timer.tolerance = Self.statusCheckInterval / 2
        RunLoop.main.add(timer, forMode: .common)
        statusTimer = timer
    }

    private func observeStatus() {
        store.send(
            .statusObserved(
                accessibility: AXIsProcessTrusted(),
                inputMonitoring: CGPreflightListenEventAccess(),
                tapActive: tap.isActive,
                fnLocked: tap.isLocked
            )
        )
    }

    private func request(_ permission: Permission) {
        switch permission {
        case .accessibility:
            AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        case .inputMonitoring:
            CGRequestListenEventAccess()
        }
    }

    private func openSettingsApp() {
        let enclosingApp = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        SystemOpener.open(path: enclosingApp.path)
    }
}
