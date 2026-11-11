import Foundation
import Testing
@testable import KineticDomain

@Suite struct AgentReducerTests {
    private let keyboard = DeviceInfo(kind: .keyboard, vendorID: 1, productID: 1, name: "K", isApple: false, isBuiltIn: false)

    private func hasApply(_ effects: [AgentEffect], force: Bool) -> Bool {
        effects.contains { effect in
            if case let .applySettings(_, _, _, isForced) = effect {
                return isForced == force
            }
            return false
        }
    }

    @Test func startupForcesAFullApply() {
        var state = AgentState(config: KineticConfig())
        let effects = AgentReducer.reduce(&state, .started)
        #expect(hasApply(effects, force: true))
    }

    @Test func unchangedConfigDoesNothing() {
        var state = AgentState(config: KineticConfig())
        let effects = AgentReducer.reduce(&state, .configLoaded(KineticConfig()))
        #expect(effects.isEmpty)
    }

    @Test func changingTheMenuBarIconRelaunches() {
        var state = AgentState(config: KineticConfig())
        var config = KineticConfig()
        config.showMenuBarIcon.toggle()

        let effects = AgentReducer.reduce(&state, .configLoaded(config))

        #expect(effects == [.relaunch])
        #expect(state.config == config)
    }

    @Test func menuBarValuesSurviveCrossingToTheLibrary() throws {
        let model = MenuBarModel(state: AgentState(config: KineticConfig()))
        let decodedModel = try JSONDecoder().decode(MenuBarModel.self, from: JSONEncoder().encode(model))
        #expect(decodedModel == model)

        let command = MenuBarCommand.setPointerSpeed(7)
        let decodedCommand = try JSONDecoder().decode(MenuBarCommand.self, from: JSONEncoder().encode(command))
        #expect(decodedCommand == command)
    }

    @Test func newDevicesApplyPublishAndScheduleARetry() {
        var state = AgentState(config: KineticConfig())
        let effects = AgentReducer.reduce(&state, .devicesChanged([keyboard]))
        #expect(state.devices == [keyboard])
        #expect(hasApply(effects, force: false))
        #expect(effects.contains(.scheduleReapply))
        #expect(effects.contains(.publish(state.status)))
    }

    @Test func sameDevicesDoNothing() {
        var state = AgentState(config: KineticConfig())
        _ = AgentReducer.reduce(&state, .devicesChanged([keyboard]))
        let effects = AgentReducer.reduce(&state, .devicesChanged([keyboard]))
        #expect(effects.isEmpty)
    }

    @Test func statusIsOnlyPublishedWhenItChanges() {
        var state = AgentState(config: KineticConfig())
        let observed = AgentIntent.statusObserved(accessibility: true, inputMonitoring: true, tapActive: true, fnLocked: false)
        let effects = AgentReducer.reduce(&state, observed)
        #expect(effects.contains(.publish(state.status)))
        let secondEffects = AgentReducer.reduce(&state, observed)
        #expect(secondEffects.isEmpty)
    }

    @Test func wakeForcesAnApply() {
        var state = AgentState(config: KineticConfig())
        let effects = AgentReducer.reduce(&state, .reapplyRequested)
        #expect(hasApply(effects, force: true))
    }

    @Test func menuEditsChangeStateAndArePersisted() {
        var state = AgentState(config: KineticConfig())
        let effects = AgentReducer.reduce(&state, .menu(.togglePause))
        #expect(state.config.paused)
        #expect(effects.contains(.persist(.setPaused(true))))
    }

    @Test func removedAppStopsTheAgentWithoutCountingAsAUserQuit() {
        var state = AgentState(config: KineticConfig())
        #expect(AgentReducer.reduce(&state, .appRemoved) == [.stop])
    }

    @Test func menuEditsTheProfileInUse() {
        let mouse = DeviceInfo(kind: .mouse, vendorID: 1, productID: 2, name: "M", isApple: false, isBuiltIn: false)
        var config = KineticConfig()
        config.mice[mouse.key] = MouseProfile()
        var state = AgentState(config: config)
        _ = AgentReducer.reduce(&state, .devicesChanged([mouse]))
        _ = AgentReducer.reduce(&state, .menu(.setPointerSpeed(4)))
        #expect(state.config.mice[mouse.key]?.pointer.speed == 4)
        #expect(state.config.mice["*"]?.pointer.speed == 10)
    }

