import XCTest

/// W3：摇一摇打开 DebugSwift 面板，面板展示 App 注入的配置信息与动作。
///
/// XCUITest 无法合成摇动事件，`-WalkSimulateShake` 在启动后发出与 UIWindow 摇动
/// 相同的通知，覆盖「通知 → 呈现 → SDK 面板 → 自定义信息/动作」的真实链路。
final class DebugToolsUITests: XCTestCase {
    @MainActor
    func testShakeOpensPanelWithInjectedConfiguration() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-WalkDataMode", "mock",
            "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
            "-WalkEnvironment", "development",
            "-WalkSimulateShake",
        ]
        app.launch()

        // DebugSwift 面板的 App 分组承载 customInfo / customAction；每个分组以标题作为一行。
        let appTab = app.tabBars.buttons["App"]
        XCTAssertTrue(appTab.waitForExistence(timeout: 15), "摇一摇后未出现 DebugSwift 面板")
        appTab.tap()

        // 1) 自定义信息：展示本次启动的有效配置。
        openRow("当前生效", in: app)
        XCTAssertTrue(label(containing: ["数据模式", "mock"], in: app).waitForExistence(timeout: 5),
                      "未展示当前生效的数据模式")
        attach(app, "debug-panel-effective")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 2) 自定义动作：写入待生效设置，不改变本次有效配置。
        openRow("数据模式", in: app)
        openRow("remoteOnly", in: app)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 3) SDK 的 App 列表不会自动重载，需点其刷新按钮；之后出现「重启后生效」。
        app.navigationBars.buttons["Refresh"].firstMatch.tap()
        let toast = app.alerts.firstMatch
        if toast.waitForExistence(timeout: 3) {
            _ = toast.waitForNonExistence(timeout: 5)
        }
        openRow("重启后生效", in: app)
        XCTAssertTrue(label(containing: ["数据模式", "remoteOnly"], in: app).waitForExistence(timeout: 5),
                      "动作未写入待生效设置")
        attach(app, "debug-panel-pending")

        // 清理：恢复构建默认值，避免影响后续手动运行。
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openRow("维护", in: app)
        openRow("恢复构建默认值", in: app)
    }

    private func openRow(_ title: String, in app: XCUIApplication) {
        let row = app.staticTexts[title].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "缺少行：\(title)")
        row.tap()
    }

    private func label(containing parts: [String], in app: XCUIApplication) -> XCUIElement {
        let predicates = parts.map { NSPredicate(format: "label CONTAINS %@", $0) }
        return app.descendants(matching: .any)
            .matching(NSCompoundPredicate(andPredicateWithSubpredicates: predicates))
            .firstMatch
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
