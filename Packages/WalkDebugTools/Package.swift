// swift-tools-version: 6.0
import PackageDescription

/// 调试适配层。仅开发依赖图（project.yml）声明本包；生产依赖图不得引用。
///
/// 依据 specs/README.md R-DEBUG：DebugSwift 只经本包进入 App，业务模块不依赖它。
/// 本包不依赖 WalkData / WalkDesignSystem / App，只接收 App 注入的只读快照与动作回调。
let package = Package(
    name: "WalkDebugTools",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "WalkDebugTools", targets: ["WalkDebugTools"])
    ],
    dependencies: [
        .package(url: "https://github.com/DebugSwift/DebugSwift.git", exact: "1.19.0")
    ],
    targets: [
        .target(name: "WalkDebugTools", dependencies: ["DebugSwift"])
    ],
    swiftLanguageModes: [.v5]
)
