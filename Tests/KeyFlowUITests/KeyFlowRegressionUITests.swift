import XCTest

/// W6 关键流程回归：Mock 模式下走通五个业务域主链路与登录。
///
/// 依据 specs/README.md R-VERIFY「业务与 UI：受影响的导航、登录、五域加载与操作回归」。
/// 用例要求从未登录状态开始并显式登录，不依赖模拟器残留登录态。Keychain 在卸载 App 后仍保留，
/// 因此运行前需重置模拟器 Keychain（`scripts/run_key_flow_regression.sh` 负责）；
/// 入口按合并后的无障碍标签前缀定位（卡片以 `.combine` 合并子元素），不用会与引导文案重名的片段判断状态。
final class KeyFlowRegressionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-WalkDataMode", "mock",
            "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
            "-WalkEnvironment", "w6-keyflow",
        ]
        app.launch()
    }

    @MainActor
    func testFiveDomainsAndLogin() throws {
        // 路线：发现页卡片 → 详情
        tab("路线")
        let routeScene = button(labelContaining: "长海子")
        XCTAssertTrue(routeScene.waitForExistence(timeout: 10), "路线发现页未展示路线")
        capture("01-routes-discovery")
        routeScene.tap()
        XCTAssertTrue(app.buttons["立即出发"].firstMatch.waitForExistence(timeout: 10), "路线详情未加载")
        capture("02-route-detail")

        // 登录：由需要认证的动作触发，完成后回到原任务继续
        app.buttons["立即出发"].firstMatch.tap()
        login()
        // 创建行程页以「生成行程」为页标题（UtilityPage）。
        let createTitle = app.staticTexts.matching(NSPredicate(format: "label == %@", "生成行程")).firstMatch
        XCTAssertTrue(createTitle.waitForExistence(timeout: 10), "登录后未回到创建行程任务")
        capture("03-create-trip-after-login")

        // 首页：焦点行程
        tab("首页")
        let focus = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "继续行程：")).firstMatch
        XCTAssertTrue(focus.waitForExistence(timeout: 10), "首页未展示焦点行程")
        capture("04-home-focus")

        // 行程：焦点行程 → 详情 → 天气、装备
        focus.tap()
        // 行程天气区的逐日行是进入天气页的按钮（D1 起，含温度范围）。
        let weatherEntry = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "D1,", "°C")
        ).firstMatch
        XCTAssertTrue(weatherEntry.waitForExistence(timeout: 10), "行程详情未加载")
        capture("05-trip-detail")
        scrollTo(weatherEntry).tap()
        Thread.sleep(forTimeInterval: 1.5)
        capture("06-trip-weather")
        back()
        let equipmentEntry = button(labelBeginsWith: "行程装备")
        scrollTo(equipmentEntry).tap()
        Thread.sleep(forTimeInterval: 1.5)
        capture("07-trip-equipment")
        back()

        // 装备与我的：我的页 → 我的装备
        tab("我的")
        let myEquipment = button(labelBeginsWith: "我的装备，")
        XCTAssertTrue(myEquipment.waitForExistence(timeout: 10), "我的页未展示装备入口（未登录或加载失败）")
        capture("08-profile")
        scrollTo(myEquipment).tap()
        Thread.sleep(forTimeInterval: 1.5)
        capture("09-personal-equipment")
    }

    /// 路线发现页当前路线卡片必须在无障碍树中可达（VoiceOver 可读、可激活）。
    /// 依据 PAGE-ROUTES：换页后只让当前 RouteScene 进入焦点顺序，而不是全部隐藏。
    @MainActor
    func testDiscoveryCurrentRouteIsAccessible() throws {
        tab("路线")
        let routeScene = button(labelContaining: "长海子")
        XCTAssertTrue(routeScene.waitForExistence(timeout: 10), "发现页当前路线卡片不在无障碍树中")
        routeScene.tap()
        XCTAssertTrue(app.buttons["立即出发"].firstMatch.waitForExistence(timeout: 10), "从发现页卡片未进入路线详情")
    }

    // MARK: - Helpers

    /// Tab bar 只在一级根页可见（二级任务栈内隐藏），切换前先返回到根页。
    private func tab(_ title: String) {
        let item = app.tabBars.buttons[title].firstMatch
        var attempts = 0
        while !item.exists && attempts < 6 {
            back()
            attempts += 1
        }
        XCTAssertTrue(item.waitForExistence(timeout: 5), "无法回到一级页切换到 \(title)")
        item.tap()
    }

    private func button(labelBeginsWith prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func button(labelContaining text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func login() {
        let phone = app.textFields["手机号"].firstMatch
        XCTAssertTrue(phone.waitForExistence(timeout: 10), "未弹出登录")
        phone.tap()
        phone.typeText("+8613800138000")
        app.buttons["获取验证码"].firstMatch.tap()
        let code = app.textFields["验证码"].firstMatch
        XCTAssertTrue(code.waitForExistence(timeout: 10), "验证码输入未出现")
        code.tap()
        code.typeText("123456")
        app.buttons["登录并继续"].firstMatch.tap()
        XCTAssertTrue(phone.waitForNonExistence(timeout: 10), "登录未完成")
    }

    @discardableResult
    private func scrollTo(_ element: XCUIElement) -> XCUIElement {
        var attempts = 0
        while !element.isHittable && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.isHittable, "无法滚动到目标入口")
        return element
    }

    private func back() {
        let backButton = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "返回", "Back")).firstMatch
        if backButton.waitForExistence(timeout: 3) {
            backButton.tap()
        } else {
            app.swipeRight()
        }
        Thread.sleep(forTimeInterval: 1)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
