import AppKit
import KineticDomain

/// The menu bar icon and the panel it opens. The panel only exists while it's open,
/// so it costs no memory the rest of the time.
@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    var onCommand: ((MenuBarCommand) -> Void)?

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var popover: NSPopover?
    private var panel: MenuBarPanelView?
    private var model: MenuBarModel?
    private var clickMonitor: Any?
    private var appSwitchObserver: NSObjectProtocol?

    override init() {
        super.init()
        statusItem.button?.image = MenuBarIcon.make()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)
    }

    func render(_ model: MenuBarModel) {
        self.model = model
        statusItem.button?.appearsDisabled = model.health == .paused
        panel?.render(model)
    }

    func popoverDidClose(_ notification: Notification) {
        stopWatchingForDismissal()
        popover?.contentViewController = nil
        popover = nil
        panel = nil
    }

    @objc private func togglePanel() {
        if let popover {
            popover.performClose(nil)
            return
        }
        showPanel()
    }

    private func showPanel() {
        guard let button = statusItem.button else { return }

        let panel = MenuBarPanelView()
        panel.onCommand = { [weak self] command in
            self?.onCommand?(command)
        }
        panel.onClose = { [weak self] in
            self?.popover?.performClose(nil)
        }
        if let model {
            panel.render(model)
        }

        let viewController = NSViewController()
        viewController.view = panel
        viewController.preferredContentSize = MenuBarPanelView.size

        let popover = NSPopover()
        popover.contentViewController = viewController
        popover.contentSize = MenuBarPanelView.size
        popover.behavior = .transient
        popover.delegate = self

        self.panel = panel
        self.popover = popover

        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        viewController.view.window?.makeKey()
        watchForDismissal()
    }

    /// `.transient` only closes the popover while this app is active, and macOS doesn't have to
    /// activate a background agent. So clicks elsewhere and app switches are watched for directly.
    private func watchForDismissal() {
        stopWatchingForDismissal()
        let close: () -> Void = { [weak self] in
            MainActor.assumeIsolated {
                self?.popover?.performClose(nil)
            }
        }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { _ in
            close()
        }
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { _ in
            close()
        }
    }

    private func stopWatchingForDismissal() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        if let appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appSwitchObserver)
        }
        clickMonitor = nil
        appSwitchObserver = nil
    }
}
