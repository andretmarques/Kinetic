import Testing
@testable import KineticDomain

@Suite struct InputRouterTests {
    private let f1: UInt16 = 122
    private let f2: UInt16 = 120
    private let letterA: UInt16 = 0
    private let rightControlHeld = KeyCombo.control | 0x2000
    private let keyboard = DeviceInfo(kind: .keyboard, vendorID: 0x46d, productID: 1, name: "K", isApple: false, isBuiltIn: false)

    private func context(
        paused: Bool = false,
        substitute: FnSubstitute = .rightControl,
        button: KineticAction? = nil,
        learning: Bool = false,
        locked: Bool = false,
        keyboardPresent: Bool = true
    ) -> InputContext {
        var config = KineticConfig()
        config.paused = paused
        config.keyboards[keyboard.key] = KeyboardDeviceSettings(macFunctionKeys: true)
        config.keyboard.fnSubstitute = substitute
        for key in 1...12 {
            config.keyboard.fKeyOverrides[String(key)] = KineticAction.mute
        }
        if let button {
            config.mice["*"]?.buttons["3"] = button
        }
        return InputContext(
            rules: InputRules(config: config, devices: keyboardPresent ? [keyboard] : []),
            isLearning: learning,
            isLocked: locked
        )
    }

    @Test func functionKeyIsTakenOverAndRunsItsAction() {
        let router = RouterDriver()
        let result = router.routeKey(code: f2, isDown: true, isRepeat: false, flags: 0, context: context())
        #expect(result.route == .swallow)
        #expect(result.command == .run(.mute))
        #expect(router.release(f2, context()) == .swallow)
    }

    @Test func plainFunctionKeyArrivesWithoutTheSubstituteModifier() {
        let router = RouterDriver()
        #expect(router.press(f2, flags: rightControlHeld, context()) == .passWithFlags(0))
        #expect(router.release(f2, flags: rightControlHeld, context()) == .passWithFlags(0))
    }

    @Test func leftControlHeldAsWellKeepsControl() {
        let router = RouterDriver()
        let route = router.press(f2, flags: rightControlHeld | 0x0001, context())
        #expect(route == .passWithFlags(KeyCombo.control | 0x0001))
    }

    @Test func pausedFunctionKeyKeepsTheSubstituteModifier() {
        let router = RouterDriver()
        #expect(router.press(f2, flags: rightControlHeld, context(paused: true)) == .pass)
    }

    @Test func releaseFollowsThePressAfterPausing() {
        let router = RouterDriver()
        _ = router.press(f1, context())
        #expect(router.release(f1, context(paused: true)) == .swallow)
        #expect(router.press(f1, context(paused: true)) == .pass)
        #expect(router.release(f1, context(paused: true)) == .pass)
    }

    @Test func repeatsFollowTheFirstPress() {
        let router = RouterDriver()
        #expect(router.press(f1, flags: rightControlHeld, context()) != .swallow)
        #expect(router.press(f1, isRepeat: true, context()) == .pass)
        #expect(router.release(f1, context()) == .pass)
    }

    @Test func rightClickReleaseStaysRightAfterPausing() {
        let router = RouterDriver()
        #expect(router.routeButton(3, phase: .down, context: context(button: .rightClick)).route == .asRight)
        #expect(router.routeButton(3, phase: .dragged, context: context(paused: true)).route == .asRight)
        #expect(router.routeButton(3, phase: .up, context: context(paused: true)).route == .asRight)
    }

    @Test func swallowedPressSwallowsItsReleaseAfterTheMappingGoes() {
        let router = RouterDriver()
        #expect(router.routeButton(3, phase: .down, context: context(button: .mute)).route == .swallow)
        #expect(router.routeButton(3, phase: .up, context: context()).route == .swallow)
        #expect(router.routeButton(3, phase: .down, context: context()).route == .pass)
        #expect(router.routeButton(3, phase: .up, context: context()).route == .pass)
    }

