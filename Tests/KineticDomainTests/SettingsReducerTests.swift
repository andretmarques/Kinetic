import Testing
@testable import KineticDomain

@Suite struct SettingsReducerTests {
    private let mouse = DeviceInfo(kind: .mouse, vendorID: 1, productID: 2, name: "M", isApple: false, isBuiltIn: false)

    private func makeState(config: KineticConfig = KineticConfig(), devices: [DeviceInfo] = []) -> SettingsState {
        SettingsState(config: config, status: AgentStatus(devices: devices))
    }

    @Test func setupAsksForPermissionsInOrderOnceTheAgentRuns() {
        var state = makeState()
        #expect(state.nextPermissionToRequest == nil)

        state.agentRunning = true
        #expect(state.nextPermissionToRequest == .accessibility)

        state.status.accessibilityGranted = true
        #expect(state.nextPermissionToRequest == .inputMonitoring)

        state.status.inputMonitoringGranted = true
        #expect(state.nextPermissionToRequest == nil)
    }

    @Test func setupAsksForEachPermissionOnlyOnce() {
        var state = makeState()
        state.agentRunning = true
        #expect(SettingsReducer.reduce(&state, .askNextPermission) == [.requestPermission(.accessibility)])
        #expect(SettingsReducer.reduce(&state, .askNextPermission).isEmpty)

        state.status.accessibilityGranted = true
        #expect(SettingsReducer.reduce(&state, .askNextPermission) == [.requestPermission(.inputMonitoring)])
    }

    @Test func setupOnlyBringsTheAppBackAfterAsking() {
        var state = makeState()
        #expect(SettingsReducer.reduce(&state, .permissionsGranted).isEmpty)

        state.agentRunning = true
        _ = SettingsReducer.reduce(&state, .askNextPermission)
        #expect(SettingsReducer.reduce(&state, .permissionsGranted) == [.bringAppForward])
    }

    @Test func dismissingSetupForgetsWhatItAsked() {
        var state = makeState()
        state.agentRunning = true
        _ = SettingsReducer.reduce(&state, .askNextPermission)
        _ = SettingsReducer.reduce(&state, .onboardingDismissed)
        #expect(state.askedPermissions.isEmpty)
    }

    @Test func setupDoesNotAskForInputMonitoringWhenTheTapAlreadyRuns() {
        var state = makeState()
        state.agentRunning = true
        state.status.accessibilityGranted = true
        state.status.eventTapActive = true
        #expect(state.nextPermissionToRequest == nil)
    }

    @Test func firstLaunchShowsOnboardingAndStartsTheAgent() {
        var state = makeState()
        let effects = SettingsReducer.reduce(&state, .started)
        #expect(state.isOnboardingPresented)
        #expect(effects.contains(.ensureAgentRunning))
    }

    @Test func aTurnedOffAgentStaysOffWhenReopening() {
        var config = KineticConfig()
        config.agentEnabled = false
        var state = makeState(config: config)
        let effects = SettingsReducer.reduce(&state, .started)
        #expect(!effects.contains(.ensureAgentRunning))
        #expect(state.banner == .turnedOff)
    }

    @Test func editsChangeStateAndArePersisted() {
        var state = makeState()
        let effects = SettingsReducer.reduce(&state, .edit(.setPaused(true)))
        #expect(state.config.paused)
        #expect(effects == [.persist(.setPaused(true))])
    }

    @Test func showingSetupAgainNeverOverwritesSettings() {
        var config = KineticConfig()
        config.onboardingDone = true
        var state = makeState(config: config)
        let choices = OnboardingChoices(accelerationOff: true, reverseScroll: true, desktopButtons: true, keyboards: [])
        _ = SettingsReducer.reduce(&state, .finishOnboarding(choices))
        #expect(state.config.mice["*"]?.pointer.acceleration == .system)
        #expect(!state.isOnboardingPresented)
    }

    @Test func selectionFallsBackWhenTheMouseGoesAway() {
        var state = makeState(devices: [mouse])
        _ = SettingsReducer.reduce(&state, .selectMouse(mouse.key))
        #expect(state.selectedMouseKey == mouse.key)
        _ = SettingsReducer.reduce(&state, .statusLoaded(AgentStatus()))
        #expect(state.selectedMouseKey == KineticConfig.allMiceKey)
    }

