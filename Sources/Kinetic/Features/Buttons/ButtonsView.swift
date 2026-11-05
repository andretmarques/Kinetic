import KineticDomain
import SwiftUI

struct ButtonsView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        let state = store.state

        Form {
            MouseProfileBanner()

            Section {
                PressPrompt(button: state.highlightedButton, isListening: state.isListening)
            } footer: {
                Text("While this screen is open, pressing a mouse button only identifies it. Its action won't run until you leave.")
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(state.buttonRows, id: \.self) { button in
                    ButtonRow(
                        button: button,
                        action: actionBinding(for: button),
                        isHighlighted: state.highlightedButton == button
                    )
                }
            } header: {
                Text("Buttons")
            } footer: {
                Text("Left and right buttons can't be remapped. A button set to Default does what it normally does.")
                    .foregroundStyle(.secondary)
            }

            if usesDesktopNumberAction {
                Section {
                    Label(
                        "“Switch to Desktop 1–9” shortcuts are off by default in macOS. Turn them on in System Settings → Keyboard → Keyboard Shortcuts → Mission Control.",
                        systemImage: "info.circle"
                    )
                    .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Buttons")
        .onAppear {
            store.send(.buttonsScreenAppeared)
        }
        .onDisappear {
            store.send(.buttonsScreenDisappeared)
        }
    }

    private var usesDesktopNumberAction: Bool {
        store.state.mouse.buttons.values.contains { action in
            if case .desktop = action { true } else { false }
        }
    }

    private func actionBinding(for button: Int) -> Binding<KineticAction?> {
        let mouse = store.state.selectedMouseKey
        return store.edit({ $0.mouse.buttons[String(button)] }) {
            .setButtonAction(mouse: mouse, button: button, $0)
        }
    }
}

private struct PressPrompt: View {
    let button: Int?
    let isListening: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "computermouse.fill")
                .font(.system(size: 30, weight: .light))
                .symbolEffect(.bounce, value: button)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(button.map(MouseButtons.name) ?? "Press any button on your mouse…")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .animation(.smooth(duration: 0.25), value: button)
    }

    private var subtitle: String {
        if !isListening {
            return "Waiting for Kinetic Agent's permissions."
        }
        return button == nil ? "Its row will light up." : "Pick its action below."
    }
}

private struct ButtonRow: View {
    let button: Int
    @Binding var action: KineticAction?
    let isHighlighted: Bool

    var body: some View {
        LabeledContent {
            ActionPicker(selection: $action, defaultTitle: "Default")
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(isHighlighted ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: 8, height: 8)
                Text(MouseButtons.name(button))
                    .fontWeight(isHighlighted ? .semibold : .regular)
            }
        }
        .animation(.smooth(duration: 0.25), value: isHighlighted)
    }
}
