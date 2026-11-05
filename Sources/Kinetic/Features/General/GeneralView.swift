import KineticDomain
import SwiftUI

struct GeneralView: View {
    @Environment(SettingsStore.self) private var store
    @State private var isConfirmingReset = false

    var body: some View {
        Form {
            agentSection
            permissionsSection
            devicesSection
            settingsFileSection
        }
        .formStyle(.grouped)
        .navigationTitle("General")
        .confirmationDialog("Reset all Kinetic settings?", isPresented: $isConfirmingReset) {
            Button("Reset", role: .destructive) {
                store.send(.resetToDefaults)
            }
        } message: {
            Text("This removes every mouse profile, button mapping and keyboard setting. You can't undo it, but you can Export first.")
        }
    }

    private var agentSection: some View {
        Section {
            LabeledContent("Status") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(store.state.agentRunning ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(store.state.agentRunning ? "Running" : "Not running")
                    Button(store.state.agentRunning ? "Restart" : "Start") {
                        store.send(.restartAgent)
                    }
                }
            }
            Toggle(
                "Keep Kinetic on, including after login",
                isOn: store.binding(\.isAgentEnabled) { .setAgentEnabled($0) }
            )
            Toggle(
                "Pause all changes",
                isOn: store.edit(\.config.paused) { .setPaused($0) }
            )
            Toggle(
                "Show menu bar icon",
                isOn: store.edit(\.config.showMenuBarIcon) { .setShowMenuBarIcon($0) }
            )
        } header: {
            Text("Kinetic Agent")
        } footer: {
            Text("Turning Kinetic off or pausing it puts your mouse and keyboard back to how macOS has them. Hiding the menu bar icon uses less memory, because its interface never loads.")
                .foregroundStyle(.secondary)
        }
    }

    private var permissionsSection: some View {
        let state = store.state
        let allGranted = state.accessibilityGranted && state.inputMonitoringGranted

        return Section("Kinetic Agent's permissions") {
            PermissionRow(
                title: "Accessibility",
                isGranted: state.accessibilityGranted,
                reason: "Lets it trigger actions like Mission Control."
            ) {
                store.send(.requestPermission(.accessibility))
            }
            PermissionRow(
                title: "Input Monitoring",
                isGranted: state.inputMonitoringGranted,
                reason: "Lets it see scroll, button and F-key events."
            ) {
                store.send(.requestPermission(.inputMonitoring))
            }
            LabeledContent("Event handling", value: state.isListening ? "Active" : "Not active")
        }
        .task(id: allGranted) {
            guard !allGranted else { return }
            while !Task.isCancelled {
                store.send(.checkStatus)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private var devicesSection: some View {
        Section {
            if store.state.status.devices.isEmpty {
                Text("No devices reported yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.state.status.devices) { device in
                DeviceRow(device: device)
            }
        } header: {
            Text("Devices")
        } footer: {
            Text("Some keyboards, mice and wireless receivers report themselves as both. Turn off whichever one yours isn't.")
                .foregroundStyle(.secondary)
        }
    }

    private var settingsFileSection: some View {
        Section("Settings file") {
            HStack {
                Button("Export…") {
                    store.send(.exportSettings)
                }
                Button("Import…") {
                    store.send(.importSettings)
                }
                Spacer()
                Button("Reset to Defaults…", role: .destructive) {
                    isConfirmingReset = true
                }
            }
            Button("Show setup again") {
                store.send(.presentOnboarding)
            }
        }
    }
}

private struct DeviceRow: View {
    @Environment(SettingsStore.self) private var store
    let device: DeviceInfo

    var body: some View {
        if device.isBuiltIn {
            LabeledContent {
                Text("Built-in")
                    .foregroundStyle(.secondary)
            } label: {
                Label(device.name, systemImage: symbol)
            }
        } else {
            let key = device.key
            Toggle(
                isOn: store.edit({ !$0.config.hiddenDevices.contains(key) }) {
                    .setDeviceHidden(key: key, !$0)
                }
            ) {
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(device.name)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: symbol)
                }
            }
        }
    }

    private var symbol: String {
        device.kind == .mouse ? "computermouse" : "keyboard"
    }

    private var detail: String {
        let kind = device.kind == .mouse ? "Mouse" : "Keyboard"
        let ids = String(format: "%04X:%04X", device.vendorID, device.productID)
        guard device.isCompound else { return "\(kind) · \(ids)" }
        return "\(kind) · \(ids) · also reports as a \(device.kind == .mouse ? "keyboard" : "mouse")"
    }
}

private struct PermissionRow: View {
    let title: String
    let isGranted: Bool
    let reason: String
    let onOpenSettings: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isGranted ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isGranted {
                Button("Open System Settings", action: onOpenSettings)
            }
        }
        .animation(.smooth, value: isGranted)
    }
}
