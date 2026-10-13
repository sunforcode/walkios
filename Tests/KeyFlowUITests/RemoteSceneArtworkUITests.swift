import XCTest

/// Opt-in: 只读连接已导入亚丁五日与六张场景的真实服务，不启用 App Mock。
final class RemoteSceneArtworkUITests: XCTestCase {
    @MainActor
    func testPublicRouteShowsSixRemoteScenes() throws {
        guard let base = ProcessInfo.processInfo.environment["WALK_SCENE_HTTP_BASE_URL"], !base.isEmpty else {
            throw XCTSkip("需要显式 WALK_SCENE_HTTP_BASE_URL 与已经导入的真实测试服务")
        }
        let routeName = ProcessInfo.processInfo.environment["WALK_SCENE_ROUTE_NAME"] ?? "亚丁5日"
        let app = XCUIApplication()
        app.launchArguments = [
            "-WalkDataMode", "remoteOnly", "-APIBaseURL", base,
            "-WalkEnvironment", "scene-real-http-\(UUID().uuidString)",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["路线"].waitForExistence(timeout: 15))
        app.tabBars.buttons["路线"].tap()
        let route = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", routeName)).firstMatch
        if !route.waitForExistence(timeout: 15) {
            let allRoutes = app.buttons["全部路线"]
            XCTAssertTrue(allRoutes.waitForExistence(timeout: 10))
            allRoutes.tap()
            let search = app.buttons["搜索路线"]
            XCTAssertTrue(search.waitForExistence(timeout: 10))
            search.tap()
            let input = app.textFields["输入路线名称或地区"]
            XCTAssertTrue(input.waitForExistence(timeout: 10))
            input.tap()
            input.typeText(routeName)
        }
        XCTAssertTrue(route.waitForExistence(timeout: 15))
        capture(app, "scene-http-route-discovery")
        route.tap()
        XCTAssertTrue(app.buttons["进入全屏地图"].waitForExistence(timeout: 15))
        capture(app, "scene-http-route-detail")

        let gallery = app.staticTexts["场景示意"]
        let lastDay = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "第5天 · AIGC 场景示意")).firstMatch
        for _ in 0..<70 {
            if gallery.exists, gallery.isHittable, lastDay.exists, lastDay.isHittable { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.80))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.28)))
        }
        XCTAssertTrue(gallery.isHittable, "真实服务场景应在独立图库分组展示")
        XCTAssertTrue(lastDay.isHittable)
        for day in 1...5 {
            XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "第\(day)天 · AIGC 场景示意")).firstMatch.exists)
        }
        // 图片节点对辅助功能隐藏；线上原图下载完成须以截图人工检查，文字断言不替代图像验收。
        if let rawWait = ProcessInfo.processInfo.environment["WALK_SCENE_IMAGE_SETTLE_SECONDS"],
           let seconds = TimeInterval(rawWait), seconds > 0 {
            Thread.sleep(forTimeInterval: min(seconds, 180))
        }
        capture(app, "scene-http-six-images-gallery")
        app.terminate()
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
