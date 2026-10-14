// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MapComponentCore",
    platforms: [.macOS(.v13), .iOS("18.0")],
    products: [.library(name: "MapComponentCore", targets: ["MapComponentCore"])],
    targets: [
        .target(name: "MapComponentCore"),
        .testTarget(name: "MapComponentCoreTests", dependencies: ["MapComponentCore"])
    ]
)