    @Test func releaseWithNoPressPasses() {
        let router = RouterDriver()
        #expect(router.routeButton(4, phase: .up, context: context()).route == .pass)
    }

    @Test func learnModeReportsInsteadOfActingEvenWhilePaused() {
        let router = RouterDriver()
        let result = router.routeButton(4, phase: .down, context: context(paused: true, learning: true))
        #expect(result.route == .swallow)
        #expect(result.command == .reportButton(4))
        #expect(router.routeButton(4, phase: .up, context: context()).route == .swallow)
    }

    @Test func pressFromBeforeLearnModeStillPasses() {
        let router = RouterDriver()
        _ = router.routeButton(2, phase: .down, context: context())
        #expect(router.routeButton(2, phase: .up, context: context(learning: true)).route == .pass)
    }

    @Test func doubleTapFlipsTheMode() {
        let router = RouterDriver()
        let rules = context()
        #expect(!router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 10, context: rules))
        #expect(!router.routeFlags(keyCode: KeyCodes.rightControl, flags: 0, now: 10.05, context: rules))
        #expect(router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 10.1, context: rules))
    }

    @Test func releaseWhileTheKeyboardIsGoneDoesNotLeaveTheKeyDown() {
        let router = RouterDriver()
        _ = router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 10, context: context())
        _ = router.routeFlags(keyCode: KeyCodes.rightControl, flags: 0, now: 10.05, context: context(keyboardPresent: false))
        let rules = context()
        #expect(!router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 20, context: rules))
        #expect(!router.routeFlags(keyCode: KeyCodes.rightControl, flags: 0, now: 20.05, context: rules))
        #expect(router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 20.1, context: rules))
    }

    @Test func pausedDoubleTapDoesNotFlip() {
        let router = RouterDriver()
        let rules = context(paused: true)
        #expect(!router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 10, context: rules))
        #expect(!router.routeFlags(keyCode: KeyCodes.rightControl, flags: 0, now: 10.05, context: rules))
        #expect(!router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 10.1, context: rules))
    }

    @Test func slowTapsDoNotFlip() {
        let router = RouterDriver()
        let rules = context()
        _ = router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 10, context: rules)
        _ = router.routeFlags(keyCode: KeyCodes.rightControl, flags: 0, now: 10.1, context: rules)
        #expect(!router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 11, context: rules))
    }

    @Test func aShortcutBetweenPressesDoesNotFlip() {
        let router = RouterDriver()
        let rules = context()
        _ = router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 10, context: rules)
        _ = router.press(letterA, flags: rightControlHeld, rules)
        _ = router.routeFlags(keyCode: KeyCodes.rightControl, flags: 0, now: 10.05, context: rules)
        #expect(!router.routeFlags(keyCode: KeyCodes.rightControl, flags: rightControlHeld, now: 10.1, context: rules))
    }

    @Test func lockFlipsWhatAFunctionKeyDoes() {
        let router = RouterDriver()
        #expect(router.press(f1, context(locked: true)) == .pass)
    }

    @Test func otherKeysAlwaysPass() {
        let router = RouterDriver()
        #expect(router.press(letterA, context()) == .pass)
        #expect(router.release(letterA, context()) == .pass)
    }
}

/// Lets a mutating router be used inside `#expect`.
private final class RouterDriver {
    private var router = InputRouter()

    func press(_ code: UInt16, flags: UInt64 = 0, isRepeat: Bool = false, _ context: InputContext) -> KeyRoute {
        router.routeKey(code: code, isDown: true, isRepeat: isRepeat, flags: flags, context: context).route
    }

    func release(_ code: UInt16, flags: UInt64 = 0, _ context: InputContext) -> KeyRoute {
        router.routeKey(code: code, isDown: false, isRepeat: false, flags: flags, context: context).route
    }

