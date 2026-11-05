import Foundation
import KineticDomain

/// Loads the menu bar, the only part of the agent that needs AppKit, as a separate library.
/// With the icon turned off this never runs, so AppKit and its memory never enter the process.
@MainActor
final class MenuBarModule {
    private typealias CommandHandler = @convention(c) (UnsafePointer<CChar>) -> Void
    private typealias Start = @convention(c) (CommandHandler) -> Void
    private typealias Render = @convention(c) (UnsafePointer<CChar>) -> Void
    private typealias Run = @convention(c) () -> Void

    private static let libraryName = "libKineticMenuBar.dylib"
    private static var commandReceiver: ((MenuBarCommand) -> Void)?

    private let startModule: Start
    private let renderModule: Render
    private let runModule: Run
    private let encoder = JSONEncoder()

    init?() {
        guard
            let path = Bundle.main.privateFrameworksURL?.appendingPathComponent(Self.libraryName).path,
            let library = dlopen(path, RTLD_NOW | RTLD_LOCAL),
            let start = dlsym(library, "kinetic_menubar_start"),
            let render = dlsym(library, "kinetic_menubar_render"),
            let run = dlsym(library, "kinetic_menubar_run")
        else {
            NSLog("Kinetic: menu bar unavailable: %@", String(cString: dlerror()))
            return nil
        }
        startModule = unsafeBitCast(start, to: Start.self)
        renderModule = unsafeBitCast(render, to: Render.self)
        runModule = unsafeBitCast(run, to: Run.self)
    }

    func start(onCommand: @escaping (MenuBarCommand) -> Void) {
        Self.commandReceiver = onCommand
        startModule { json in
            let data = Data(String(cString: json).utf8)
            guard let command = try? JSONDecoder().decode(MenuBarCommand.self, from: data) else { return }
            MainActor.assumeIsolated {
                MenuBarModule.commandReceiver?(command)
            }
        }
    }

    func render(_ model: MenuBarModel) {
        guard let data = try? encoder.encode(model) else { return }
        String(decoding: data, as: UTF8.self).withCString { renderModule($0) }
    }

    /// Hands the main thread to AppKit. Never returns.
    func run() {
        runModule()
    }
}
