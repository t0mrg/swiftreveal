// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiftReveal",
    platforms: [.macOS(.v14)],
    products: [.library(name: "SwiftRevealCore", targets: ["SwiftRevealCore"]), .executable(name: "SwiftReveal", targets: ["SwiftRevealApp"]), .executable(name: "SwiftRevealTool", targets: ["SwiftRevealTool"])],
    targets: [
        .target(name: "SwiftRevealCore", resources: [.copy("Resources")]),
        .executableTarget(name: "SwiftRevealApp", dependencies: ["SwiftRevealCore"]),
        .executableTarget(name: "SwiftRevealTool", dependencies: ["SwiftRevealCore"]),
        .testTarget(name: "SwiftRevealCoreTests", dependencies: ["SwiftRevealCore"])
    ]
)