    func routeKey(code: UInt16, isDown: Bool, isRepeat: Bool, flags: UInt64, context: InputContext) -> (route: KeyRoute, command: InputCommand?) {
        router.routeKey(code: code, isDown: isDown, isRepeat: isRepeat, flags: flags, context: context)
    }

    func routeButton(_ button: Int, phase: ButtonPhase, context: InputContext) -> (route: ButtonRoute, command: InputCommand?) {
        router.routeButton(button, phase: phase, context: context)
    }

    func routeFlags(keyCode: UInt16, flags: UInt64, now: Double, context: InputContext) -> Bool {
        router.routeFlags(keyCode: keyCode, flags: flags, now: now, context: context)
    }
}

@Suite struct InputRulesTests {
    private let keyboard = DeviceInfo(kind: .keyboard, vendorID: 0x46d, productID: 1, name: "K", isApple: false, isBuiltIn: false)
    private let mouse = DeviceInfo(kind: .mouse, vendorID: 0x46d, productID: 2, name: "M", isApple: false, isBuiltIn: false)
    private let otherMouse = DeviceInfo(kind: .mouse, vendorID: 0x46d, productID: 3, name: "N", isApple: false, isBuiltIn: false)

    @Test func functionKeysFollowTheEnabledKeyboard() {
        var config = KineticConfig()
        #expect(!InputRules(config: config, devices: [keyboard]).usesMacFunctionKeys)
        config.keyboards[keyboard.key] = KeyboardDeviceSettings(macFunctionKeys: true)
        #expect(InputRules(config: config, devices: [keyboard]).usesMacFunctionKeys)
        #expect(!InputRules(config: config, devices: []).usesMacFunctionKeys)
    }

    @Test func activeSubstituteNeedsEnabledRulesAMacKeyboardAndASubstitute() {
        var config = KineticConfig()
        config.keyboards[keyboard.key] = KeyboardDeviceSettings(macFunctionKeys: true)
        #expect(InputRules(config: config, devices: [keyboard]).activeSubstitute == KeyCodes.rightControl)
        #expect(InputRules(config: config, devices: []).activeSubstitute == nil)
        config.keyboard.fnSubstitute = .none
        #expect(InputRules(config: config, devices: [keyboard]).activeSubstitute == nil)
        config.keyboard.fnSubstitute = .rightControl
        config.paused = true
        #expect(InputRules(config: config, devices: [keyboard]).activeSubstitute == nil)
    }

    @Test func hiddenDevicesAreIgnored() {
        var config = KineticConfig()
        config.keyboards[keyboard.key] = KeyboardDeviceSettings(macFunctionKeys: true)
        config.mice[mouse.key] = MouseProfile(scroll: ScrollSettings(reverseVertical: true))
        config.hiddenDevices = [keyboard.key, mouse.key]
        let rules = InputRules(config: config, devices: [keyboard, mouse])
        #expect(!rules.usesMacFunctionKeys)
        #expect(!rules.reverseVertical)
    }

    @Test func aLoneMousesOwnProfileApplies() {
        var config = KineticConfig()
        config.mice[mouse.key] = MouseProfile(scroll: ScrollSettings(reverseVertical: true, linesPerNotch: 6), buttons: ["3": .mute])
        let rules = InputRules(config: config, devices: [mouse])
        #expect(rules.reverseVertical)
        #expect(rules.scrollMultiplier == 2)
        #expect(rules.buttonActions == [3: .mute])
    }

    @Test func oneMousesSettingsDoNotLeakOntoAnother() {
        var config = KineticConfig()
        config.mice[mouse.key] = MouseProfile(scroll: ScrollSettings(reverseVertical: true), buttons: ["3": .mute])
        let rules = InputRules(config: config, devices: [mouse, otherMouse])
        #expect(!rules.reverseVertical)
        #expect(rules.buttonActions.isEmpty)
    }

    @Test func pauseDisablesTheRules() {
        var config = KineticConfig()
        config.paused = true
        #expect(!InputRules(config: config, devices: []).isEnabled)
    }
}
