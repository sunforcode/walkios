import XCTest
import UIKit

/// 临时迁壳回归截图流程：批次 2 / 批次 3 页面截图，归档确认后整文件删除，不属于组件目录。
final class WalkTempBugFlowUITests: XCTestCase {
    /// 批次 2 迁壳回归：装备页 / 全部路线 / 路线搜索 / 生成行程页截图。跑完即删。
    @MainActor
    func testCaptureBatch2UnifiedShellPages() throws {
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        app.launchArguments = [
            "-DataSourceMode", "mock",
            "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
            "-WalkEnvironment", "test",
        ]
        app.launch()

        func snap(_ name: String) {
            let attachment = XCTAttachment(image: XCUIScreen.main.screenshot().image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        func tapIfExist(_ element: XCUIElement, _ name: String) {
            guard element.waitForExistence(timeout: 4) else {
                XCTContext.runActivity(named: "missing \(name)") { _ in }
                return
            }
            element.tap()
        }

        Thread.sleep(forTimeInterval: 3)

        // 登录（mock 验证码）
        app.tabBars.buttons["我的"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 2)
        let calendarCard = app.buttons.matching(NSPredicate(format: "label CONTAINS '行程日历'")).firstMatch
        if !calendarCard.waitForExistence(timeout: 3) {
            tapIfExist(app.buttons["登录"].firstMatch, "登录入口")
            let phoneField = app.textFields["手机号"].firstMatch
            XCTAssertTrue(phoneField.waitForExistence(timeout: 6), "手机号输入框未出现")
            phoneField.tap()
            phoneField.typeText("+8613800000000")
            tapIfExist(app.buttons["获取验证码"].firstMatch, "获取验证码")
            let codeField = app.textFields["验证码"].firstMatch
            XCTAssertTrue(codeField.waitForExistence(timeout: 6), "验证码输入框未出现")
            codeField.tap()
            codeField.typeText("123456")
            tapIfExist(app.buttons["登录并继续"].firstMatch, "登录并继续")
            Thread.sleep(forTimeInterval: 3)
        }

        // 装备页（迁壳代表页 1）
        let equipmentCard = app.buttons.matching(NSPredicate(format: "label CONTAINS '我的装备'")).firstMatch
        XCTAssertTrue(equipmentCard.waitForExistence(timeout: 6), "装备卡未出现")
        equipmentCard.tap()
        Thread.sleep(forTimeInterval: 2)
        snap("b2-01-equipment")
        // 滚动后截图：验证内容从悬浮导航行下方穿过（导航行不独占布局）。
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        snap("b2-01b-equipment-scrolled")
        app.swipeDown()
        Thread.sleep(forTimeInterval: 1)
        tapIfExist(app.buttons["清单"].firstMatch, "清单页签")
        Thread.sleep(forTimeInterval: 1.5)
        snap("b2-02-equipment-lists")
        tapIfExist(app.buttons["返回"].firstMatch, "返回(装备页)")
        Thread.sleep(forTimeInterval: 1)

        // 全部路线（从路线 tab 进）
        app.tabBars.buttons["路线"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 2)
        snap("b2-03-route-discovery")
        tapIfExist(app.buttons["全部路线"].firstMatch, "全部路线入口")
        Thread.sleep(forTimeInterval: 2)
        snap("b2-04-route-collection")

        // 路线搜索（hero 承载 sticky 输入区）
        tapIfExist(app.buttons["搜索路线"].firstMatch, "搜索入口")
        Thread.sleep(forTimeInterval: 2)
        snap("b2-05-route-search")
        tapIfExist(app.buttons["返回"].firstMatch, "返回(搜索页)")
        Thread.sleep(forTimeInterval: 1)
        tapIfExist(app.buttons["返回"].firstMatch, "返回(全部路线)")
        Thread.sleep(forTimeInterval: 1)

        // 生成行程页（迁壳代表页 2）：场景卡 → 详情 → 生成我的行程
        // 谓词必须精确到场景卡 label（'长海子，…'），避免误中「全部路线」入口或 tab 栏「路线」按钮。
        let sceneCard = app.buttons.matching(NSPredicate(format: "label CONTAINS '长海子'")).firstMatch
        XCTAssertTrue(sceneCard.waitForExistence(timeout: 6), "路线场景未出现")
        sceneCard.tap()
        Thread.sleep(forTimeInterval: 2)
        snap("b2-06-route-detail")
        // 详情页工具栏入口是「立即出发」，进入 CreateTripView 后提交按钮才是「生成我的行程」。
        let depart = app.buttons["立即出发"].firstMatch
        XCTAssertTrue(depart.waitForExistence(timeout: 6), "立即出发按钮未出现")
        depart.tap()
        Thread.sleep(forTimeInterval: 2)
        let generate = app.buttons["生成我的行程"].firstMatch
        XCTAssertTrue(generate.waitForExistence(timeout: 6), "生成我的行程按钮未出现")
        Thread.sleep(forTimeInterval: 1)
        snap("b2-07-create-trip")
        // 滚动后截图：验证长表单页滚动时内容从悬浮导航行下方穿过。
        app.swipeUp()
        Thread.sleep(forTimeInterval: 1)
        snap("b2-07b-create-trip-scrolled")
    }

    /// 批次 3 迁壳回归：行程详情（封面入 hero）/ 逐日浏览（browseHero 入 hero）截图。跑完即删。
    @MainActor
    func testCaptureBatch3TripHeroPages() throws {
        XCUIDevice.shared.orientation = .portrait

        let app = XCUIApplication()
        app.launchArguments = [
            "-DataSourceMode", "mock",
            "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
            "-WalkEnvironment", "test",
        ]
        app.launch()

        func snap(_ name: String) {
            let attachment = XCTAttachment(image: XCUIScreen.main.screenshot().image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        Thread.sleep(forTimeInterval: 3)

        // 登录（mock 验证码；已有登录态则直接复用）
        app.tabBars.buttons["我的"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 2)
        let calendarCard = app.buttons.matching(NSPredicate(format: "label CONTAINS '行程日历'")).firstMatch
        if !calendarCard.waitForExistence(timeout: 3) {
            app.buttons["登录"].firstMatch.tap()
            let phoneField = app.textFields["手机号"].firstMatch
            XCTAssertTrue(phoneField.waitForExistence(timeout: 6), "手机号输入框未出现")
            phoneField.tap()
            phoneField.typeText("+8613800000000")
            app.buttons["获取验证码"].firstMatch.tap()
            let codeField = app.textFields["验证码"].firstMatch
            XCTAssertTrue(codeField.waitForExistence(timeout: 6), "验证码输入框未出现")
            codeField.tap()
            codeField.typeText("123456")
            app.buttons["登录并继续"].firstMatch.tap()
            Thread.sleep(forTimeInterval: 3)
        }

        // 行程日历卡 → 我的全部行程 → 行程详情
        XCTAssertTrue(calendarCard.waitForExistence(timeout: 6), "行程日历卡未出现")
        calendarCard.tap()
        Thread.sleep(forTimeInterval: 2)
        let tripRow = app.staticTexts["贡嘎环线三日计划"].firstMatch
        XCTAssertTrue(tripRow.waitForExistence(timeout: 6), "行程行未出现")
        tripRow.tap()
        Thread.sleep(forTimeInterval: 2.5)
        snap("b3-01-trip-detail-hero")

        // 概览日入口 → 逐日阅读（browseHero 入壳 hero）
        let dayEntry = app.descendants(matching: .any)
            .matching(identifier: "baseline.trip-detail.overview.day.1").firstMatch
        // 概览区在详情页下方，滚动至可见再点。
        var attempts = 0
        while !dayEntry.isHittable && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(dayEntry.waitForExistence(timeout: 4), "逐日入口未出现")
        dayEntry.tap()
        Thread.sleep(forTimeInterval: 2)
        snap("b3-02-trip-browse-hero")

        // 返回详情，确认壳导航行返回可用
        app.buttons["返回"].firstMatch.tap()
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(app.buttons["返回"].firstMatch.exists, "返回详情页后导航行未出现")
        snap("b3-03-back-to-detail")
    }
}
