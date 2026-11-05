import KineticDomain
import SwiftUI

/// A button with a popover, because a standard menu picker can't center its text.
struct MouseDevicePicker: View {
    private struct Option: Identifiable {
        let id: String
        let title: String
    }

    @Environment(SettingsStore.self) private var store
    @State private var isShowingOptions = false

    var body: some View {
        Button {
            isShowingOptions.toggle()
        } label: {
            Text(selectedTitle)
                .lineLimit(1)
                .frame(minWidth: 150)
                .padding(.horizontal, 18)
                .overlay(alignment: .trailing) {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 2)
                }
                .contentShape(.rect)
        }
        .fixedSize()
        .accessibilityLabel("Mouse")
        .accessibilityValue(selectedTitle)
        .popover(isPresented: $isShowingOptions, arrowEdge: .bottom) {
            VStack(spacing: 2) {
                ForEach(options) { option in
                    row(for: option)
                }
            }
            .padding(6)
            .frame(minWidth: 220)
        }
    }

    private func row(for option: Option) -> some View {
        Button {
            store.send(.selectMouse(option.id))
            isShowingOptions = false
        } label: {
            Text(option.title)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.vertical, 5)
                .overlay(alignment: .leading) {
                    if option.id == store.state.selectedMouseKey {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundStyle(.tint)
                            .padding(.leading, 6)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var selectedTitle: String {
        options.first { $0.id == store.state.selectedMouseKey }?.title ?? "All Mice"
    }

    private var options: [Option] {
        let state = store.state
        let allMice = Option(id: KineticConfig.allMiceKey, title: "All Mice")
        let connected = state.externalMice.map { mouse in
            Option(id: mouse.key, title: state.config.mice[mouse.key] == nil ? mouse.name : "\(mouse.name) (own settings)")
        }
        let saved = state.savedMouseKeys.map { key in
            Option(id: key, title: "Unplugged mouse (\(key.replacingOccurrences(of: "mouse:", with: "")))")
        }
        return [allMice] + connected + saved
    }
}
