import XCTest
import WalkData
@testable import Walk

/// W2-4：remoteOnly 之后再进入 real 时，此前的响应缓存失效。
///
/// 依据 specs/README.md R-INVALIDATION：`remoteOnly` 请求不访问响应缓存；再次进入 `real`
/// 时需使此前缓存失效，避免忽略 `remoteOnly` 期间的修改，该失效属于启动生命周期管理。
final class ResponseCacheLifecycleTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var cacheDirectory: URL!

    override func setUpWithError() throws {
        suiteName = "walk.tests.cache-lifecycle.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        cacheDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("walk-cache-lifecycle-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: cacheDirectory)
    }

    // MARK: - 决策

    func testRealAfterRemoteOnlyInvalidatesExactlyOnce() {
        let lifecycle = ResponseCacheLifecycle(defaults: defaults)

        XCTAssertFalse(lifecycle.recordLaunch(.real))
        XCTAssertFalse(lifecycle.recordLaunch(.remoteOnly))
        XCTAssertTrue(lifecycle.recordLaunch(.real), "remoteOnly 之后进入 real 必须失效")
        XCTAssertFalse(lifecycle.recordLaunch(.real), "失效后不重复清理")
    }

    /// 中间隔着 mock 也不能漏掉 remoteOnly 期间的修改。
    func testInterveningMockDoesNotHideRemoteOnlyLaunch() {
        let lifecycle = ResponseCacheLifecycle(defaults: defaults)

        _ = lifecycle.recordLaunch(.remoteOnly)
        XCTAssertFalse(lifecycle.recordLaunch(.mock))
        XCTAssertTrue(lifecycle.recordLaunch(.real))
    }

    func testMockAndRealAloneNeverInvalidate() {
        let lifecycle = ResponseCacheLifecycle(defaults: defaults)

        XCTAssertFalse(lifecycle.recordLaunch(.real))
        XCTAssertFalse(lifecycle.recordLaunch(.mock))
        XCTAssertFalse(lifecycle.recordLaunch(.real))
    }

    // MARK: - 装配

    func testAppEnvironmentClearsResponseCacheWhenReturningToReal() async throws {
        let marker = cacheDirectory.appendingPathComponent("stale-entry")
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try Data("stale".utf8).write(to: marker)

        _ = try makeEnvironment(.remoteOnly)
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path), "remoteOnly 不访问也不清理响应缓存")

        _ = try makeEnvironment(.real)
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path), "回到 real 前清理此前缓存")
    }

    func testAppEnvironmentKeepsCacheAcrossRealLaunches() throws {
        _ = try makeEnvironment(.real)
        let marker = cacheDirectory.appendingPathComponent("kept-entry")
        try Data("kept".utf8).write(to: marker)

        _ = try makeEnvironment(.real)

        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
    }

    private func makeEnvironment(_ mode: WalkDataMode) throws -> AppEnvironment {
        try AppEnvironment(
            configuration: AppConfiguration(
                dataMode: mode,
                baseURL: URL(string: "https://api.example.test/v1")!,
                environmentName: "test"
            ),
            responseCacheDirectory: cacheDirectory,
            cacheLifecycle: ResponseCacheLifecycle(defaults: defaults)
        )
    }
}
