import XCTest

/// W5：WalkDesignSystem 不承载业务概念。
///
/// 依据 specs/README.md R-DEP：WalkDesignSystem 提供 Theme、通用 UI 和通用展示值，
/// 不依赖业务数据模型；绑定业务对象或具体页面的组件留在所属 Feature。
/// 检查公开类型名的驼峰词，不绑定具体文件或实现。
final class DesignSystemBoundaryTests: XCTestCase {
    /// 业务域与具体页面词。出现即说明该类型属于某个业务域或页面。
    private static let businessWords: Set<String> = [
        "Route", "Trip", "Me", "Profile", "Account", "Equipment", "Weather", "Home", "Camp", "Hike",
    ]

    func testPublicTypesCarryNoBusinessOrPageNames() throws {
        let violations = try Self.publicTypeNames().filter { name in
            !Self.businessWords.isDisjoint(with: Self.camelWords(name))
        }
        XCTAssertEqual(violations.sorted(), [], "设计系统公开类型不得以业务域或具体页面命名，请移回所属 Feature")
    }

    func testPackageDeclaresNoBusinessDependency() throws {
        let manifest = try String(
            contentsOf: Self.repoRoot.appendingPathComponent("Packages/WalkDesignSystem/Package.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(manifest.contains("WalkData"), "设计系统不得依赖数据层")
    }

    // MARK: - Helpers

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func publicTypeNames() throws -> [String] {
        let root = repoRoot.appendingPathComponent("Packages/WalkDesignSystem/Sources").standardizedFileURL
        let pattern = try NSRegularExpression(
            pattern: #"^\s*public\s+(?:final\s+)?(?:struct|class|enum|protocol|typealias)\s+(\w+)"#,
            options: [.anchorsMatchLines]
        )
        var names: [String] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in enumerator ?? NSEnumerator() where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            let range = NSRange(source.startIndex..., in: source)
            for match in pattern.matches(in: source, range: range) {
                if let r = Range(match.range(at: 1), in: source) { names.append(String(source[r])) }
            }
        }
        return names
    }

    /// `MePageBackgroundOverlay` → ["Me", "Page", "Background", "Overlay"]。
    private static func camelWords(_ name: String) -> Set<String> {
        var words: [String] = []
        var current = ""
        for character in name {
            if character.isUppercase, !current.isEmpty {
                words.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { words.append(current) }
        return Set(words)
    }
}
