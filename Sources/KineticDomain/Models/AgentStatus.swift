public struct AgentStatus: Codable, Equatable, Sendable {
    public var eventTapActive: Bool
    public var accessibilityGranted: Bool
    public var inputMonitoringGranted: Bool
    public var devices: [DeviceInfo]
    public var fnLocked: Bool
    /// Whether an app holds macOS Secure Input, which hides every key press from the event tap.
    public var secureInputOn: Bool

    public init(
        eventTapActive: Bool = false,
        accessibilityGranted: Bool = false,
        inputMonitoringGranted: Bool = false,
        devices: [DeviceInfo] = [],
        fnLocked: Bool = false,
        secureInputOn: Bool = false
    ) {
        self.eventTapActive = eventTapActive
        self.accessibilityGranted = accessibilityGranted
        self.inputMonitoringGranted = inputMonitoringGranted
        self.devices = devices
        self.fnLocked = fnLocked
        self.secureInputOn = secureInputOn
    }
}

public enum Permission: String, Sendable {
    case accessibility, inputMonitoring
}
