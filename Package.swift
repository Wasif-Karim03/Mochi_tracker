// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TypingCompanion",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "TypingCompanion", targets: ["TypingCompanion"])],
    targets: [
        .target(name: "CompanionCore"),
        .executableTarget(name: "TypingCompanion", dependencies: ["CompanionCore"], resources: [.copy("Resources")]),
        .testTarget(name: "CompanionCoreTests", dependencies: ["CompanionCore"])
    ],
    swiftLanguageModes: [.v5]
)
