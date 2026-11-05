import AppKit
import KineticDomain
import SwiftUI

struct ShortcutRecorderSheet: View {
    let onRecord: (KeyCombo) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var combo: KeyCombo?

    var body: some View {
        VStack(spacing: 16) {
            Text("Press a key combination")
                .font(.headline)
            Text(combo?.display ?? "…")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .frame(width: 220, height: 64)
                .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 14))
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                Button("Use") {
                    if let combo {
                        onRecord(combo)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(combo == nil)
            }
        }
        .padding(24)
        .background(KeyCaptureView { combo = $0 })
    }
}

private struct KeyCaptureView: NSViewRepresentable {
    let onKey: (KeyCombo) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onKey = onKey
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {}

    final class CaptureView: NSView {
        var onKey: ((KeyCombo) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            report(event)
        }

        /// Without this, the menu bar would take combos like ⌘Q and ⌘W first.
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard event.type == .keyDown, window?.firstResponder === self else { return false }
            report(event)
            return true
        }

        private func report(_ event: NSEvent) {
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let pairs: [(NSEvent.ModifierFlags, UInt64)] = [
                (.shift, KeyCombo.shift),
                (.control, KeyCombo.control),
                (.option, KeyCombo.option),
                (.command, KeyCombo.command),
            ]
            let modifiers = pairs.reduce(UInt64(0)) { result, pair in
                flags.contains(pair.0) ? result | pair.1 : result
            }
            onKey?(KeyCombo(keyCode: event.keyCode, modifiers: modifiers))
        }
    }
}