    @Test func selectionStaysForAnUnpluggedMouseWithItsOwnProfile() {
        var config = KineticConfig()
        config.mice[mouse.key] = MouseProfile()
        var state = makeState(config: config, devices: [mouse])
        _ = SettingsReducer.reduce(&state, .selectMouse(mouse.key))
        _ = SettingsReducer.reduce(&state, .statusLoaded(AgentStatus()))
        #expect(state.selectedMouseKey == mouse.key)
        #expect(state.savedMouseKeys == [mouse.key])
    }

    @Test func hidingTheSelectedMouseClearsTheSelection() {
        var state = makeState(devices: [mouse])
        _ = SettingsReducer.reduce(&state, .selectMouse(mouse.key))
        _ = SettingsReducer.reduce(&state, .edit(.setDeviceHidden(key: mouse.key, true)))
        #expect(state.selectedMouseKey == KineticConfig.allMiceKey)
    }

    @Test func staleStatusIsNotShownWhileTheAgentIsDown() {
        var state = makeState()
        _ = SettingsReducer.reduce(
            &state,
            .statusLoaded(AgentStatus(eventTapActive: true, accessibilityGranted: true, inputMonitoringGranted: true))
        )
        #expect(!state.isListening)
        #expect(!state.accessibilityGranted)
        #expect(state.health == .notRunning)
    }

    @Test func aRunningTapCountsAsInputMonitoring() {
        var state = makeState()
        state.agentRunning = true
        state.status = AgentStatus(eventTapActive: true, accessibilityGranted: true, inputMonitoringGranted: false)
        #expect(state.inputMonitoringGranted)
        #expect(state.banner == nil)
    }

    @Test func buttonHighlightOnlyClearsForTheLatestPress() {
        var state = makeState()
        _ = SettingsReducer.reduce(&state, .buttonPressed(3))
        let first = state.highlightGeneration
        _ = SettingsReducer.reduce(&state, .buttonPressed(4))
        _ = SettingsReducer.reduce(&state, .highlightExpired(generation: first))
        #expect(state.highlightedButton == 4)
        _ = SettingsReducer.reduce(&state, .highlightExpired(generation: state.highlightGeneration))
        #expect(state.highlightedButton == nil)
        #expect(state.buttonRows.contains(4))
    }

    @Test func restartingAnUnregisteredAgentRegistersIt() {
        var state = makeState()
        let effects = SettingsReducer.reduce(&state, .restartAgent)
        #expect(effects.contains(.setRegistered(true)))
    }
}

@Suite struct AgentRecoveryTests {
    private func observeDown(_ state: inout SettingsState) -> [SettingsEffect] {
        SettingsReducer.reduce(&state, .agentObserved(isRunning: false, registration: .enabled))
    }

    @Test func repairStartsAfterRepeatedDownPolls() {
        var state = SettingsState(config: KineticConfig(), status: AgentStatus())
        let effects = observeDown(&state)
        #expect(effects.isEmpty)
        let secondEffects = observeDown(&state)
        #expect(secondEffects.isEmpty)
        let thirdEffects = observeDown(&state)
        #expect(thirdEffects == [.repairAgent(mayRelaunch: false, mayRegister: true)])
    }

    @Test func aFailedRegistrationAllowsARelaunch() {
        var state = SettingsState(config: KineticConfig(), status: AgentStatus())
        for _ in 1...3 {
            _ = observeDown(&state)
        }
        _ = SettingsReducer.reduce(&state, .repairFinished(didRegister: true))
        for _ in 1...2 {
            _ = observeDown(&state)
        }
        let effects = observeDown(&state)
        #expect(effects == [.repairAgent(mayRelaunch: true, mayRegister: true)])
    }

    @Test func onlyOneRepairRunsAtATime() {
        var state = SettingsState(config: KineticConfig(), status: AgentStatus())
        for _ in 1...3 {
            _ = observeDown(&state)
        }
        let effects = observeDown(&state)
        #expect(effects.isEmpty)
    }

    @Test func aQuitByTheUserIsNotRepaired() {
        var state = SettingsState(config: KineticConfig(), status: AgentStatus())
        _ = SettingsReducer.reduce(&state, .agentQuitByUser)
        for _ in 1...5 {
            let effects = observeDown(&state)
            #expect(effects.isEmpty)
        }
    }

    @Test func recoveryResetsOnceTheAgentIsBack() {
        var state = SettingsState(config: KineticConfig(), status: AgentStatus())
        _ = SettingsReducer.reduce(&state, .agentQuitByUser)
        _ = SettingsReducer.reduce(&state, .agentObserved(isRunning: true, registration: .enabled))
        #expect(state.recovery == AgentRecovery())
    }
}