    private func attachedMice(acceleration: [AccelerationMode]) -> (AgentState, [DeviceInfo]) {
        let mice = (2...4).map {
            DeviceInfo(kind: .mouse, vendorID: 1, productID: $0, name: "M\($0)", isApple: false, isBuiltIn: false)
        }
        var config = KineticConfig()
        for (mouse, mode) in zip(mice, acceleration) {
            var profile = MouseProfile()
            profile.pointer.acceleration = mode
            config.mice[mouse.key] = profile
        }
        var state = AgentState(config: config)
        _ = AgentReducer.reduce(&state, .devicesChanged(mice))
        return (state, mice)
    }

    @Test func menuSpeedReachesEveryConnectedProfile() {
        var (state, mice) = attachedMice(acceleration: [.system, .system])
        let unattached = DeviceInfo.key(kind: .mouse, vendorID: 9, productID: 9)
        state.config.mice[unattached] = MouseProfile()
        let effects = AgentReducer.reduce(&state, .menu(.setPointerSpeed(4)))
        #expect(effects.contains(.persist(.setPointerSpeed(mouse: "*", 4))))
        #expect(effects.contains(.persist(.setPointerSpeed(mouse: mice[0].key, 4))))
        #expect(effects.contains(.persist(.setPointerSpeed(mouse: mice[1].key, 4))))
        #expect(state.config.mice["*"]?.pointer.speed == 4)
        #expect(state.config.mice[mice[0].key]?.pointer.speed == 4)
        #expect(state.config.mice[mice[1].key]?.pointer.speed == 4)
        #expect(state.config.mice[mice[2].key] == nil)
        #expect(state.config.mice[unattached]?.pointer.speed == 10)
    }

    @Test func menuAccelerationTurnsAllConnectedProfilesOff() {
        var (state, mice) = attachedMice(acceleration: [.system, .system])
        _ = AgentReducer.reduce(&state, .menu(.toggleAcceleration))
        #expect(state.config.mice["*"]?.pointer.acceleration == .off)
        #expect(state.config.mice[mice[0].key]?.pointer.acceleration == .off)
        #expect(state.config.mice[mice[1].key]?.pointer.acceleration == .off)
    }

    @Test func menuAccelerationTurnsAllConnectedProfilesOnTogether() {
        var (state, mice) = attachedMice(acceleration: [.off, .system])
        state.config.mice["*"] = MouseProfile(pointer: PointerSettings(acceleration: .off))
        state.config.mice[mice[1].key]?.pointer = PointerSettings(acceleration: .system, curve: 1.0)
        _ = AgentReducer.reduce(&state, .menu(.toggleAcceleration))
        #expect(state.config.mice["*"]?.pointer.acceleration == .system)
        #expect(state.config.mice[mice[0].key]?.pointer.acceleration == .system)
        #expect(state.config.mice[mice[1].key]?.pointer.acceleration == .system)
    }

    @Test func customSurvivesTheAccelerationToggle() {
        var config = KineticConfig()
        config.mice["*"] = MouseProfile(pointer: PointerSettings(acceleration: .custom, curve: 0.9))
        var state = AgentState(config: config)
        _ = AgentReducer.reduce(&state, .menu(.toggleAcceleration))
        #expect(state.config.mice["*"]?.pointer.acceleration == .off)
        _ = AgentReducer.reduce(&state, .menu(.toggleAcceleration))
        #expect(state.config.mice["*"]?.pointer.acceleration == .custom)
    }

    // Documents the known limit: "off" forgets the mode, so Custom at the default curve returns as macOS.
    @Test func customAtTheDefaultCurveTurnsBackOnAsMacOS() {
        var config = KineticConfig()
        config.mice["*"] = MouseProfile(pointer: PointerSettings(acceleration: .custom))
        var state = AgentState(config: config)
        _ = AgentReducer.reduce(&state, .menu(.toggleAcceleration))
        _ = AgentReducer.reduce(&state, .menu(.toggleAcceleration))
        #expect(state.config.mice["*"]?.pointer.acceleration == .system)
    }

    @Test func menuModelDescribesTheState() {
        var state = AgentState(config: KineticConfig())
        _ = AgentReducer.reduce(&state, .menu(.toggleAcceleration))
        let model = MenuBarModel(state: state)
        #expect(model.tiles.count == 6)
        #expect(model.statusText == "Needs permissions")
        #expect(model.showsGain)
        #expect(model.speedDescription(for: 10) == "10  ·  0.42×")
    }
}
