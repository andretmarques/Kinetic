public struct AgentStatus: Codable, Equatable, Sendable {
    public var eventTapActive: Bool
    public var accessibilityGranted: Bool
    public var inputMonitoringGranted: Bool
    public var devices: [DeviceInfo]
    public var fnLocked: Bool

    public init(
        eventTapActive: Bool = false,
        accessibilityGranted: Bool = false,
        inputMonitoringGranted: Bool = false,
        devices: [DeviceInfo] = [],
        fnLocked: Bool = false
    ) {
        self.eventTapActive = eventTapActive
        self.accessibilityGranted = accessibilityGranted
        self.inputMonitoringGranted = inputMonitoringGranted
        self.devices = devices
        self.fnLocked = fnLocked
    }
}

public enum Permission: String, Sendable {
    case accessibility, inputMonitoring
}
