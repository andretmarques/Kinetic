import Foundation
import Testing
@testable import KineticDomain

@Suite struct KineticConfigDecodingTests {
    private func decode(_ json: String) throws -> KineticConfig {
        try JSONDecoder().decode(KineticConfig.self, from: Data(json.utf8))
    }

    @Test func unknownActionLosesOnlyThatMapping() throws {
        let config = try decode(#"{"mice":{"*":{"buttons":{"3":{"desktopNext":{}},"4":{"bogus":{}}}}}}"#)
        #expect(config.mice["*"]?.buttons == ["3": .desktopNext])
    }

    @Test func outOfRangeValuesAreClamped() throws {
        let config = try decode(#"{"mice":{"*":{"pointer":{"speed":99999,"curve":-4},"scroll":{"linesPerNotch":100000}}}}"#)
        #expect(config.mice["*"]?.pointer.speed == 20)
        #expect(config.mice["*"]?.pointer.curve == 0)
        #expect(config.mice["*"]?.scroll.linesPerNotch == 10)
    }

    @Test func allMiceProfileAlwaysExists() throws {
        #expect(try decode(#"{"mice":{}}"#).mice["*"] != nil)
    }

    @Test func agentStaysOnUnlessTurnedOff() throws {
        #expect(try decode("{}").agentEnabled)
        #expect(try !decode(#"{"agentEnabled":false}"#).agentEnabled)
    }

    @Test func noDefaultFunctionKeyDependsOnAUserShortcut() {
        for key in 1...12 {
            if case .runShortcut = KeyboardSettings.defaultMacAction(for: key) {
                Issue.record("F\(key) depends on a shortcut")
            }
        }
    }

    @Test func f6StaysAFunctionKeyByDefault() {
        #expect(InputRules(config: KineticConfig(), devices: []).functionKeyActions[6] == .passThrough)
    }
}

@Suite struct ConfigEditTests {
    private let mouse = "mouse:046d:0001"

    private func applying(_ edit: ConfigEdit, to config: KineticConfig = KineticConfig()) -> KineticConfig {
        var result = config
        edit.apply(to: &result)
        return result
    }

    @Test func firstEditOfAMouseStartsFromAllMice() {
        var base = KineticConfig()
        base.mice["*"]?.scroll.reverseVertical = true
        let config = applying(.setPointerSpeed(mouse: mouse, 3), to: base)
        #expect(config.mice[mouse]?.pointer.speed == 3)
        #expect(config.mice[mouse]?.scroll.reverseVertical == true)
        #expect(config.mice["*"]?.pointer.speed == 10)
    }

    @Test func clearingAButtonRemovesTheMapping() {
        let mapped = applying(.setButtonAction(mouse: "*", button: 3, .mute))
        #expect(mapped.mice["*"]?.buttons["3"] == .mute)
        let cleared = applying(.setButtonAction(mouse: "*", button: 3, nil), to: mapped)
        #expect(cleared.mice["*"]?.buttons["3"] == nil)
    }

    @Test func hidingADeviceCanBeUndone() {
        let hidden = applying(.setDeviceHidden(key: mouse, true))
        #expect(hidden.hiddenDevices == [mouse])
        #expect(applying(.setDeviceHidden(key: mouse, false), to: hidden).hiddenDevices.isEmpty)
    }

    @Test func editsToDifferentFieldsBothSurvive() {
        let first = applying(.setPaused(true))
        let both = applying(.setFKeyMode(.standard), to: first)
        #expect(both.paused)
        #expect(both.keyboard.fKeyMode == .standard)
    }

    @Test func onboardingAppliesChoices() {
        let choices = OnboardingChoices(accelerationOff: true, reverseScroll: true, desktopButtons: true, keyboards: ["keyboard:1"])
        let config = applying(.completeOnboarding(choices))
        #expect(config.onboardingDone)
        #expect(config.mice["*"]?.pointer.acceleration == .off)
        #expect(config.mice["*"]?.buttons["3"] == .desktopPrevious)
        #expect(config.keyboards["keyboard:1"]?.swapAltWin == true)
    }
}
