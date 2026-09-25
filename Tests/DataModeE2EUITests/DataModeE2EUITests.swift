import XCTest

/// W6 三模式 E2E：正式 App 按启动参数选择模式，连到宿主上的受控服务。
///
/// 判据由宿主脚本核对：受控服务的请求日志与 App 响应缓存目录（依据 R-VERIFY：
/// remoteOnly 需要真实到达受控服务的证据，仅有页面显示成功不算证据）。本用例只负责
/// 按模式启动 App、等待路线页加载完成并截图留证。
///
/// 真实网络模式拒绝 localhost / 127.0.0.1 占位地址（R-CONFIG），受控服务使用宿主局域网地址，
/// 由环境变量 `WALK_E2E_BASE_URL` 注入。
final class DataModeE2EUITests: XCTestCase {
    private static var base: String {
        ProcessInfo.processInfo.environment["WALK_E2E_BASE_URL"] ?? "http://192.168.31.127:18765/walkbg/api/v1"
    }

    @MainActor func testMock() throws { try run(mode: "mock") }
    @MainActor func testReal() throws { try run(mode: "real") }
    @MainActor func testRemoteOnly() throws { try run(mode: "remoteOnly") }

    @MainActor
    private func run(mode: String) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-WalkDataMode", mode, "-APIBaseURL", Self.base, "-WalkEnvironment", "w6-e2e"]
        app.launch()
        app.tabBars.buttons["路线"].firstMatch.tap()

        XCTAssertTrue(app.buttons["全部路线"].firstMatch.waitForExistence(timeout: 10), "\(mode)：路线页未出现")
        let loading = app.descendants(matching: .any).matching(identifier: "路线加载中").firstMatch
        let loadingLabel = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "路线加载中")).firstMatch
        let finished = NSPredicate(format: "exists == false")
        expectation(for: finished, evaluatedWith: loading)
        expectation(for: finished, evaluatedWith: loadingLabel)
        waitForExpectations(timeout: 15)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "mode-\(mode)"
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }
}
