import KineticDomain
import SwiftUI

struct AgentStatusPill: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        let health = store.state.health
        HStack(spacing: 6) {
            Circle()
                .fill(health.color)
                .frame(width: 8, height: 8)
            Text(health.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
    }
}

private extension AgentHealth {
    var title: String {
        switch self {
        case .notRunning: "Agent not running"
        case .paused: "Paused"
        case .active: "Active"
        case .needsPermission: "Needs permission"
        }
    }

    var color: Color {
        switch self {
        case .notRunning: .red
        case .paused: .yellow
        case .active: .green
        case .needsPermission: .orange
        }
    }
}
