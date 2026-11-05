import KineticDomain
import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case pointer = "Pointer"
    case scrolling = "Scrolling"
    case buttons = "Buttons"
    case keyboard = "Keyboard"
    case general = "General"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .pointer: "cursorarrow.motionlines"
        case .scrolling: "arrow.up.and.down"
        case .buttons: "computermouse"
        case .keyboard: "keyboard"
        case .general: "gearshape"
        }
    }

    var editsMouse: Bool {
        self == .pointer || self == .scrolling || self == .buttons
    }
}

struct RootView: View {
    @Environment(SettingsStore.self) private var store
    @State private var section: SettingsSection? = .pointer
    @State private var hasStarted = false

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $section) { section in
                Label(section.rawValue, systemImage: section.symbol)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
            .safeAreaInset(edge: .bottom) {
                AgentStatusPill()
                    .padding(10)
            }
        } detail: {
            VStack(spacing: 0) {
                AgentProblemBanner()
                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                if section?.editsMouse ?? true {
                    MouseDevicePicker()
                }
            }
        }
        .sheet(isPresented: onboardingBinding) {
            OnboardingView()
                .environment(store)
        }
        .alert("Kinetic", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.state.alertMessage ?? "")
        }
        .onAppear {
            guard !hasStarted else { return }
            hasStarted = true
            store.send(.started)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch section ?? .pointer {
        case .pointer: PointerView()
        case .scrolling: ScrollingView()
        case .buttons: ButtonsView()
        case .keyboard: KeyboardView()
        case .general: GeneralView()
        }
    }

    private var onboardingBinding: Binding<Bool> {
        store.binding(\.isOnboardingPresented) { _ in .onboardingDismissed }
    }

    private var alertBinding: Binding<Bool> {
        store.binding({ $0.alertMessage != nil }) { _ in .alertDismissed }
    }
}
