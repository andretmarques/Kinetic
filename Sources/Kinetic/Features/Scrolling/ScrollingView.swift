import KineticDomain
import SwiftUI

struct ScrollingView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        let mouse = store.state.selectedMouseKey

        Form {
            MouseProfileBanner()

            Section {
                Toggle(
                    "Reverse vertical scrolling",
                    isOn: store.edit(\.mouse.scroll.reverseVertical) { .setReverseVertical(mouse: mouse, $0) }
                )
                Toggle(
                    "Reverse horizontal scrolling",
                    isOn: store.edit(\.mouse.scroll.reverseHorizontal) { .setReverseHorizontal(mouse: mouse, $0) }
                )
            } header: {
                Text("Direction")
            } footer: {
                Text("Only affects the mouse wheel. Your trackpad keeps the direction set in System Settings.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(
                    "Change scroll speed",
                    isOn: store.edit({ $0.mouse.scroll.linesPerNotch != nil }) {
                        .setLinesPerNotch(mouse: mouse, $0 ? 3 : nil)
                    }
                )
                if store.state.mouse.scroll.linesPerNotch != nil {
                    LabeledContent("Lines per notch") {
                        CommitSlider(
                            value: store.edit({ Double($0.mouse.scroll.linesPerNotch ?? 3) }) {
                                .setLinesPerNotch(mouse: mouse, Int($0))
                            },
                            range: 1...10,
                            step: 1
                        )
                    }
                }
            } header: {
                Text("Speed")
            } footer: {
                Text("3 is macOS's normal speed. 1 is a third of that, and 10 is over three times faster.")
                    .foregroundStyle(.secondary)
            }

            Section("Try it") {
                ScrollTryItArea()
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Scrolling")
    }
}

private struct ScrollTryItArea: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(1...30, id: \.self) { line in
                    HStack {
                        Text("Line \(line)")
                            .monospacedDigit()
                        Spacer()
                        Capsule()
                            .fill(.quaternary)
                            .frame(width: CGFloat(60 + (line * 37) % 180), height: 8)
                    }
                }
            }
            .padding()
        }
        .frame(height: 160)
        .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
    }
}
