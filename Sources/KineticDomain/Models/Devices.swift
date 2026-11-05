import Foundation

public enum DeviceKind: String, Codable, Sendable {
    case mouse, keyboard
}

public struct DeviceInfo: Codable, Equatable, Hashable, Identifiable, Sendable {
    public static let appleVendorID = 0x05AC

    public var kind: DeviceKind
    public var vendorID: Int
    public var productID: Int
    public var name: String
    public var isApple: Bool
    public var isBuiltIn: Bool
    /// The same hardware also reports as the other kind, so nothing is switched on for it automatically.
    public var isCompound: Bool

    public init(
        kind: DeviceKind,
        vendorID: Int,
        productID: Int,
        name: String,
        isApple: Bool,
        isBuiltIn: Bool,
        isCompound: Bool = false
    ) {
        self.kind = kind
        self.vendorID = vendorID
        self.productID = productID
        self.name = name
        self.isApple = isApple
        self.isBuiltIn = isBuiltIn
        self.isCompound = isCompound
    }

    public var id: String { key }
    public var key: String { Self.key(kind: kind, vendorID: vendorID, productID: productID) }

    public static func key(kind: DeviceKind, vendorID: Int, productID: Int) -> String {
        String(format: "%@:%04x:%04x", kind.rawValue, vendorID, productID)
    }
}

public enum MouseButtons {
    /// Left and right are excluded because remapping them would make the mouse unusable.
    public static let standard = [2, 3, 4]

    public static func name(_ number: Int) -> String {
        switch number {
        case 0: "Left button"
        case 1: "Right button"
        case 2: "Middle button"
        case 3: "Back (button 4)"
        case 4: "Forward (button 5)"
        default: "Button \(number + 1)"
        }
    }
}
