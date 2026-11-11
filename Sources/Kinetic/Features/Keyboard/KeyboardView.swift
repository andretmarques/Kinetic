import KineticDomain
import SwiftUI

struct KeyboardView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        let state = store.state
        let keyboards = state.externalKeyboards

        Form {
            if keyboards.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No external keyboard",
                        systemImage: "keyboard",
                        description: Text("Plug in a keyboard and it will show up here. Your Mac's built-in keyboard is never changed.")
                    )
                }
            }

            ForEach(keyboards) { keyboard in
                KeyboardSection(
                    keyboard: keyboard,
                    showsSwapNote: keyboard.id == keyboards.first { !$0.isApple }?.id
                )
            }

            if keyboards.contains(where: { state.config.keyboards[$0.key]?.macFunctionKeys == true }) {
                FunctionKeysSection()
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Keyboard")
    }
}

private struct KeyboardSection: View {
    @Environment(SettingsStore.self) private var store
    let keyboard: DeviceInfo
    let showsSwapNote: Bool

    var body: some View {
        let key = keyboard.key
        let settings = store.state.config.keyboards[key] ?? KeyboardDeviceSettings()

        Section {
            ModifierIllustration(isMacOrder: keyboard.isApple || settings.swapAltWin)

            if keyboard.isApple {
                Text("Apple keyboard – already in Mac order.")
                    .foregroundStyle(.secondary)
            } else {
                Toggle(
                    "Use Mac layout (swap Alt ⇄ Win)",
                    isOn: store.edit({ $0.config.keyboards[key]?.swapAltWin ?? false }) {
                        .setSwapAltWin(keyboard: key, $0)
                    }
                )
                Toggle(
                    "Mac-style F-keys (brightness, media, volume…)",
                    isOn: store.edit({ $0.config.keyboards[key]?.macFunctionKeys ?? false }) {
                        .setMacFunctionKeys(keyboard: key, $0)
                    }
                )
            }

            if keyboard.isCompound {
                HStack {
                    Text("This device also reports as a mouse. If it isn't a keyboard, hide it from this list.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Not a Keyboard") {
                        store.send(.edit(.setDeviceHidden(key: key, true)))
                    }
                }
            }
        } header: {
            Label(keyboard.name, systemImage: "keyboard")
        } footer: {
            if showsSwapNote {
                Text("The Alt ⇄ Win swap is applied by macOS itself, so it costs nothing and works everywhere, including password fields.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FunctionKeysSection: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        let state = store.state
        let substitute = state.config.keyboard.fnSubstitute

        Section {
            Picker("F-keys do", selection: store.edit(\.config.keyboard.fKeyMode) { .setFKeyMode($0) }) {
                ForEach(FKeyMode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("Hold for the other mode", selection: store.edit(\.config.keyboard.fnSubstitute) { .setFnSubstitute($0) }) {
                ForEach(FnSubstitute.allCases, id: \.self) { substitute in
                    Text(substitute.title).tag(substitute)
                }
            }

            FunctionKeyGrid()

            if state.status.fnLocked {
                Label("F-keys are flipped right now. Double-tap \(substitute.title) to undo it.", systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("F-keys")
        } footer: {
            Text(footer(for: substitute))
                .foregroundStyle(.secondary)
        }
    }

    private func footer(for substitute: FnSubstitute) -> String {
        let scope = "Applies to every keyboard, including Fn+F-keys on your Mac's own keyboard, because macOS doesn't say which keyboard a key came from."
        let reach = substitute == .none
            ? "Choose a key above to reach the other mode."
            : "The Fn key on PC keyboards never reaches macOS, so hold \(substitute.title) instead; double-tap it to flip the mode until you double-tap again, pause Kinetic, or the Mac-F-key keyboard disconnects."
        return "\(scope) \(reach) Click a key to change what it does."
    }
}

private struct ModifierIllustration: View {
    private struct Key: Identifiable {
        let id: String
        let label: String
        let caption: String
    }

    let isMacOrder: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(keys) { key in
                VStack(spacing: 2) {
                    Text(key.label)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                    if !key.caption.isEmpty {
                        Text(key.caption)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 72, height: 50)
                .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 10))
            }
            Text("Space")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 160, height: 50)
                .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 10))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .animation(.smooth(duration: 0.3), value: isMacOrder)
    }

    private var keys: [Key] {
        if isMacOrder {
            return [
                Key(id: "control", label: "⌃", caption: "control"),
                Key(id: "option", label: "⌥", caption: "option"),
                Key(id: "command", label: "⌘", caption: "command"),
            ]
        }
        return [
            Key(id: "control", label: "Ctrl", caption: ""),
            Key(id: "command", label: "⌘", caption: "win"),
            Key(id: "option", label: "⌥", caption: "alt"),
        ]
    }
}

private struct FunctionKeyGrid: View {
    private let columns = Array(repeating: GridItem(.flexible(minimum: 34), spacing: 5), count: 12)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(1...12, id: \.self) { key in
                FunctionKeyCell(key: key)
            }
        }
    }
}

private struct FunctionKeyCell: View {
    @Environment(SettingsStore.self) private var store
    let key: Int

    var body: some View {
        let keyboard = store.state.config.keyboard
        let action = keyboard.action(for: key)
        let isOverridden = keyboard.fKeyOverrides[String(key)] != nil

        ActionPicker(
            selection: store.edit({ $0.config.keyboard.fKeyOverrides[String(key)] }) {
                .setFKeyOverride(key: key, $0)
            },
            defaultTitle: "Default: \(KeyboardSettings.defaultMacAction(for: key).title)",
            extraActions: [.passThrough]
        ) {
            VStack(spacing: 4) {
                Image(systemName: action.symbol)
                    .font(.system(size: 14))
                    .foregroundStyle(isOverridden ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                    .frame(height: 18)
                Text("F\(key)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 8))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("F\(key): \(action.title)")
        .accessibilityLabel("F\(key): \(action.title)")
    }
}
