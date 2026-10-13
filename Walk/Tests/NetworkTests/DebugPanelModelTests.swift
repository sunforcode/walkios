import XCTest
import WalkData
import WalkDebugTools
@testable import Walk

/// W3-2：调试面板的信息与动作。
///
/// 依据 specs/README.md R-DEBUG：App 注入只读配置快照与设置、清缓存等动作回调，
/// 数据模块执行实际操作；DebugTools 不持有第二份有效配置。
/// 依据 R-SWITCH：保存只影响下一次启动，面板展示当前有效值与待生效值。
@MainActor
final class DebugPanelModelTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: DebugSettingsStore!
    private var clearCount = 0

    override func setUp() {
        super.setUp()
        suiteName = "walk.tests.debug-panel.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = DebugSettingsStore(defaults: defaults)
        clearCount = 0
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - 信息

    func testInfoShowsEffectiveConfiguration() {
        let model = makeModel(effective: configuration(.real, "development"))
        let effective = section("当前生效", in: model.infoSections())

        XCTAssertEqual(value("数据模式", in: effective), "real")
        XCTAssertEqual(value("服务器", in: effective), "development · https://vialu.cn/walkbg/api/v1")
        XCTAssertEqual(value("断网策略", in: effective), "fail")
    }

    func testInfoShowsPendingOnlyWhenSavedDiffersFromEffective() {
        let model = makeModel(effective: configuration(.real, "development"))
        XCTAssertNil(model.infoSections().first { $0.title == "重启后生效" })

        store.save(DebugSettings(dataMode: .real, server: nil))
        XCTAssertNil(model.infoSections().first { $0.title == "重启后生效" }, "与生效值相同不算待生效")

        store.save(DebugSettings(dataMode: .remoteOnly, server: nil))
        let pending = section("重启后生效", in: model.infoSections())
        XCTAssertEqual(value("数据模式", in: pending), "remoteOnly")
    }

    /// 目前没有端点登记离线资格，选择 useCache 的实际效果需要如实告知。
    func testInfoDisclosesThatUseCacheHasNoEligibleEndpointsYet() {
        let model = makeModel(effective: configuration(.real, "development", policy: .useCache))
        let effective = section("当前生效", in: model.infoSections())
        XCTAssertEqual(value("断网策略", in: effective), "useCache（当前无端点登记离线资格，行为同 fail）")
    }

    // MARK: - 动作

    func testComponentCatalogActionOnlyOpensPreviewWithoutChangingConfigurationOrCache() {
        let saved = DebugSettings(
            dataMode: .remoteOnly,
            server: .init(environmentName: "production", baseURL: URL(string: "https://vialu.cn/walkbg/api/v1")!),
            offlinePolicy: .useCache
        )
        store.save(saved)
        let storedData = defaults.data(forKey: DebugSettingsStore.key)
        let effective = configuration(.real, "development")
        let model = makeModel(effective: effective)
        let infoBefore = model.infoSections()
        var openCount = 0
        let sections = model.actionSections(openComponentCatalog: { openCount += 1 })
        XCTAssertEqual(openCount, 0, "创建动作列表不能打开预览")
        guard let previewSection = sections.first(where: { $0.title == "组件预览" }) else {
            return XCTFail("missing action section 组件预览")
        }
        XCTAssertEqual(previewSection.actions.map(\.title), ["打开组件目录"])
        guard let action = previewSection.actions.first else {
            return XCTFail("missing action 组件预览/打开组件目录")
        }

        action.perform()

        XCTAssertEqual(openCount, 1)
        XCTAssertEqual(model.effective, effective, "预览不能修改本次有效配置")
        XCTAssertEqual(store.load(), saved, "预览不能修改待生效设置")
        XCTAssertEqual(defaults.data(forKey: DebugSettingsStore.key), storedData)
        XCTAssertEqual(model.infoSections(), infoBefore)
        XCTAssertEqual(clearCount, 0, "预览不能清除响应缓存")
    }

    func testComponentCatalogActionDoesNotCreateSettingsWhenNoneAreSaved() {
        let effective = configuration(.mock, "development")
        let model = makeModel(effective: effective)
        var openCount = 0

        perform("打开组件目录", in: "组件预览", model: model, openComponentCatalog: { openCount += 1 })

        XCTAssertEqual(openCount, 1)
        XCTAssertEqual(model.effective, effective)
        XCTAssertNil(store.load())
        XCTAssertNil(defaults.data(forKey: DebugSettingsStore.key))
        XCTAssertNil(model.infoSections().first { $0.title == "重启后生效" })
        XCTAssertEqual(clearCount, 0)
    }

    func testModeActionsWriteOnlyTheModeDimension() {
        store.save(DebugSettings(
            dataMode: .mock,
            server: .init(environmentName: "production", baseURL: URL(string: "https://vialu.cn/walkbg/api/v1")!),
            offlinePolicy: .useCache
        ))
        let model = makeModel(effective: configuration(.mock, "development"))

        perform("remoteOnly", in: "数据模式", model: model)

        let saved = store.load()
        XCTAssertEqual(saved?.dataMode, .remoteOnly)
        XCTAssertEqual(saved?.server?.environmentName, "production", "切换模式不改变服务器")
        XCTAssertEqual(saved?.offlinePolicy, .useCache, "切换模式不改变策略")
    }

    func testServerActionsWriteOnlyTheServerDimension() {
        store.save(DebugSettings(dataMode: .remoteOnly, server: nil))
        let model = makeModel(effective: configuration(.remoteOnly, "development"))

        perform("线上 production", in: "服务器", model: model)

        let saved = store.load()
        XCTAssertEqual(saved?.server?.environmentName, "production")
        XCTAssertEqual(saved?.server?.baseURL.absoluteString, "https://vialu.cn/walkbg/api/v1")
        XCTAssertEqual(saved?.dataMode, .remoteOnly, "切换服务器不改变模式")
    }

    func testPolicyActionWritesPolicy() {
        let model = makeModel(effective: configuration(.real, "development"))
        perform("useCache", in: "断网策略", model: model)
        XCTAssertEqual(store.load()?.offlinePolicy, .useCache)
    }

    func testFollowBuildDefaultsClearsSavedSettings() {
        store.save(DebugSettings(dataMode: .remoteOnly, server: nil))
        let model = makeModel(effective: configuration(.real, "development"))

        perform("恢复构建默认值", in: "维护", model: model)

        XCTAssertNil(store.load())
    }

    func testClearResponseCacheDelegatesToInjectedAction() {
        let model = makeModel(effective: configuration(.real, "development"))
        perform("清除响应缓存", in: "维护", model: model)
        XCTAssertEqual(clearCount, 1)
    }

    /// 动作不改变本次启动的有效配置（R-SWITCH）。
    func testActionsDoNotMutateEffectiveConfiguration() {
        let effective = configuration(.real, "development")
        let model = makeModel(effective: effective)

        perform("mock", in: "数据模式", model: model)

        XCTAssertEqual(model.effective, effective)
        XCTAssertEqual(value("数据模式", in: section("当前生效", in: model.infoSections())), "real")
    }

    // MARK: - Helpers

    private func makeModel(effective: AppConfiguration) -> DebugPanelModel {
        DebugPanelModel(
            effective: effective,
            store: store,
            clearResponseCache: { [weak self] in self?.clearCount += 1 }
        )
    }

    private func configuration(
        _ mode: WalkDataMode,
        _ environmentName: String,
        policy: OfflinePolicy = .fail
    ) -> AppConfiguration {
        AppConfiguration(
            dataMode: mode,
            baseURL: URL(string: "https://vialu.cn/walkbg/api/v1")!,
            environmentName: environmentName,
            offlinePolicy: policy
        )
    }

    private func section(_ title: String, in sections: [DebugInfoSection]) -> DebugInfoSection {
        guard let found = sections.first(where: { $0.title == title }) else {
            XCTFail("missing info section \(title)")
            return DebugInfoSection(title: title, rows: [])
        }
        return found
    }

    private func value(_ title: String, in section: DebugInfoSection) -> String? {
        section.rows.first { $0.title == title }?.value
    }

    private func perform(
        _ actionTitle: String,
        in sectionTitle: String,
        model: DebugPanelModel,
        openComponentCatalog: @escaping () -> Void = {}
    ) {
        guard let action = model.actionSections(openComponentCatalog: openComponentCatalog)
            .first(where: { $0.title == sectionTitle })?
            .actions.first(where: { $0.title == actionTitle }) else {
            return XCTFail("missing action \(sectionTitle)/\(actionTitle)")
        }
        action.perform()
    }
}
