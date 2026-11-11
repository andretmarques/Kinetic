import AppKit
import KineticDomain
import SwiftUI
import UniformTypeIdentifiers

/// One searchable picker for mouse buttons and F-keys. A nil selection means default behaviour.
struct ActionPicker<PickerLabel: View>: View {
    @Binding var selection: KineticAction?
    let defaultTitle: String
    var actions: [KineticAction] = KineticAction.catalog
    @ViewBuilder let label: () -> PickerLabel

    @Environment(SettingsStore.self) private var store
    @State private var isShowingMenu = false
    @State private var query = ""
    @State private var isRecording = false

    var body: some View {
        Button {
            isShowingMenu.toggle()
        } label: {
            label()
        }
        .popover(isPresented: $isShowingMenu, arrowEdge: .bottom) {
            menu
        }
        .sheet(isPresented: $isRecording) {
            ShortcutRecorderSheet { combo in
                selection = .keyCombo(combo)
            }
        }
    }

    private var menu: some View {
        VStack(spacing: 0) {
            TextField("Search actions", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(10)

            List {
                if matches(defaultTitle) {
                    actionRow(title: defaultTitle, symbol: "arrow.uturn.backward", isSelected: selection == nil) {
                        choose(nil)
                    }
                }
                ForEach(KineticAction.Category.allCases, id: \.self) { category in
                    section(for: category)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 300, height: 360)
        }
        .onDisappear {
            query = ""
        }
    }

    @ViewBuilder
    private func section(for category: KineticAction.Category) -> some View {
        let actions = filteredActions.filter { $0.category == category }
        if !actions.isEmpty || category == .custom {
            Section(category.rawValue) {
                ForEach(actions, id: \.self) { action in
                    actionRow(title: action.title, symbol: action.symbol, isSelected: selection == action) {
                        choose(action)
                    }
                }
                if category == .custom {
                    customRows
                }
            }
        }
    }

    @ViewBuilder
    private var customRows: some View {
        if matches("Keyboard Shortcut") {
            actionRow(title: "Keyboard Shortcut…", symbol: "keyboard", isSelected: false) {
                isShowingMenu = false
                isRecording = true
            }
        }
        if matches("Open App") {
            actionRow(title: "Open App…", symbol: "app", isSelected: false) {
                isShowingMenu = false
                chooseApp()
            }
        }
        if !store.state.shortcutNames.isEmpty && matches("Run Shortcut") {
            Menu {
                ForEach(store.state.shortcutNames, id: \.self) { name in
                    Button(name) {
                        choose(.runShortcut(name: name))
                    }
                }
            } label: {
                Label("Run Shortcut…", systemImage: "sparkles.rectangle.stack")
            }
        }
    }

    private func actionRow(title: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var filteredActions: [KineticAction] {
        actions.filter {
            matches($0.title) || matches($0.category.rawValue)
        }
    }

    private func matches(_ text: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || text.localizedCaseInsensitiveContains(trimmed)
    }

    private func choose(_ action: KineticAction?) {
        selection = action
        isShowingMenu = false
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard
            panel.runModal() == .OK,
            let url = panel.url,
            let bundle = Bundle(url: url),
            let bundleID = bundle.bundleIdentifier
        else {
            return
        }
        let info = bundle.infoDictionary
        let name = info?["CFBundleDisplayName"] as? String
            ?? info?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        selection = .openApp(bundleID: bundleID, name: name)
    }
}

extension ActionPicker where PickerLabel == ActionPickerLabel {
    init(selection: Binding<KineticAction?>, defaultTitle: String) {
        self.init(selection: selection, defaultTitle: defaultTitle) {
            ActionPickerLabel(selection: selection.wrappedValue, defaultTitle: defaultTitle)
        }
    }
}

struct ActionPickerLabel: View {
    let selection: KineticAction?
    let defaultTitle: String

    var body: some View {
        HStack(spacing: 6) {
            if let selection {
                Image(systemName: selection.symbol)
                    .foregroundStyle(.tint)
            }
            Text(selection?.title ?? defaultTitle)
                .lineLimit(1)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
