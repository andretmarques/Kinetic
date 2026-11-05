// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kinetic",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "KineticMenuBar", type: .dynamic, targets: ["KineticMenuBar"]),
    ],
    targets: [
        .target(name: "KineticDomain"),
        .target(name: "KineticInfrastructure", dependencies: ["KineticDomain"]),
        .target(
            name: "KineticMenuBar",
            dependencies: ["KineticDomain"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "KineticAgent",
            dependencies: ["KineticDomain", "KineticInfrastructure"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Kinetic",
            dependencies: ["KineticDomain", "KineticInfrastructure"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(name: "KineticDomainTests", dependencies: ["KineticDomain"]),
        .testTarget(name: "KineticInfrastructureTests", dependencies: ["KineticInfrastructure"]),
    ]
)
