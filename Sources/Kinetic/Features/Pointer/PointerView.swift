import KineticDomain
import SwiftUI

struct PointerView: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        let mouse = store.state.selectedMouseKey
        let pointer = store.state.mouse.pointer

        Form {
            MouseProfileBanner()

            Section {
                LabeledContent("Speed") {
                    CommitSlider(
                        value: store.edit(\.mouse.pointer.speed) { .setPointerSpeed(mouse: mouse, $0) },
                        range: 1...20,
                        step: 1,
                        minimumSymbol: "tortoise",
                        maximumSymbol: "hare"
                    )
                }

                Picker("Acceleration", selection: store.edit(\.mouse.pointer.acceleration) { .setAcceleration(mouse: mouse, $0) }) {
                    ForEach(AccelerationMode.allCases, id: \.self) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if pointer.acceleration == .custom {
                    LabeledContent("Curve") {
                        CommitSlider(
                            value: store.edit(\.mouse.pointer.curve) { .setCurve(mouse: mouse, $0) },
                            range: 0...3,
                            step: 0.125,
                            format: "%.2f"
                        )
                    }
                }
            } header: {
                Text("Pointer")
            } footer: {
                Text(footer(for: pointer))
                    .foregroundStyle(.secondary)
            }

            Section("Try it") {
                PointerTryItArea()
            }

            Section {
                Button("Use macOS Defaults") {
                    store.send(.edit(.resetPointer(mouse: mouse)))
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Pointer")
    }

    private func footer(for pointer: PointerSettings) -> String {
        switch pointer.acceleration {
        case .off:
            let gain = String(format: "%.2f", PointerMath.linearGain(speed: pointer.speed))
            return "Off: the pointer moves the same distance however fast you move your hand. It's moving \(gain)× your mouse's raw movement. Speed 10 matches macOS's average speed, and about 16 is 1:1."
        case .system:
            return "macOS: small movements are precise and fast flicks travel further. Speed 10 is what macOS does by itself."
        case .custom:
            return "Custom: 0 is the gentlest curve and 3 is very aggressive. Speed 10 keeps your mouse's normal resolution."
        }
    }
}

private struct PointerTryItArea: View {
    @State private var hoverPoint: CGPoint?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.quaternary.opacity(0.4))
            ForEach(0..<5, id: \.self) { ring in
                Circle()
                    .strokeBorder(.secondary.opacity(0.25), lineWidth: 1)
                    .frame(width: CGFloat(24 + ring * 36))
            }
            Circle()
                .fill(.tint)
                .frame(width: 14)
            if let hoverPoint {
                Circle()
                    .fill(.tint.opacity(0.35))
                    .frame(width: 18)
                    .position(hoverPoint)
            }
        }
        .frame(height: 180)
        .onContinuousHover { phase in
            switch phase {
            case let .active(point): hoverPoint = point
            case .ended: hoverPoint = nil
            }
        }
    }
}
