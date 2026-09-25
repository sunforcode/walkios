import XCTest

/// W4：Feature 之间、Feature 与 App 之间的依赖边界。
///
/// 依据 specs/README.md R-DEP：
/// - Feature 不引用其他 Feature 的页面、ViewModel 或内部类型；
/// - Feature 不引用 App 根实现；
/// - 导航意图与被多个域使用的业务组件放在明确的共享合同位置 `Features/Shared/`，
///   Shared 自身不依赖任何业务域。
///
/// 检查范围是顶层类型声明（含业务组件命名空间 enum）。对 WalkData 类型的 extension 成员
/// 不在检查范围内。注释会被忽略，字符串字面量不会。
final class FeatureBoundaryTests: XCTestCase {
    private static let sharedDomain = "Shared"

    func testFeaturesReferenceOnlyTheirOwnDomainAndShared() throws {
        let index = try Self.buildIndex()
        var violations: [String] = []
        for file in index.files {
            for (name, owner) in index.owners where owner != file.domain {
                guard owner != Self.sharedDomain || file.domain == Self.sharedDomain else { continue }
                if Self.references(name, in: file.source) {
                    violations.append("\(file.path) → \(owner).\(name)")
                }
            }
        }
        XCTAssertEqual(violations.sorted(), [], "Feature 只能引用本域与 Shared 的类型；Shared 不得依赖业务域")
    }

    func testFeaturesDoNotReferenceAppTypes() throws {
        let appTypes = try Self.topLevelTypes(under: "Walk/App", excluding: ["Baseline", "Debug"])
        let index = try Self.buildIndex()
        var violations: [String] = []
        for file in index.files {
            for name in appTypes where Self.references(name, in: file.source) {
                violations.append("\(file.path) → App.\(name)")
            }
        }
        XCTAssertEqual(violations.sorted(), [], "Feature 不得引用 App 根实现类型")
    }

    // MARK: - Index

    private struct SourceFile {
        let path: String
        let domain: String
        let source: String
    }

    private struct Index {
        let files: [SourceFile]
        /// 顶层类型名 → 声明所在域
        let owners: [String: String]
    }

    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    private static func buildIndex() throws -> Index {
        let root = repoRoot.appendingPathComponent("Walk/Features").standardizedFileURL
        var files: [SourceFile] = []
        var owners: [String: String] = [:]
        for url in try swiftFiles(under: root) {
            let relative = String(url.path.dropFirst(root.path.count + 1))
            guard let domain = relative.split(separator: "/").first.map(String.init) else { continue }
            let source = stripComments(try String(contentsOf: url, encoding: .utf8))
            files.append(SourceFile(path: relative, domain: domain, source: source))
            for name in declaredTopLevelTypes(in: source) {
                owners[name] = domain
            }
        }
        return Index(files: files, owners: owners)
    }

    private static func topLevelTypes(under relative: String, excluding: [String]) throws -> Set<String> {
        let root = repoRoot.appendingPathComponent(relative).standardizedFileURL
        var names: Set<String> = []
        for url in try swiftFiles(under: root) {
            let sub = String(url.path.dropFirst(root.path.count + 1))
            if excluding.contains(where: { sub.hasPrefix($0 + "/") }) { continue }
            names.formUnion(declaredTopLevelTypes(in: stripComments(try String(contentsOf: url, encoding: .utf8))))
        }
        return names
    }

    private static func swiftFiles(under root: URL) throws -> [URL] {
        var result: [URL] = []
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        for case let url as URL in enumerator ?? NSEnumerator() where url.pathExtension == "swift" {
            result.append(url.standardizedFileURL)
        }
        return result.sorted { $0.path < $1.path }
    }

    /// 无缩进的非 private 类型声明视为顶层可见类型。
    private static let declaration = try! NSRegularExpression(
        pattern: #"^(?:@\w+\s+)*(?:public\s+|internal\s+)?(?:final\s+)?(?:struct|class|enum|protocol|actor|typealias)\s+(\w+)"#,
        options: [.anchorsMatchLines]
    )

    private static func declaredTopLevelTypes(in source: String) -> Set<String> {
        let range = NSRange(source.startIndex..., in: source)
        return Set(declaration.matches(in: source, range: range).compactMap {
            Range($0.range(at: 1), in: source).map { String(source[$0]) }
        })
    }

    private static func references(_ name: String, in source: String) -> Bool {
        source.range(of: #"\b\#(name)\b"#, options: .regularExpression) != nil
    }

    private static func stripComments(_ source: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false).map { line -> Substring in
            let trimmed = line.drop { $0 == " " || $0 == "\t" }
            if trimmed.hasPrefix("//") { return "" }
            if let range = line.range(of: " //") { return line[..<range.lowerBound] }
            return line
        }.joined(separator: "\n")
    }
}
