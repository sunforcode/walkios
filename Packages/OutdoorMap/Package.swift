// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OutdoorMap",
    platforms: [.iOS("18.0")],
    products: [.library(name: "OutdoorMap", targets: ["OutdoorMap"])],
    dependencies: [
        .package(path: "../MapComponentCore"),
        .package(url: "https://github.com/mapbox/mapbox-maps-ios.git", exact: "11.16.0")
    ],
    targets: [
        .target(name: "OutdoorMap", dependencies: ["MapComponentCore", .product(name: "MapboxMaps", package: "mapbox-maps-ios")]),
        .testTarget(name: "OutdoorMapTests", dependencies: ["OutdoorMap", "MapComponentCore", .product(name: "MapboxMaps", package: "mapbox-maps-ios")])
    ]
)
