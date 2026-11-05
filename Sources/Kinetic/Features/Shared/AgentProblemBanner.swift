import KineticDomain
import SwiftUI

struct AgentProblemBanner: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        if let banner = store.state.banner {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(banner.message)
                    .font(.callout)
                    .lineLimit(2)
                Spacer()
                Button(banner.actionTitle) {
                    store.send(banner.intent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.orange.opacity(0.12))
        }
    }
}

private extension SettingsBanner {
    var message: String {
        switch self {
        case .turnedOff: "Kinetic is turned off, so your mouse and keyboard are as macOS has them."
        case .needsLoginItemApproval: "Kinetic Agent is turned off in Login Items, so nothing is being applied."
        case .notRunning: "Kinetic Agent isn't running, so nothing is being applied."
        case .needsPermissions: "Kinetic Agent still needs permission before mouse buttons, scrolling and F-keys work."
        }
    }

    var actionTitle: String {
        switch self {
        case .turnedOff: "Turn On"
        case .needsLoginItemApproval: "Open Login Items"
        case .notRunning: "Start Agent"
        case .needsPermissions: "Show Me"
        }
    }

    var intent: SettingsIntent {
        switch self {
        case .turnedOff: .setAgentEnabled(true)
        case .needsLoginItemApproval: .openLoginItems
        case .notRunning: .restartAgent
        case .needsPermissions: .presentOnboarding
        }
    }
}
