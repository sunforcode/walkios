// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WalkDebugTools",
    platforms: [.iOS(.v18)],
    products: [.library(name: "WalkDebugTools", targets: ["WalkDebugTools"])],
    dependencies: [
        .package(url: "https://github.com/DebugSwift/DebugSwift.git", exact: "1.19.0")
    ],
    targets: [
        .target(name: "WalkDebugTools", dependencies: ["DebugSwift"])
    ],
    swiftLanguageModes: [.v5]
)
