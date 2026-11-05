import Testing
@testable import KineticDomain

@Suite struct PointerMathTests {
    private let baseline = PointerMath.defaultResolution

    private func values(_ settings: PointerSettings, scaling: Double = 0.6875, linear: Bool = false, baseline: Int? = nil) -> PointerMath.Values {
        PointerMath.values(
            for: settings,
            systemScaling: scaling,
            systemLinear: linear,
            baselineResolution: baseline ?? self.baseline
        )
    }

    @Test func macOSModeUsesTheSystemValues() {
        #expect(values(PointerSettings()) == .init(linear: false, acceleration: 45056, resolution: baseline))
    }

    @Test func offAtSpeedTenMatchesMacOSAverage() {
        let expected = PointerMath.Values(linear: true, acceleration: PointerMath.fixed(0.42), resolution: baseline)
        #expect(values(.init(speed: 10, acceleration: .off)) == expected)
    }

    @Test func offRangeMatchesWhatTheUISays() {
        #expect(abs(PointerMath.linearGain(speed: 1) - 0.12) < 0.01)
        #expect(abs(PointerMath.linearGain(speed: 20) - 1.68) < 0.01)
        #expect(abs(PointerMath.linearGain(speed: 16) - 1) < 0.05)
    }

    @Test func offNeverUsesMinusOneBecauseThatIgnoresSpeed() {
        for speed in stride(from: 1.0, through: 20, by: 1) {
            #expect(values(.init(speed: speed, acceleration: .off)).acceleration > 0)
        }
    }

    @Test func everySpeedStepChangesTheGain() {
        let gains = (1...20).map { PointerMath.linearGain(speed: Double($0)) }
        #expect(gains == gains.sorted())
        #expect(Set(gains).count == 20)
    }

    @Test func fiveStepsDoubleTheSpeed() {
        #expect(abs(PointerMath.linearGain(speed: 15) / PointerMath.linearGain(speed: 10) - 2) < 0.001)
    }

    @Test func onACurveFasterMeansLowerResolution() {
        #expect(values(.init(speed: 5)).resolution > baseline)
        #expect(values(.init(speed: 20)).resolution < baseline)
        #expect(!values(.init(speed: 5)).linear)
    }

    @Test func speedTenKeepsADevicesOwnResolution() {
        #expect(values(.init(speed: 10), baseline: 1000 * 65536).resolution == 1000 * 65536)
    }

    @Test func macOSLinearSettingIsRespected() {
        let expected = PointerMath.Values(linear: true, acceleration: 2 * 65536, resolution: baseline)
        #expect(values(.init(speed: 10), scaling: 2, linear: true) == expected)
    }

    @Test func customCurveIsClamped() {
        #expect(values(.init(acceleration: .custom, curve: 9)).acceleration == 3 * 65536)
    }
}
