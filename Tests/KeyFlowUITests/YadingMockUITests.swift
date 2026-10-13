import XCTest
import UIKit

/// 亚丁 Mock 通过正式路线、账户、行程页面进入；不替换首页贡嘎焦点。
final class YadingMockUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-WalkDataMode", "mock",
            "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
            "-WalkEnvironment", "yading-mock-\(UUID().uuidString)",
        ]
        app.launch()
    }

    @MainActor
    func testYadingRouteAndFiveDayTripUseProductionPages() {
        XCTAssertTrue(app.tabBars.buttons["路线"].waitForExistence(timeout: 10))
        app.tabBars.buttons["路线"].tap()
        XCTAssertTrue(button(containing: "长海子").waitForExistence(timeout: 10),
                      "等待路线列表加载，保留原长海子样例")
        let route = button(containing: "亚丁5日")
        for _ in 0..<4 {
            if route.exists && route.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(route.waitForExistence(timeout: 10), "新增亚丁应可从路线分页进入")
        XCTAssertTrue(route.isHittable)
        capture("yading-01-route-discovery")
        route.tap()

        let fullscreen = app.buttons["进入全屏地图"]
        XCTAssertTrue(fullscreen.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["立即出发"].firstMatch.exists)
        fullscreen.tap()
        XCTAssertTrue(app.maps.firstMatch.waitForExistence(timeout: 10), "真实轨迹地图应可访问")
        let elevation = element(label: "海拔走势，可滑动定位轨迹位置")
        XCTAssertTrue(elevation.waitForExistence(timeout: 5))
        for number in 1...5 {
            let day = app.buttons.matching(
                NSPredicate(format: "label == %@ OR label BEGINSWITH %@", "D\(number)", "D\(number) ")
            ).firstMatch
            XCTAssertTrue(day.exists, "路线全屏地图应有第 \(number) 天参考划分")
        }
        capture("yading-02-route-track-five-days")

        let restore = app.staticTexts["上划唤回信息面"]
        XCTAssertTrue(restore.waitForExistence(timeout: 5))
        restore.tap()
        let referenceDays = app.staticTexts["参考分日"]
        scrollTo(referenceDays)
        XCTAssertTrue(referenceDays.isHittable, "路线详情应展示参考分日资料")
        capture("yading-03-route-reference-days")
        back()

        openYadingTripFromCalendar()

        let scene = app.buttons["trip-expedition-scene"]
        let overview = app.buttons["trip-date-overview"]
        XCTAssertTrue(scene.waitForExistence(timeout: 10))
        XCTAssertTrue(overview.isSelected, "默认进入全程安排")
        let identity = app.descendants(matching: .any)
            .matching(identifier: "trip-expedition-identity").firstMatch
        XCTAssertTrue(identity.label.contains("10月1"))
        XCTAssertTrue(identity.label.contains("10月5"))
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "trip-scene-elevation").firstMatch.exists)
        capture("yading-04-trip-overview")

        scene.tap()
        XCTAssertTrue(app.buttons["trip-date-1"].wait(for: \.isSelected, toEqual: true, timeout: 5),
                      "从全程主图应进入第一天摘要")
        for number in 1...5 {
            selectDay(number)
            XCTAssertTrue(scene.exists)
            let heading = app.staticTexts["trip-timeline-heading"]
            XCTAssertTrue(heading.exists)
            XCTAssertFalse(heading.label.isEmpty, "每日安排应有实际起讫标题")
            XCTAssertFalse(overview.isSelected)
            app.buttons["trip-date-\(number)"].tap()
            XCTAssertTrue(scene.exists, "重复点同一日期仍停留当天摘要")
            XCTAssertTrue(app.buttons["trip-date-\(number)"].isSelected)
            capture("yading-day-\(number)")
        }

        scene.swipeLeft()
        XCTAssertTrue(app.buttons["trip-date-5"].isSelected, "末日继续左划不循环")
        scene.swipeRight()
        XCTAssertTrue(app.buttons["trip-date-4"].wait(for: \.isSelected, toEqual: true, timeout: 5))
        selectDay(3)
        scene.tap()
        XCTAssertTrue(scene.waitForNonExistence(timeout: 8), "日场景再次点击进入完整每日安排")
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "D3", "10月3日")
        ).firstMatch.waitForExistence(timeout: 8))
        capture("yading-10-daily-detail")
        back()
        XCTAssertTrue(scene.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["trip-date-3"].isSelected, "每日详情返回保留所选日")

        let weather = app.buttons.matching(identifier: "trip-weather-day-summary").firstMatch
        XCTAssertTrue(weather.isHittable)
        weather.tap()
        XCTAssertTrue(app.staticTexts["行程天气"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["5 个自然日"].waitForExistence(timeout: 8), "五天的天气上下文应完整可读")
        XCTAssertFalse(app.staticTexts["无法显示行程天气"].exists)
        capture("yading-11-weather")
        back()
        XCTAssertTrue(scene.waitForExistence(timeout: 8))

        let equipment = app.buttons["trip-equipment-summary"]
        XCTAssertTrue(equipment.isHittable)
        equipment.tap()
        XCTAssertTrue(app.staticTexts["行程装备"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["亚丁5日"].waitForExistence(timeout: 8), "装备页面应属于亚丁行程")
        XCTAssertTrue(app.descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "装备条目 ")
        ).firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["无法显示行程装备"].exists)
        capture("yading-12-equipment")
        back()
        XCTAssertTrue(scene.waitForExistence(timeout: 8))
        overview.tap()
        XCTAssertTrue(overview.wait(for: \.isSelected, toEqual: true, timeout: 5), "最左日期入口返回全程")
    }

    /// 六张既有本地艺术图的叠加视觉检查；不进入路线 MapKit，不使用预览页或基线替代实现。
    @MainActor
    func testYadingOverviewAndFiveDaysLocalOverlayVisualReview() {
        openYadingTripFromCalendar()
        let scene = app.buttons["trip-expedition-scene"]
        XCTAssertTrue(scene.waitForExistence(timeout: 10))
        let overview = app.buttons["trip-date-overview"]
        XCTAssertTrue(overview.isSelected)
        var landmarkGroups = [String]()
        for number in 0...5 {
            if number > 0 { selectDay(number) }
            XCTAssertTrue(scene.isHittable)
            let timeline = app.scrollViews.matching(identifier: "trip-expedition-timeline").firstMatch
            XCTAssertTrue(timeline.exists)
            XCTAssertGreaterThan(timeline.frame.minY, app.frame.height * 0.6, "摘要留在左下，不再扩大为半屏正文")
            XCTAssertEqual(timeline.frame.width / app.frame.width, 0.66, accuracy: 0.02)
            let heading = app.staticTexts["trip-timeline-heading"]
            XCTAssertTrue(heading.isHittable)
            XCTAssertEqual(heading.label, number == 0 ? "全程概览" : "当日走法")
            XCTAssertFalse(app.staticTexts["AIGC 场景示意"].exists)
            XCTAssertFalse(app.staticTexts["行程提醒"].exists)
            XCTAssertFalse(app.scrollViews["trip-scene-notices"].exists)
            // AX滚动范围不代表实际裁切高度；200pt由结构测试及六态截图共同核对。
            XCTAssertFalse(app.maps.firstMatch.exists, "本地场景不挂载需要在线底图的地图控件")
            XCTAssertFalse(app.tabBars.firstMatch.exists, "场景仍使用正式行程二级页面")
            let elevation = app.descendants(matching: .any).matching(identifier: "trip-scene-elevation").firstMatch
            XCTAssertTrue(elevation.exists)
            XCTAssertTrue(elevation.label.contains("来自冻结行程数据"))
            let labels = scene.label.components(separatedBy: "AIGC 场景示意，")
            XCTAssertEqual(labels.count, 2)
            let nodes = labels.last ?? ""
            XCTAssertGreaterThanOrEqual(nodes.split(separator: "，").count, 3, "山景上应叠加本场景真实名称的关键点")
            for forbidden in ["老榆林", "日乌且溪", "下日乌且营地", "日乌且垭口", "草科"] {
                XCTAssertFalse(nodes.contains(forbidden), "亚丁不能使用贡嘎样例节点")
            }
            if number > 0 {
                XCTAssertFalse(landmarkGroups.contains(nodes), "每日必须切换到各自的示意节点")
                landmarkGroups.append(nodes)
                XCTAssertTrue(app.buttons["trip-date-\(number)"].isSelected)
            }
            // 先保留实际画面，即使几何断言失败也能核对系统区域与图片裁切。
            capture(number == 0 ? "yading-compact-overview" : "yading-compact-day-\(number)")
            assertForegroundStaysInsideSystemArea()
            assertArtworkReachesEveryScreenEdge(app.screenshot().image)
        }
        overview.tap()
        XCTAssertTrue(overview.wait(for: \.isSelected, toEqual: true, timeout: 5))
    }

    private func assertForegroundStaysInsideSystemArea() {
        let statusBar = app.statusBars.firstMatch
        for control in [app.buttons["返回"].firstMatch, app.buttons["trip-detail-more"], app.buttons["trip-equipment-summary"]] {
            XCTAssertTrue(control.isHittable)
            XCTAssertGreaterThanOrEqual(control.frame.minX, app.frame.minX)
            XCTAssertLessThanOrEqual(control.frame.maxX, app.frame.maxX)
            if statusBar.exists {
                XCTAssertGreaterThanOrEqual(control.frame.minY, statusBar.frame.maxY - 1,
                                            "操作不能移入状态栏或刘海区域")
            }
        }
        let dates = app.buttons["trip-date-overview"]
        let heading = app.staticTexts["trip-timeline-heading"]
        for element in [dates, heading] {
            XCTAssertTrue(element.isHittable)
            XCTAssertGreaterThan(element.frame.minY, app.frame.minY)
            XCTAssertLessThan(element.frame.maxY, app.frame.maxY)
        }
        // ScrollView 及其 AX 容器的 frame 包含裁切外子节点，不能代表实际绘制边界。
        // 底部以生产前景 frame/clipped 结构约束和六态截图核验，不把 AX 容器范围当成安全区。
    }

    private func assertArtworkReachesEveryScreenEdge(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return XCTFail("截图必须可读取像素") }
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let rendered = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(rendered)
        guard rendered else { return }
        // 使用画布比例避开圆角、状态文字、刘海与手势条，不写死某设备的系统 inset。
        let positions = (0..<32).map { Double($0) / 31 }
        let edges: [(String, [(Double, Double)])] = [
            ("左", positions.map { (0.008, 0.3 + $0 * 0.4) }),
            ("右", positions.map { (0.992, 0.3 + $0 * 0.4) }),
            ("上", positions.map { (0.18 + $0 * 0.12, 0.008) }),
            ("下", positions.map { (0.18 + $0 * 0.12, 0.992) }),
        ]
        for (edge, points) in edges {
            let colors = Set(points.map { x, y -> UInt32 in
                let index = (min(height - 1, Int(y * Double(height))) * width
                    + min(width - 1, Int(x * Double(width)))) * 4
                return UInt32(pixels[index]) << 16 | UInt32(pixels[index + 1]) << 8 | UInt32(pixels[index + 2])
            })
            XCTAssertGreaterThan(colors.count, 4, "\(edge)边应保留这组场景素材的图像纹理，不能出现纯色留白条")
        }
    }

    private func openYadingTripFromCalendar() {
        // RootView 与近期四 Tab 用例的真实入口仍是「我的 → 行程日历」，不是行程根焦点。
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 8))
        app.tabBars.buttons["我的"].tap()
        // 分发演示固定环境，不接受测试随机环境参数；重复运行可能保留合法Mock会话。
        if app.buttons["登录"].waitForExistence(timeout: 3) {
            app.buttons["登录"].tap()
            login()
        } else {
            XCTAssertTrue(button(containing: "行程日历").waitForExistence(timeout: 5), "未出现登录时必须已处于合法样例账户页面")
        }
        XCTAssertTrue(app.tabBars.buttons["我的"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["我的"].isSelected, "登录完成恢复原来的我的区域")
        let calendar = button(containing: "行程日历")
        XCTAssertTrue(calendar.waitForExistence(timeout: 8))
        scrollTo(calendar)
        calendar.tap()
        let trip = button(containing: "亚丁五日计划")
        XCTAssertTrue(trip.waitForExistence(timeout: 8))
        XCTAssertTrue(button(containing: "贡嘎环线三日计划").exists, "亚丁样例不能覆盖原贡嘎行程")
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        scrollTo(trip)
        trip.tap()
        XCTAssertTrue(app.buttons["trip-expedition-scene"].waitForExistence(timeout: 10))
    }

    private func selectDay(_ number: Int) {
        let day = app.buttons["trip-date-\(number)"]
        let dates = app.scrollViews.containing(.button, identifier: "trip-date-1").firstMatch
        for _ in 0..<5 {
            if day.exists && day.isHittable { break }
            let selected = (1...5).first { app.buttons["trip-date-\($0)"].isSelected } ?? 1
            if number < selected { dates.swipeRight() } else { dates.swipeLeft() }
        }
        XCTAssertTrue(day.isHittable, "第 \(number) 天日期应可以横向滚动到")
        day.tap()
        XCTAssertTrue(day.wait(for: \.isSelected, toEqual: true, timeout: 5))
    }

    private func login() {
        let phone = app.textFields["手机号"]
        XCTAssertTrue(phone.waitForExistence(timeout: 5))
        phone.tap()
        phone.typeText("+8613800138000")
        app.buttons["获取验证码"].tap()
        let code = app.textFields["验证码"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.tap()
        code.typeText("123456")
        app.buttons["登录并继续"].tap()
        XCTAssertTrue(phone.waitForNonExistence(timeout: 8))
    }

    private func button(containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func element(label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func scrollTo(_ element: XCUIElement) {
        for _ in 0..<10 {
            let back = app.buttons["返回"].firstMatch
            let top = back.exists ? back.frame.maxY + 12 : app.frame.minY + 100
            let bottom = app.frame.maxY - 55
            if element.exists, element.isHittable,
               element.frame.minY >= top, element.frame.maxY <= bottom { return }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let from = top + (bottom - top) * 0.8
            let to = top + (bottom - top) * 0.25
            origin.withOffset(CGVector(dx: app.frame.midX, dy: from))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: to)))
        }
        XCTAssertTrue(element.isHittable, "目标内容应能滚动到")
    }

    private func back() {
        let back = app.buttons["返回"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
    }

    private func capture(_ name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
