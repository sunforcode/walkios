import XCTest

/// W3：摇一摇打开 DebugSwift 面板，面板展示 App 注入的配置信息与动作。
///
/// XCUITest 无法合成摇动事件，`-WalkSimulateShake` 在启动后发出与 UIWindow 摇动
/// 相同的通知，覆盖「通知 → 呈现 → SDK 面板 → 自定义信息/动作」的真实链路。
final class DebugToolsUITests: XCTestCase {
    @MainActor
    func testComponentPreviewOpensFromPanelAndReturnsWithoutChangingConfiguration() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-WalkDataMode", "mock",
            "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
            "-WalkEnvironment", "development",
            "-WalkSimulateShake",
        ]
        app.launch()
        defer { app.terminate() }
        let appTab = app.tabBars.buttons["App"]
        XCTAssertTrue(appTab.waitForExistence(timeout: 15))
        appTab.tap()
        let previewEntry = app.staticTexts["组件预览"].firstMatch
        XCTAssertTrue(previewEntry.waitForExistence(timeout: 5), "DebugPanel 缺少组件预览入口")
        guard previewEntry.exists else { return }
        previewEntry.tap()
        openRow("打开组件目录", in: app)

        let component = app.buttons["debug.component.AvatarButton"]
        XCTAssertTrue(component.waitForExistence(timeout: 5))
        component.tap()
        let state = app.buttons["debug.component.state.default"]
        XCTAssertTrue(state.waitForExistence(timeout: 5))
        state.tap()
        let ready = app.descendants(matching: .any)
            .matching(identifier: "component-preview-ready:AvatarButton:default").firstMatch
        XCTAssertTrue(ready.waitForExistence(timeout: 5), "面板必须复用组件 UITest 的生产预览")
        attach(app, "debug-component-preview")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(state.waitForExistence(timeout: 5))
        app.buttons["debug.components.close"].tap()
        XCTAssertTrue(appTab.waitForExistence(timeout: 5), "关闭组件目录应返回原调试面板")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openRow("当前生效", in: app)
        XCTAssertTrue(label(containing: ["数据模式", "mock"], in: app).waitForExistence(timeout: 5))
    }

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

    @MainActor
    func testViewportComponentsRemainVisibleAndCanReturnFromPanel() throws {
        for componentID in ["ModalBottomSheet", "UtilityPage", "MixedPageShell"] {
            let app = XCUIApplication()
            app.launchArguments = [
                "-WalkDataMode", "mock",
                "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
                "-WalkEnvironment", "development",
                "-WalkSimulateShake",
            ]
            app.launch()
            defer { app.terminate() }
            let appTab = app.tabBars.buttons["App"]
            XCTAssertTrue(appTab.waitForExistence(timeout: 15))
            appTab.tap()
            openRow("组件预览", in: app)
            openRow("打开组件目录", in: app)
            let component = app.buttons["debug.component.\(componentID)"]
            for _ in 0..<12 {
                if component.exists && component.isHittable { break }
                app.swipeUp()
            }
            XCTAssertTrue(component.isHittable, "目录项不可达：\(componentID)")
            component.tap()
            let state = app.buttons["debug.component.state.default"]
            XCTAssertTrue(state.waitForExistence(timeout: 5))
            state.tap()
            let ready = app.descendants(matching: .any)
                .matching(identifier: "component-preview-ready:\(componentID):default").firstMatch
            XCTAssertTrue(ready.waitForExistence(timeout: 5))
            attach(app, "debug-viewport-\(componentID)")

            let close = app.buttons["debug.components.close"]
            XCTAssertTrue(close.isHittable, "关闭入口被组件遮挡：\(componentID)")
            let content = app.staticTexts[componentID == "ModalBottomSheet" ? "底部模态任务" : "Content Slot"].firstMatch
            XCTAssertTrue(content.exists, "组件内容缺失：\(componentID)")
            XCTAssertTrue(content.isHittable, "组件内容不可见：\(componentID)")
            XCTAssertGreaterThanOrEqual(content.frame.minY, app.navigationBars.firstMatch.frame.maxY)
            XCTAssertLessThanOrEqual(content.frame.maxY, app.frame.maxY)
            if componentID == "ModalBottomSheet" {
                let action = app.buttons["完成"]
                XCTAssertTrue(action.isHittable, "Sheet 底部动作不可达")
                XCTAssertGreaterThan(action.frame.midY, app.frame.midY, "Sheet 未定位在视口底部")
            }
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(state.waitForExistence(timeout: 5), "无法返回状态选择：\(componentID)")
            app.buttons["debug.components.close"].tap()
            XCTAssertTrue(appTab.waitForExistence(timeout: 5), "无法返回原面板：\(componentID)")
        }
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
