import Darwin

/// Tells the agent when its app has been trashed or deleted, since macOS keeps a login item running after that.
/// Moving the app to another folder, or replacing it with a new version, doesn't count.
public struct AppRemovalCheck: Sendable {
    private let launchPath: String?
    private var lastSampleWasRemoved = false

    public init() {
        launchPath = Self.currentExecutablePath()
    }

    public var isAppRemoved: Bool {
        Self.isRemoved(launchPath: launchPath, currentPath: Self.currentExecutablePath()) { access($0, F_OK) == 0 }
    }

    /// Replacing the app removes the old copy a moment before the new one is in place, so one sample can be wrong.
    /// shortcut: the 10 s timer's tolerance can put two samples about 5 s apart, so a slower replace still counts as removal; sample faster or compare bundle versions if that shows up.
    public mutating func isConfirmedRemoved() -> Bool {
        confirm(isAppRemoved)
    }

    mutating func confirm(_ sample: Bool) -> Bool {
        defer { lastSampleWasRemoved = sample }
        return sample && lastSampleWasRemoved
    }

    static func isRemoved(launchPath: String?, currentPath: String?, fileExists: (String) -> Bool) -> Bool {
        if let launchPath, !isInTrash(launchPath), fileExists(launchPath) {
            return false
        }
        guard let currentPath, fileExists(currentPath) else {
            return true
        }
        return isInTrash(currentPath)
    }

    private static func isInTrash(_ path: String) -> Bool {
        path.split(separator: "/").contains { $0 == ".Trash" || $0 == ".Trashes" }
    }

    /// The kernel follows a running executable when it moves, unlike the path it was launched with.
    private static func currentExecutablePath() -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_pidpath(getpid(), &buffer, UInt32(buffer.count)) > 0 else { return nil }
        return String(cString: buffer)
    }
}
