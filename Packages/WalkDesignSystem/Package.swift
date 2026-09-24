// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WalkDesignSystem",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "WalkDesignSystem", targets: ["WalkDesignSystem"])
    ],
    targets: [
        .target(name: "WalkDesignSystem")
    ],
    swiftLanguageModes: [.v5]
)
