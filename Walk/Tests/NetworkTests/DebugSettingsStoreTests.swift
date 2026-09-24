import XCTest
import WalkData
@testable import Walk

/// W2-2：Debug 设置以带版本的单一记录保存。
///
/// 依据 R-SWITCH：保存只影响下一次启动。依据 R-MIGRATION：未知值不猜测迁移。
/// 旧 `walk.debug.environment` 预设是临时状态，不迁移。
final class DebugSettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "walk.tests.debug-settings.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testRoundTripPreservesIndependentDimensions() {
        let store = DebugSettingsStore(defaults: defaults)
        let settings = DebugSettings(
            dataMode: .remoteOnly,
            server: .init(environmentName: "staging", baseURL: URL(string: "https://staging.example.test/v1")!)
        )

        store.save(settings)

        XCTAssertEqual(store.load(), settings)
        XCTAssertEqual(store.load()?.version, DebugSettings.currentVersion)
    }

    func testAbsentRecordLoadsAsNil() {
        XCTAssertNil(DebugSettingsStore(defaults: defaults).load())
    }

    func testRetiredPresetKeyIsNotMigrated() {
        defaults.set("mock", forKey: "walk.debug.environment")
        XCTAssertNil(DebugSettingsStore(defaults: defaults).load())
    }

    func testUnreadableOrFutureRecordIsIgnoredWithoutGuessing() throws {
        let store = DebugSettingsStore(defaults: defaults)

        defaults.set(Data("not-json".utf8), forKey: DebugSettingsStore.key)
        XCTAssertNil(store.load())

        let future = try JSONSerialization.data(withJSONObject: [
            "version": DebugSettings.currentVersion + 1,
            "dataMode": "mock",
        ])
        defaults.set(future, forKey: DebugSettingsStore.key)
        XCTAssertNil(store.load())
    }

    func testClearRemovesRecord() {
        let store = DebugSettingsStore(defaults: defaults)
        store.save(DebugSettings(dataMode: .mock, server: nil))

        store.clear()

        XCTAssertNil(store.load())
    }
}
