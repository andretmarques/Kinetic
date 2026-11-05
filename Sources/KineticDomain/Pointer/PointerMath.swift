import Foundation

/// Conversion from UI settings to HID values, based on measurements of real hardware:
/// - Linear mode gives the same gain at every hand speed, with the acceleration value as that gain.
/// - On a curve, resolution scales the speed, and a lower resolution also moves the curve.
public enum PointerMath {
    public struct Values: Equatable, Sendable {
        public var linear: Bool
        public var acceleration: Int
        public var resolution: Int

        public init(linear: Bool, acceleration: Int, resolution: Int) {
            self.linear = linear
            self.acceleration = acceleration
            self.resolution = resolution
        }
    }

    public static let macOSDefaultScaling = 0.6875
    public static let defaultResolution = 400 * 65536
    /// Average gain of macOS's default curve across hand speeds. Speed 10 is anchored to it.
    public static let macOSAverageGain = 0.42

    private static let speedRange = 1.0...20.0
    private static let stepsPerDoubling = 5.0
    private static let curveResolutionPower = 1.6

    public static func fixed(_ value: Double) -> Int {
        Int((value * 65536).rounded())
    }

    public static func speedFactor(speed: Double) -> Double {
        pow(2, (speed.clamped(to: speedRange) - 10) / stepsPerDoubling)
    }

    public static func linearGain(speed: Double) -> Double {
        macOSAverageGain * speedFactor(speed: speed)
    }

    public static func values(
        for settings: PointerSettings,
        systemScaling: Double,
        systemLinear: Bool,
        baselineResolution: Int
    ) -> Values {
        let factor = speedFactor(speed: settings.speed)
        let curvedResolution = Int((Double(baselineResolution) / pow(factor, 1 / curveResolutionPower)).rounded())

        switch settings.acceleration {
        case .off:
            return Values(
                linear: true,
                acceleration: fixed(linearGain(speed: settings.speed)),
                resolution: baselineResolution
            )
        case .system where systemLinear:
            return Values(
                linear: true,
                acceleration: fixed(max(systemScaling, 0) * factor),
                resolution: baselineResolution
            )
        case .system:
            return Values(linear: false, acceleration: fixed(systemScaling), resolution: curvedResolution)
        case .custom:
            return Values(
                linear: false,
                acceleration: fixed(settings.curve.clamped(to: 0...3)),
                resolution: curvedResolution
            )
        }
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
