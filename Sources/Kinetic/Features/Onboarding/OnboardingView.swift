import AppKit
import KineticDomain
import SwiftUI

struct OnboardingView: View {
    private enum Step: CaseIterable {
        case permissions, setup
    }

    private static let pauseBeforeAsking: Duration = .seconds(0.8)
    private static let pauseBeforeSetup: Duration = .seconds(1.2)

    @Environment(SettingsStore.self) private var store
    @State private var step = Step.permissions
    @State private var accelerationOff = true
    @State private var reverseScroll = true
    @State private var desktopButtons = true
    @State private var chosenKeyboards: Set<String> = []
    @State private var didPresetKeyboards = false

    private var allGranted: Bool {
        store.state.accessibilityGranted && store.state.inputMonitoringGranted
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .permissions: permissionsStep
            case .setup: setupStep
            }
            footer
                .padding(20)
        }
        .frame(width: 540, height: 560)
        .animation(.smooth(duration: 0.3), value: step)
        .animation(.smooth(duration: 0.3), value: allGranted)
    }

    private var footer: some View {
        HStack {
            ForEach(Step.allCases, id: \.self) { item in
                Capsule()
                    .fill(item == step ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: item == step ? 22 : 8, height: 8)
            }
            Spacer()
            switch step {
            case .permissions:
                if allGranted {
                    Button("Continue") { step = .setup }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Skip for Now") { step = .setup }
                }
            case .setup:
                Button("Back") { step = .permissions }
                Button("Start Using Kinetic") { finish() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var permissionsStep: some View {
        let next = store.state.nextPermissionToRequest

        return VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 88, height: 88)
            VStack(spacing: 6) {
                Text("Welcome to Kinetic")
                    .font(.largeTitle.weight(.semibold))
                Text("Let's make your mouse and keyboard feel at home. First, macOS needs your OK for two things.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 12) {
                permissionRow(
                    .accessibility,
                    number: 1,
                    title: "Accessibility",
                    reason: "Lets Kinetic trigger Mission Control, desktops and shortcuts.",
                    isGranted: store.state.accessibilityGranted,
                    isCurrent: next == .accessibility
                )
                Divider()
                permissionRow(
                    .inputMonitoring,
                    number: 2,
                    title: "Input Monitoring",
                    reason: "Lets Kinetic see your mouse buttons, scroll wheel and F-keys.",
                    isGranted: store.state.inputMonitoringGranted,
                    isCurrent: next == .inputMonitoring
                )
            }
            .padding(16)
            .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 14))
            guidance(for: next)
                .font(.callout)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Label("It never records what you type and has no network code.", systemImage: "lock.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: next) {
            await askOrMoveOn(next: next)
        }
        .task {
            while !Task.isCancelled {
                store.send(.checkStatus)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    @ViewBuilder
    private func guidance(for next: Permission?) -> some View {
        switch next {
        case .accessibility:
            Text("In System Settings, turn on **Kinetic Agent**, then come back. This screen updates by itself.")
        case .inputMonitoring:
            Text("Now turn on **Kinetic Agent** in this list too. If macOS offers **Quit & Reopen**, choose it.")
        case nil:
            if allGranted {
                Label("You're all set.", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .fontWeight(.medium)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Getting ready… If this takes a while, check System Settings → General → Login Items.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func permissionRow(
        _ permission: Permission,
        number: Int,
        title: String,
        reason: String,
        isGranted: Bool,
        isCurrent: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "\(number).circle")
                .font(.title2)
                .foregroundStyle(isGranted ? AnyShapeStyle(.green) : isCurrent ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(isCurrent ? .semibold : .regular)
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isCurrent {
                Button("Open Settings") {
                    store.send(.requestPermission(permission))
                }
            }
        }
    }

    /// A moment to read the screen before each request. The reducer decides what gets asked, and only asks once.
    private func askOrMoveOn(next: Permission?) async {
        if next != nil {
            try? await Task.sleep(for: Self.pauseBeforeAsking)
            guard !Task.isCancelled else { return }
            store.send(.askNextPermission)
        } else if allGranted, !store.state.askedPermissions.isEmpty {
            store.send(.permissionsGranted)
            try? await Task.sleep(for: Self.pauseBeforeSetup)
            guard !Task.isCancelled else { return }
            step = .setup
        }
    }

    private var setupStep: some View {
        let keyboards = store.state.externalKeyboards.filter { !$0.isApple }

        return VStack(alignment: .leading, spacing: 14) {
            Text("Make it yours")
                .font(.title.weight(.semibold))
            Text("We've picked the usual fixes for PC gear. Turn off anything you don't want, and change it all later if you like.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Form {
                Section("All mice") {
                    Toggle("Turn pointer acceleration off", isOn: $accelerationOff)
                    Toggle("Reverse the scroll wheel", isOn: $reverseScroll)
                    Toggle("Side buttons switch desktops (instead of Back/Forward)", isOn: $desktopButtons)
                }
                if !keyboards.isEmpty {
                    Section("Swap Alt ⇄ Win and use Mac F-keys on") {
                        ForEach(keyboards) { keyboard in
                            keyboardToggle(for: keyboard)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !didPresetKeyboards else { return }
            didPresetKeyboards = true
            chosenKeyboards = Set(keyboards.filter { !$0.isCompound }.map(\.key))
        }
    }

    private func keyboardToggle(for keyboard: DeviceInfo) -> some View {
        Toggle(
            isOn: Binding(
                get: { chosenKeyboards.contains(keyboard.key) },
                set: { isChosen in
                    if isChosen {
                        chosenKeyboards.insert(keyboard.key)
                    } else {
                        chosenKeyboards.remove(keyboard.key)
                    }
                }
            )
        ) {
            VStack(alignment: .leading, spacing: 1) {
                Text(keyboard.name)
                if keyboard.isCompound {
                    Text("Also reports as a mouse, so tick it only if it's really a keyboard.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func finish() {
        store.send(
            .finishOnboarding(
                OnboardingChoices(
                    accelerationOff: accelerationOff,
                    reverseScroll: reverseScroll,
                    desktopButtons: desktopButtons,
                    keyboards: chosenKeyboards
                )
            )
        )
    }
}
