import XCTest

/// Preview 样例数据与所属对象共置。
///
/// 组件或页面在自身文件的 `#if DEBUG` 段内以所属类型 extension 提供样例，
/// Preview 与组件目录共用同一份；主 target 不设集中式 fixture 目录或聚合类型。
/// 通用组件样例由 WalkDesignSystem 自身承载，不在本检查范围。
final class PreviewFixtureColocationTests: XCTestCase {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    func testNoCentralPreviewContentDirectory() {
        let path = Self.repoRoot.appendingPathComponent("Walk/Preview Content").path
        XCTAssertFalse(FileManager.default.fileExists(atPath: path), "Preview 样例应与所属对象共置，不设集中目录")
    }

    func testNoAggregatePreviewFixtureTypes() throws {
        let pattern = try NSRegularExpression(
            pattern: #"^\s*(?:public\s+)?(?:enum|struct|class)\s+(\w*(?:PreviewFixtures|PreviewHelpers))\b"#,
            options: [.anchorsMatchLines]
        )
        var violations: [String] = []
        for relative in ["Walk/App", "Walk/Features", "Walk/Support"] {
            let root = Self.repoRoot.appendingPathComponent(relative)
            let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            for case let url as URL in enumerator ?? NSEnumerator() where url.pathExtension == "swift" {
                let source = try String(contentsOf: url, encoding: .utf8)
                let range = NSRange(source.startIndex..., in: source)
                for match in pattern.matches(in: source, range: range) {
                    if let r = Range(match.range(at: 1), in: source) {
                        violations.append("\(url.lastPathComponent): \(source[r])")
                    }
                }
            }
        }
        XCTAssertEqual(violations.sorted(), [], "样例数据应作为所属类型的 DEBUG extension 放在对象自身文件中")
    }
}
