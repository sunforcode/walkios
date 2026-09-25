import XCTest
import WalkData
@testable import Walk

/// 调试面板保存的设置不得让 App 无法启动。
///
/// 缺陷：构建默认模式为 mock，面板「服务器 / 线上 production」只写入服务器维度；
/// 重启后解析为 mock + production，被 R-CONFIG（production 必须真实网络）拒绝，
/// `WalkApp.init` 触发 fatalError，且设置已持久化导致每次启动都崩溃。
@MainActor
final class DebugSettingsStartupTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var store: DebugSettingsStore!

    private let buildConfiguration: [String: Any] = [
        "WalkDataMode": "mock",
        "WalkAPIBaseURL": "https://vialu.cn/walkbg/api/v1",
        "WalkEnvironment": "development",
    ]

    override func setUp() {
        super.setUp()
        suiteName = "walk.tests.debug-startup.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = DebugSettingsStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// 从构建默认开始，面板里单独执行任一动作后，下一次启动都必须能解析并装配。
    func testEveryPanelActionFromBuildDefaultsProducesALaunchableConfiguration() throws {
        let effective = try resolve(nil)
        for section in model(effective: effective).actionSections() where section.title != "维护" {
            for action in section.actions {
                store.clear()
                action.perform()
                let saved = store.load()
                XCTAssertNoThrow(
                    try AppEnvironment(configuration: try resolve(saved)),
                    "\(section.title) / \(action.title) 保存后无法启动：\(String(describing: saved))"
                )
            }
        }
    }

    /// 选择线上服务器时，数据模式随之切到真实网络（线上不存在 Mock 数据）。
    func testSelectingProductionServerAlsoSelectsRealNetwork() throws {
        let effective = try resolve(nil)
        perform("线上 production", in: "服务器", model: model(effective: effective))
        XCTAssertEqual(store.load()?.server?.environmentName, "production")
        XCTAssertEqual(store.load()?.dataMode?.usesRealNetwork, true)
    }

    /// 已保存设置无法组成合法配置时：清除它，回落到构建默认，不让 App 崩溃。
    func testInvalidSavedSettingsAreDiscardedAtStartup() throws {
        store.save(DebugSettings(
            dataMode: .mock,
            server: .init(environmentName: "production", baseURL: URL(string: "https://vialu.cn/walkbg/api/v1")!)
        ))
        let resolution = try AppConfiguration.resolveProcess(
            arguments: ["Walk"],
            environment: [:],
            bundleInfo: buildConfiguration,
            store: store,
            isDebugBuild: true
        )
        XCTAssertEqual(resolution.configuration.dataMode, .mock)
        XCTAssertEqual(resolution.configuration.environmentName, "development")
        XCTAssertEqual(resolution.discardedSettingsError, .productionRequiresRealNetwork)
        XCTAssertNil(store.load(), "非法设置必须被清除，避免下次启动重复失败")
    }

    /// 显式启动参数出错仍然立即失败：只容错个人保存的 Debug 设置。
    func testExplicitLaunchArgumentErrorsStillThrow() {
        XCTAssertThrowsError(try AppConfiguration.resolveProcess(
            arguments: ["Walk", "-WalkDataMode", "mock", "-WalkEnvironment", "production"],
            environment: [:],
            bundleInfo: buildConfiguration,
            store: store,
            isDebugBuild: true
        ))
    }

    // MARK: - Helpers

    private func resolve(_ settings: DebugSettings?) throws -> AppConfiguration {
        try AppConfiguration(
            arguments: ["Walk"],
            environment: [:],
            bundleInfo: buildConfiguration,
            debugSettings: settings,
            isDebugBuild: true
        )
    }

    private func model(effective: AppConfiguration) -> DebugPanelModel {
        DebugPanelModel(effective: effective, store: store, clearResponseCache: {})
    }

    private func perform(_ title: String, in section: String, model: DebugPanelModel) {
        guard let action = model.actionSections().first(where: { $0.title == section })?
            .actions.first(where: { $0.title == title }) else {
            return XCTFail("missing action \(section)/\(title)")
        }
        action.perform()
    }
}
