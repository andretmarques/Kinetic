public enum KineticAction: Codable, Equatable, Hashable, Sendable {
    case desktopPrevious, desktopNext, desktop(Int), missionControl, appExpose, showDesktop
    case notificationCenter, spotlight, lockScreen, screenshotArea, screenshotOptions, launchpad, dictation
    case back, forward, nextTab, previousTab, closeWindow, quitApp
    case middleClick, rightClick, doubleClick
    case playPause, nextTrack, previousTrack, volumeUp, volumeDown, mute, brightnessUp, brightnessDown
    case keyCombo(KeyCombo)
    case openApp(bundleID: String, name: String)
    case runShortcut(name: String)
    case none
    case passThrough

    public enum Category: String, CaseIterable, Sendable {
        case desktops = "Desktops", system = "System", navigation = "Navigation",
             mouse = "Mouse", media = "Media", custom = "Custom"
    }

    public static let catalog: [KineticAction] = [
        .desktopPrevious, .desktopNext, .missionControl, .appExpose, .showDesktop,
        .desktop(1), .desktop(2), .desktop(3), .desktop(4), .desktop(5), .desktop(6),
        .notificationCenter, .spotlight, .launchpad, .lockScreen, .screenshotArea, .screenshotOptions, .dictation,
        .back, .forward, .nextTab, .previousTab, .closeWindow, .quitApp,
        .middleClick, .rightClick, .doubleClick,
        .playPause, .nextTrack, .previousTrack, .volumeUp, .volumeDown, .mute, .brightnessUp, .brightnessDown,
        .none,
    ]

    /// A key press can't hold a mouse button down, so F-keys don't offer the click remaps.
    public static let functionKeyCatalog = catalog.filter { $0 != .middleClick && $0 != .rightClick } + [.passThrough]

    public var category: Category {
        switch self {
        case .desktopPrevious, .desktopNext, .desktop, .missionControl, .appExpose, .showDesktop: .desktops
        case .notificationCenter, .spotlight, .lockScreen, .screenshotArea, .screenshotOptions, .launchpad, .dictation: .system
        case .back, .forward, .nextTab, .previousTab, .closeWindow, .quitApp: .navigation
        case .middleClick, .rightClick, .doubleClick: .mouse
        case .playPause, .nextTrack, .previousTrack, .volumeUp, .volumeDown, .mute, .brightnessUp, .brightnessDown: .media
        case .keyCombo, .openApp, .runShortcut, .none, .passThrough: .custom
        }
    }

    public var title: String {
        switch self {
        case .desktopPrevious: "Previous Desktop"
        case .desktopNext: "Next Desktop"
        case .desktop(let n): "Desktop \(n)"
        case .missionControl: "Mission Control"
        case .appExpose: "App Exposé"
        case .showDesktop: "Show Desktop"
        case .notificationCenter: "Notification Center"
        case .spotlight: "Spotlight"
        case .lockScreen: "Lock Screen"
        case .screenshotArea: "Screenshot (area)"
        case .screenshotOptions: "Screenshot options"
        case .launchpad: "Launchpad / Apps"
        case .dictation: "Dictation"
        case .back: "Back"
        case .forward: "Forward"
        case .nextTab: "Next Tab"
        case .previousTab: "Previous Tab"
        case .closeWindow: "Close Window"
        case .quitApp: "Quit App"
        case .middleClick: "Middle Click"
        case .rightClick: "Right Click"
        case .doubleClick: "Double Click"
        case .playPause: "Play / Pause"
        case .nextTrack: "Next Track"
        case .previousTrack: "Previous Track"
        case .volumeUp: "Volume Up"
        case .volumeDown: "Volume Down"
        case .mute: "Mute"
        case .brightnessUp: "Brightness Up"
        case .brightnessDown: "Brightness Down"
        case .keyCombo(let k): "Shortcut \(k.display)"
        case .openApp(_, let name): "Open \(name)"
        case .runShortcut(let name): "Run “\(name)”"
        case .none: "Do Nothing"
        case .passThrough: "Standard F-key"
        }
    }

    public var symbol: String {
        switch self {
        case .desktopPrevious: "arrow.left.square"
        case .desktopNext: "arrow.right.square"
        case .desktop: "square.on.square"
        case .missionControl: "rectangle.3.group"
        case .appExpose: "rectangle.on.rectangle"
        case .showDesktop: "menubar.dock.rectangle"
        case .notificationCenter: "bell"
        case .spotlight: "magnifyingglass"
        case .lockScreen: "lock"
        case .screenshotArea, .screenshotOptions: "camera.viewfinder"
        case .launchpad: "square.grid.3x3"
        case .dictation: "mic"
        case .back: "chevron.left"
        case .forward: "chevron.right"
        case .nextTab, .previousTab: "rectangle.stack"
        case .closeWindow: "xmark.square"
        case .quitApp: "power"
        case .middleClick, .rightClick, .doubleClick: "computermouse"
        case .playPause: "playpause"
        case .nextTrack: "forward.end"
        case .previousTrack: "backward.end"
        case .volumeUp: "speaker.wave.3"
        case .volumeDown: "speaker.wave.1"
        case .mute: "speaker.slash"
        case .brightnessUp: "sun.max"
        case .brightnessDown: "sun.min"
        case .keyCombo: "keyboard"
        case .openApp: "app"
        case .runShortcut: "sparkles.rectangle.stack"
        case .none: "nosign"
        case .passThrough: "keyboard"
        }
    }
}
