import Testing
@testable import KineticDomain

@Suite struct HIDKeyMappingTests {
    private let keyboard = DeviceInfo(kind: .keyboard, vendorID: 0x46d, productID: 1, name: "K", isApple: false, isBuiltIn: false)
    private let f11Usage: UInt64 = 0x7_0000_0044
    private let volumeDownUsage: UInt64 = 0xC_0000_00EA
    private let altWinPairs = 4

    private func config(swap: Bool = true, macKeys: Bool = true, mode: FKeyMode = .mac) -> KineticConfig {
        var config = KineticConfig()
        config.keyboards[keyboard.key] = KeyboardDeviceSettings(swapAltWin: swap, macFunctionKeys: macKeys)
        config.keyboard.fKeyMode = mode
        return config
    }

    private func pairs(_ config: KineticConfig, locked: Bool = false) -> [HIDKeyPair] {
        KeyboardMapping(device: keyboard, config: config, fnLocked: locked).pairs
    }

    @Test func macModeMapsEveryDefaultMediaKeyBesideTheSwap() {
        let mapped = pairs(config())
        // F1, F2 and F7–F12 have HID usages; F3–F6 stay with the event tap.
        #expect(mapped.count == altWinPairs + 8)
        #expect(mapped.contains(HIDKeyPair(source: f11Usage, destination: volumeDownUsage)))
    }

    @Test func lockOrStandardModeLeavesTheFunctionKeysAlone() {
        #expect(pairs(config(), locked: true).count == altWinPairs)
        #expect(pairs(config(mode: .standard)).count == altWinPairs)
        #expect(pairs(config(mode: .standard), locked: true).count == altWinPairs + 8)
    }

    @Test func pausedOrUnsetKeyboardsGetNoMapping() {
        var paused = config()
        paused.paused = true
        #expect(pairs(paused).isEmpty)
        #expect(pairs(config(swap: false, macKeys: false)).isEmpty)
        #expect(pairs(config(swap: false)).count == 8)
    }

    @Test func actionsWithoutAHIDUsageStayWithTheTap() {
        var custom = config(swap: false)
        custom.keyboard.fKeyOverrides["11"] = .desktopNext
        #expect(!pairs(custom).contains { $0.source == f11Usage })
    }

    @Test func mediaKeyTypesRoundTripToTheirActions() {
        let mapped: [KineticAction] = [.brightnessUp, .brightnessDown, .nextTrack, .previousTrack, .playPause, .mute, .volumeUp, .volumeDown]
        for action in mapped {
            #expect(action.hidUsage != nil)
            let types = (0...20).filter { KineticAction(mediaKeyType: $0) == action }
            #expect(!types.isEmpty, "\(action) has no media key type")
        }
    }

    // MARK: Holding the substitute on a HID-mapped key

    private let rightControl: UInt64 = KeyCombo.control | 0x2000
    private let volumeDownType = 1
    private let f11Code: UInt16 = 103

    private func context(locked: Bool = false) -> InputContext {
        InputContext(rules: InputRules(config: config(), devices: [keyboard]), isLearning: false, isLocked: locked)
    }

    private func holdSubstitute(_ router: inout InputRouter) {
        _ = router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControl, now: 1, context: context())
    }

    @Test func mediaKeyBecomesTheStandardFunctionKeyWhileTheSubstituteIsHeld() {
        var router = InputRouter()
        holdSubstitute(&router)
        let down = router.routeMediaKey(type: volumeDownType, isDown: true, flags: rightControl, context: context())
        #expect(down == .asFunctionKey(code: f11Code, isDown: true, flags: 0))

        _ = router.routeFlags(keyCode: KeyCodes.rightControl, flags: 0, now: 2, context: context())
        let up = router.routeMediaKey(type: volumeDownType, isDown: false, flags: 0, context: context())
        #expect(up == .asFunctionKey(code: f11Code, isDown: false, flags: 0))
    }

    @Test func mediaKeyPassesWithoutTheSubstituteOrWhileLocked() {
        var router = InputRouter()
        #expect(router.routeMediaKey(type: volumeDownType, isDown: true, flags: 0, context: context()) == .pass)
        #expect(router.routeMediaKey(type: volumeDownType, isDown: false, flags: 0, context: context()) == .pass)

        holdSubstitute(&router)
        // Locked means the HID mapping is off, so a media event here came from a real media key.
        #expect(router.routeMediaKey(type: volumeDownType, isDown: true, flags: rightControl, context: context(locked: true)) == .pass)
    }

    // MARK: Agent wiring

    @Test func flippingTheLockRewritesTheMapping() {
        var state = AgentState(config: config())
        state.devices = [keyboard]
        let effects = AgentReducer.reduce(
            &state,
            .statusObserved(accessibility: true, inputMonitoring: true, tapActive: true, fnLocked: true, secureInputOn: false)
        )
        let mappings = effects.compactMap { effect -> [KeyboardMapping]? in
            if case let .applySettings(_, keyboards, _, _) = effect { return keyboards }
            return nil
        }
        #expect(mappings.first?.first?.pairs.count == altWinPairs)
    }

    @Test func secureInputShowsInTheMenuAndStatus() {
        var state = AgentState(config: KineticConfig())
        _ = AgentReducer.reduce(
            &state,
            .statusObserved(accessibility: true, inputMonitoring: true, tapActive: true, fnLocked: false, secureInputOn: true)
        )
        #expect(state.status.secureInputOn)
        #expect(MenuBarModel(state: state).statusText == "Secure Input is on")
    }

    @Test func secureInputWarningOnlyPromisesMappedKeys() {
        #expect(config().secureInputWarning(fnLocked: false).contains("volume F-keys still work"))
        #expect(!config().secureInputWarning(fnLocked: true).contains("still work"))
        #expect(!config(mode: .standard).secureInputWarning(fnLocked: false).contains("still work"))
        var none = config()
        none.keyboard.fnSubstitute = .none
        #expect(!none.secureInputWarning(fnLocked: false).contains("None"))
    }

    @Test func releaseIsConvertedEvenIfTheSubstituteStopsApplying() {
        var router = InputRouter()
        holdSubstitute(&router)
        _ = router.routeMediaKey(type: volumeDownType, isDown: true, flags: rightControl, context: context())
        var paused = config()
        paused.paused = true
        let pausedContext = InputContext(rules: InputRules(config: paused, devices: [keyboard]), isLearning: false, isLocked: false)
        let up = router.routeMediaKey(type: volumeDownType, isDown: false, flags: 0, context: pausedContext)
        #expect(up == .asFunctionKey(code: f11Code, isDown: false, flags: 0))
    }

    @Test func aLostReleaseIsForgottenWhenTheTapComesBack() {
        var router = InputRouter()
        holdSubstitute(&router)
        _ = router.routeMediaKey(type: volumeDownType, isDown: true, flags: rightControl, context: context())
        router.tapWasReenabled()
        let plain = router.routeMediaKey(type: volumeDownType, isDown: true, flags: 0, context: context())
        #expect(plain == .pass)
    }

    @Test func aConvertedMediaKeyBreaksTheDoubleTap() {
        var router = InputRouter()
        _ = router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControl, now: 1, context: context())
        _ = router.routeMediaKey(type: volumeDownType, isDown: true, flags: rightControl, context: context())
        _ = router.routeFlags(keyCode: KeyCodes.rightControl, flags: 0, now: 1.1, context: context())
        let flipped = router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControl, now: 1.3, context: context())
        #expect(!flipped)
    }
}
