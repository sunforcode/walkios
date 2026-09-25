import XCTest

/// W6：R-DEP 依赖方向的汇总检查。
///
/// 已有专项守卫：Feature 之间与 Feature→App（FeatureBoundaryTests）、调试工具边界（DebugToolsBoundaryTests）、
/// 设计系统命名（DesignSystemBoundaryTests）。本文件补齐剩余依赖方向，只检查禁止依赖，
/// 不绑定局部函数名或完整源码字符串。
final class ArchitectureDependencyTests: XCTestCase {

    /// WalkData 只依赖 Foundation 族与 Alamofire，不依赖 App、Feature、设计系统或 UI 框架。
    func testWalkDataDependsOnlyOnAllowedModules() throws {
        let allowed: Set<String> = ["Foundation", "Alamofire", "CryptoKit", "Security"]
        let imports = try Self.imports(under: "Packages/WalkData/Sources")
        let disallowed = imports.filter { !allowed.contains($0.module) }.map { "\($0.file): \($0.module)" }
        XCTAssertEqual(disallowed.sorted(), [], "WalkData 只允许依赖 \(allowed.sorted())")

        let manifest = try Self.read("Packages/WalkData/Package.swift")
        for forbidden in ["WalkDesignSystem", "WalkDebugTools", "DebugSwift"] {
            XCTAssertFalse(manifest.contains(forbidden), "WalkData 不得声明 \(forbidden)")
        }
    }

    /// WalkDesignSystem 只依赖 UI 框架，不依赖数据层或调试工具。
    func testDesignSystemDependsOnlyOnUIFrameworks() throws {
        let allowed: Set<String> = ["Foundation", "SwiftUI", "UIKit", "CoreGraphics"]
        let imports = try Self.imports(under: "Packages/WalkDesignSystem/Sources")
        let disallowed = imports.filter { !allowed.contains($0.module) }.map { "\($0.file): \($0.module)" }
        XCTAssertEqual(disallowed.sorted(), [], "WalkDesignSystem 只允许依赖 \(allowed.sorted())")
    }

    /// Feature 不创建具体客户端、存储或认证实例，不读取运行模式或配置源。
    /// 这些由 App 依据最终配置装配后注入（R-DEP / R-CONFIG / R-AUTH）。
    func testFeaturesDoNotAssembleDataDependenciesOrReadConfiguration() throws {
        let forbidden: [(pattern: String, reason: String)] = [
            (#"\bAlamofireRemoteAPIClient\s*\("#, "创建真实客户端"),
            (#"\bMockAPIClient\s*\("#, "创建 Mock 客户端"),
            (#"\bJSONFileAPIStorage\s*\("#, "创建响应存储"),
            (#"\bAuthManager\s*\("#, "创建认证实例"),
            (#"\bWalkDataMode\b"#, "读取数据模式"),
            (#"\bAppConfiguration\b"#, "读取 App 配置"),
            (#"\bProcessInfo\b"#, "读取进程参数或环境变量"),
            (#"\bDebugSettings(Store)?\b"#, "读取 Debug 设置"),
        ]
        var violations: [String] = []
        for (file, source) in try Self.sources(under: "Walk/Features") {
            for rule in forbidden where source.range(of: rule.pattern, options: .regularExpression) != nil {
                violations.append("\(file): \(rule.reason)")
            }
        }
        XCTAssertEqual(violations.sorted(), [], "Feature 只消费 App 注入的 Service 与会话")
    }

    /// 生产装配入口唯一：真实客户端、存储、认证实例只在 App 的依赖装配中创建。
    func testProductionAssemblyHappensOnlyInAppEnvironment() throws {
        let patterns = [#"\bAlamofireRemoteAPIClient\s*\("#, #"\bJSONFileAPIStorage\s*\("#, #"\bAuthManager\s*\(\s*persistenceNamespace"#]
        var sites: Set<String> = []
        for (file, source) in try Self.sources(under: "Walk/App") {
            if patterns.contains(where: { source.range(of: $0, options: .regularExpression) != nil }) {
                sites.insert(file)
            }
        }
        XCTAssertEqual(sites, ["AppEnvironment.swift"], "生产依赖只由 AppEnvironment 装配")
    }

    // MARK: - Helpers

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func read(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot.appendingPathComponent(relative), encoding: .utf8)
    }

    /// 源码（去掉整行注释），排除预览与构建产物。
    private static func sources(under relative: String) throws -> [(String, String)] {
        let root = repoRoot.appendingPathComponent(relative).standardizedFileURL
        var result: [(String, String)] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in enumerator ?? NSEnumerator() where url.pathExtension == "swift" {
            let path = url.standardizedFileURL.path
            guard !path.contains("/.build/") else { continue }
            let raw = try String(contentsOf: url, encoding: .utf8)
            let code = raw.split(separator: "\n", omittingEmptySubsequences: false)
                .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
                .joined(separator: "\n")
            result.append((url.lastPathComponent, stripPreviews(code)))
        }
        return result
    }

    /// `#Preview` 与 `#if DEBUG` 预览块只服务开发体验，不属于生产依赖方向。
    private static func stripPreviews(_ source: String) -> String {
        guard let range = source.range(of: "\n#if DEBUG\n#Preview") ?? source.range(of: "\n#Preview") else {
            return source
        }
        return String(source[..<range.lowerBound])
    }

    private static func imports(under relative: String) throws -> [(file: String, module: String)] {
        try sources(under: relative).flatMap { file, source in
            source.split(separator: "\n").compactMap { line -> (String, String)? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { return nil }
                let module = trimmed.dropFirst("import ".count).split(separator: " ").last.map(String.init) ?? ""
                return (file, module)
            }
        }
    }
}
