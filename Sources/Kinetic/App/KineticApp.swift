import AppKit
import KineticDomain
import KineticInfrastructure
import SwiftUI

@main
struct KineticApp: App {
    @NSApplicationDelegateAdaptor(KineticAppDelegate.self) private var appDelegate
    @State private var store: SettingsStore
    @State private var effects: SettingsEffectHandler

    init() {
        let repository = ConfigRepository()
        let store = SettingsStore(
            initialState: SettingsState(config: repository.loadConfig(), status: repository.loadStatus())
        )
        let effects = SettingsEffectHandler(store: store, repository: repository)
        store.effectHandler = { effects.handle($0) }
        _store = State(initialValue: store)
        _effects = State(initialValue: effects)
    }

    var body: some Scene {
        Window("Kinetic", id: "main") {
            RootView()
                .environment(store)
                .frame(minWidth: 760, minHeight: 520)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 620)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appInfo) {
                Button("Re-apply Settings") {
                    store.send(.reapply)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}

final class KineticAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
