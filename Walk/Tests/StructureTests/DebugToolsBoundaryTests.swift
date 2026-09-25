import XCTest

/// W3-3：调试能力的依赖边界。
///
/// 依据 specs/README.md R-DEP / R-DEBUG：Feature 与业务 Service 不依赖 DebugTools；
/// 调试 SDK 只经 WalkDebugTools 进入 App，调试入口由 App 承载，不在 Feature 中留下 SDK 调用。
/// 检查聚焦禁止依赖，不绑定具体文件名或局部实现。
final class DebugToolsBoundaryTests: XCTestCase {
    private static let forbiddenModules = ["DebugSwift", "WalkDebugTools"]

    func testFeaturesDoNotImportDebugTools() throws {
        let hits = try Self.imports(of: Self.forbiddenModules, under: "Walk/Features")
        XCTAssertEqual(hits, [], "Feature 不得依赖调试工具")
    }

    func testDataAndDesignSystemPackagesDoNotImportDebugTools() throws {
        for package in ["Packages/WalkData", "Packages/WalkDesignSystem"] {
            let hits = try Self.imports(of: Self.forbiddenModules, under: package)
            XCTAssertEqual(hits, [], "\(package) 不得依赖调试工具")
        }
        for manifest in ["Packages/WalkData/Package.swift", "Packages/WalkDesignSystem/Package.swift"] {
            let source = try String(contentsOf: Self.repoRoot.appendingPathComponent(manifest), encoding: .utf8)
            for module in Self.forbiddenModules {
                XCTAssertFalse(source.contains(module), "\(manifest) 不得声明 \(module)")
            }
        }
    }

    /// DebugSwift 只允许出现在适配层包内。
    func testOnlyTheAdapterPackageImportsTheSDK() throws {
        let hits = try Self.imports(of: ["DebugSwift"], under: "Walk")
        XCTAssertEqual(hits, [], "App 只经 WalkDebugTools 使用调试 SDK")
    }

    /// 调试入口归 App，不再作为 Feature 页面或任务栈目的地存在。
    func testDebugEntryIsNotAFeatureDestination() throws {
        let features = try Self.swiftSources(under: "Walk/Features")
        for (path, source) in features {
            XCTAssertFalse(source.contains("debugEnvironment"), "\(path) 仍引用 Feature 侧调试入口")
        }
        let navigation = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Walk/App/RootNavigation.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(navigation.contains("debugEnvironment"), "调试入口不得作为 AppDestination")
    }

    /// 生产依赖图不得声明调试依赖。
    func testReleaseProjectSpecDeclaresNoDebugDependency() throws {
        let spec = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("project-release.yml"),
            encoding: .utf8
        )
        let base = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("project-base.yml"),
            encoding: .utf8
        )
        for module in Self.forbiddenModules {
            XCTAssertFalse(Self.declares(module, in: spec), "project-release.yml 不得声明 \(module)")
            XCTAssertFalse(Self.declares(module, in: base), "共用模板不得声明 \(module)")
        }
    }

    // MARK: - Helpers

    /// 本文件位于 `Walk/Tests/StructureTests/`，上四级为仓库根。
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    /// 忽略注释行，只把实际声明视为依赖。
    private static func declares(_ module: String, in yaml: String) -> Bool {
        yaml.split(separator: "\n").contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return !trimmed.hasPrefix("#") && trimmed.contains(module)
        }
    }

    private static func swiftSources(under relative: String) throws -> [(String, String)] {
        let root = repoRoot.appendingPathComponent(relative).standardizedFileURL
        var result: [(String, String)] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in enumerator ?? NSEnumerator() {
            let path = url.standardizedFileURL.path
            guard url.pathExtension == "swift",
                  !path.contains("/.build/"),
                  !path.contains("/Tests/") else { continue }
            result.append((String(path.dropFirst(root.path.count + 1)), try String(contentsOf: url, encoding: .utf8)))
        }
        return result
    }

    private static func imports(of modules: [String], under relative: String) throws -> [String] {
        try swiftSources(under: relative).flatMap { path, source in
            source.split(separator: "\n").compactMap { line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard let module = modules.first(where: {
                    trimmed == "import \($0)" || trimmed.hasPrefix("import \($0) ")
                        || trimmed.hasSuffix(" import \($0)")
                }) else { return nil }
                return "\(path): \(module)"
            }
        }
    }
}
