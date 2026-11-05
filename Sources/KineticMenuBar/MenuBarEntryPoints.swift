import AppKit
import KineticDomain

// The agent and this library each link their own copy of KineticDomain, so values cross as JSON.

@MainActor private var controller: MenuBarController?

@_cdecl("kinetic_menubar_start")
public func start(commandHandler: @convention(c) (UnsafePointer<CChar>) -> Void) {
    MainActor.assumeIsolated {
        NSApplication.shared.setActivationPolicy(.accessory)

        let menuBar = MenuBarController()
        menuBar.onCommand = { command in
            guard let data = try? JSONEncoder().encode(command) else { return }
            String(decoding: data, as: UTF8.self).withCString { commandHandler($0) }
        }
        controller = menuBar
    }
}

@_cdecl("kinetic_menubar_render")
public func render(json: UnsafePointer<CChar>) {
    let data = Data(String(cString: json).utf8)
    guard let model = try? JSONDecoder().decode(MenuBarModel.self, from: data) else { return }
    MainActor.assumeIsolated {
        controller?.render(model)
    }
}

@_cdecl("kinetic_menubar_run")
public func run() {
    NSApplication.shared.run()
}
