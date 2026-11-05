import Foundation

/// The notifications the settings app and the agent use to talk to each other.
public enum AgentMessage: String, Sendable {
    case configChanged
    case statusChanged
    case reapplyRequested = "reapply"
    case statusRequested
    case permissionRequested
    case learnRenew
    case learnStop
    case buttonPressed
    case agentQuitByUser

    fileprivate var name: Notification.Name {
        Notification.Name("com.andremarques.kinetic.\(rawValue)")
    }
}

public enum AgentChannel {
    public static func post(_ message: AgentMessage, payload: String? = nil) {
        DistributedNotificationCenter.default().postNotificationName(
            message.name,
            object: payload,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    public static func observe(
        _ message: AgentMessage,
        handler: @escaping @Sendable @MainActor (String?) -> Void
    ) -> NSObjectProtocol {
        DistributedNotificationCenter.default().addObserver(
            forName: message.name,
            object: nil,
            queue: .main
        ) { notification in
            let payload = notification.object as? String
            MainActor.assumeIsolated {
                handler(payload)
            }
        }
    }
}
