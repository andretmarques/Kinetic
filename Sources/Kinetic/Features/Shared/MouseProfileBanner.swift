import KineticDomain
import SwiftUI

struct MouseProfileBanner: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        let state = store.state
        if state.selectedMouseKey != KineticConfig.allMiceKey {
            Section {
                if state.config.mice[state.selectedMouseKey] == nil {
                    Label(
                        "This mouse follows “All Mice”. Changing anything here gives it its own pointer, scrolling and button settings.",
                        systemImage: "link"
                    )
                    .font(.callout)
                } else {
                    HStack {
                        Label("This mouse has its own pointer, scrolling and button settings.", systemImage: "link.badge.plus")
                            .font(.callout)
                        Spacer()
                        Button("Follow “All Mice”") {
                            store.send(.edit(.removeMouseProfile(state.selectedMouseKey)))
                        }
                    }
                }
                if state.externalMice.count > 1 {
                    Label(
                        "With more than one mouse connected, scrolling and buttons use “All Mice”, because macOS doesn't say which mouse an event came from. Pointer speed still applies per mouse.",
                        systemImage: "info.circle"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}
