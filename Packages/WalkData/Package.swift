// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WalkData",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "WalkData", targets: ["WalkData"])
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.9.1")
    ],
    targets: [
        .target(
            name: "WalkData",
            dependencies: [.product(name: "Alamofire", package: "Alamofire")]
        )
    ],
    swiftLanguageModes: [.v5]
)
