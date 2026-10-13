import XCTest

/// 四个 Tab 与 restore-trip-tab-home：生产页面 + 同一 Mock 数据客户端。
final class FourTabEquipmentUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // 每项用例使用新的会话命名空间，不改动开发者的其他登录态。
        app.launchArguments = ["-WalkDataMode", "mock", "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
                               "-WalkEnvironment", "four-tabs-\(UUID().uuidString)"]
        app.launch()
    }

    @MainActor
    func testSourcePickerIndependentProductionPreview() {
        app.terminate()
        app.launchArguments += ["--component-preview", "TripEquipmentSourcePicker", "default"]
        app.launch()
        let ready = app.descendants(matching: .any)
            .matching(identifier: "component-preview-ready:TripEquipmentSourcePicker:default").firstMatch
        XCTAssertTrue(ready.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["从已有装备准备本次行程"].exists)
        capture("trip-equipment-source-picker-component")
    }

    @MainActor
    func testRestoredHomeComponentsHaveIndependentProductionPreviews() {
        for component in ["FocusTripSummary", "WeatherSummary"] {
            app.terminate()
            app.launchArguments = ["-WalkDataMode", "mock", "--component-preview", component, "default"]
            app.launch()
            let ready = app.descendants(matching: .any)
                .matching(identifier: "component-preview-ready:\(component):default").firstMatch
            XCTAssertTrue(ready.waitForExistence(timeout: 10))
            capture("restored-\(component)")
        }
    }

    @MainActor
    func testTripTabKeepsHomeSceneAndCalendarOpensSecondaryTripList() {
        XCTAssertTrue(app.tabBars.buttons["行程"].waitForExistence(timeout: 10))
        app.tabBars.buttons["行程"].tap()
        XCTAssertTrue(app.buttons["开启一次新的徒步行程"].waitForExistence(timeout: 5))
        capture("trip-tab-original-home-guest")
        app.buttons["开启一次新的徒步行程"].tap()
        login()
        let focus = button(containing: "继续行程：贡嘎环线")
        XCTAssertTrue(focus.waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["行程"].isSelected)
        XCTAssertFalse(app.staticTexts["当前行程"].exists)
        XCTAssertFalse(app.staticTexts["历史行程"].exists)
        capture("trip-tab-original-home-focus")
        focus.tap()
        XCTAssertTrue(app.buttons["返回"].waitForExistence(timeout: 8))
        XCTAssertTrue(scrollTo(button(containing: "行程装备")).exists)
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(focus.waitForExistence(timeout: 8))
        app.tabBars.buttons["我的"].tap()
        let calendar = button(containing: "行程日历")
        XCTAssertTrue(calendar.waitForExistence(timeout: 8))
        calendar.tap()
        XCTAssertTrue(button(containing: "贡嘎环线三日计划").waitForExistence(timeout: 8))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertTrue(app.buttons["返回"].exists)
        capture("all-trips-secondary-page")
        app.buttons["返回"].tap()
        XCTAssertTrue(calendar.waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["我的"].isSelected)
    }

    @MainActor
    func testCinematicTripDetailKeepsWeatherAndEquipmentSeparate() {
        XCTAssertTrue(app.tabBars.buttons["装备"].waitForExistence(timeout: 10))
        app.tabBars.buttons["装备"].tap()
        app.buttons["登录"].tap()
        login()
        app.tabBars.buttons["行程"].tap()
        let focus = button(containing: "继续行程：贡嘎环线")
        XCTAssertTrue(focus.waitForExistence(timeout: 8))
        focus.tap()
        let equipment = app.buttons["trip-equipment-summary"]
        XCTAssertTrue(equipment.waitForExistence(timeout: 10))
        let weather = app.buttons.matching(identifier: "trip-weather-day-summary").firstMatch
        XCTAssertTrue(weather.exists)
        XCTAssertLessThan(equipment.frame.maxY, weather.frame.minY, "装备常驻右上，天气与日期同排")
        XCTAssertFalse(app.buttons["查看行程"].exists)
        XCTAssertFalse(app.buttons["调整装备"].exists)
        capture("cinematic-trip-detail")
        equipment.tap()
        XCTAssertTrue(app.buttons["从我的装备选入"].waitForExistence(timeout: 10))
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(equipment.waitForExistence(timeout: 10))
        weather.tap()
        XCTAssertTrue(app.staticTexts["行程天气"].waitForExistence(timeout: 10))
        capture("trip-detail-weather-destination")
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(equipment.waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    @MainActor
    func testExpeditionOverviewDailySelectionAndFixedTimeline() {
        app.tabBars.buttons["装备"].tap()
        app.buttons["登录"].tap()
        login()
        app.tabBars.buttons["行程"].tap()
        let focus = button(containing: "继续行程：贡嘎环线")
        XCTAssertTrue(focus.waitForExistence(timeout: 8))
        focus.tap()
        let scene = app.buttons["trip-expedition-scene"]
        let overview = app.buttons["trip-date-overview"]
        XCTAssertTrue(scene.waitForExistence(timeout: 10))
        XCTAssertTrue(overview.isSelected)
        XCTAssertLessThanOrEqual(app.buttons["trip-equipment-summary"].frame.width, 48, "装备仅保留44pt图标入口")
        XCTAssertFalse(app.buttons["trip-public-route"].exists, "正文不再放公共路线卡")
        let identity = app.descendants(matching: .any).matching(identifier: "trip-expedition-identity").firstMatch
        XCTAssertTrue(identity.label.contains("8月25–8月27日"))
        XCTAssertFalse(identity.label.contains("全程总览"))
        let metrics = app.descendants(matching: .any).matching(identifier: "trip-expedition-metrics").firstMatch
        XCTAssertTrue(metrics.exists)
        XCTAssertLessThanOrEqual(metrics.frame.maxY, app.buttons["trip-date-overview"].frame.minY)
        let elevation = app.descendants(matching: .any).matching(identifier: "trip-scene-elevation").firstMatch
        let notices = app.scrollViews["trip-scene-notices"]
        XCTAssertTrue(elevation.exists)
        XCTAssertLessThan(elevation.frame.midX, scene.frame.midX)
        XCTAssertLessThan(elevation.frame.minY, scene.frame.minY + 40)
        XCTAssertFalse(notices.exists, "原始提醒非空也不再显示集中提醒区")
        XCTAssertFalse(app.staticTexts["行程提醒"].exists)
        XCTAssertFalse(app.staticTexts["AIGC 场景示意"].exists)
        XCTAssertTrue(scene.label.contains("AIGC 场景示意"), "可访问来源语义保持")
        capture("expedition-overview")
        scene.tap()
        XCTAssertTrue(app.buttons["trip-date-1"].isSelected)
        capture("expedition-arrival")
        app.buttons["trip-date-2"].tap()
        XCTAssertTrue(app.buttons["trip-date-2"].isSelected)
        app.buttons["trip-date-2"].tap()
        XCTAssertTrue(scene.exists, "重复日期仍停留摘要")
        let timelineHeading = app.staticTexts["trip-timeline-heading"]
        XCTAssertEqual(timelineHeading.label, "当日走法")
        // StaticText 的可访问 frame 是字形范围，不是外层排版宽度。
        XCTAssertLessThanOrEqual(timelineHeading.frame.maxX, scene.frame.maxX - 16)
        capture("expedition-valley")
        let fixedFrame = scene.frame
        let headingFrame = timelineHeading.frame
        let timeline = app.scrollViews["trip-expedition-timeline"]
        timeline.swipeUp()
        XCTAssertEqual(scene.frame.minY, fixedFrame.minY, accuracy: 1)
        XCTAssertEqual(timelineHeading.frame.minY, headingFrame.minY, accuracy: 1, "标题留在滚动区外")
        XCTAssertTrue(app.buttons["trip-equipment-summary"].isHittable)
        capture("expedition-timeline-scrolled")
        XCTAssertFalse(notices.exists)
        XCTAssertTrue(app.buttons["trip-date-2"].isSelected, "摘要滚动不会触发每日切换或打开详情")
        XCTAssertTrue(scene.exists)
        scene.swipeLeft()
        XCTAssertTrue(app.buttons["trip-date-3"].wait(for: \.isSelected, toEqual: true, timeout: 5))
        scene.swipeLeft()
        XCTAssertTrue(app.buttons["trip-date-3"].isSelected, "末日不循环")
        capture("expedition-pass")
        scene.swipeRight()
        XCTAssertTrue(app.buttons["trip-date-2"].wait(for: \.isSelected, toEqual: true, timeout: 5))
        scene.tap()
        XCTAssertTrue(scene.waitForNonExistence(timeout: 8), "点日场景完成转场后进入完整每日安排")
        XCTAssertTrue(app.buttons["返回"].waitForExistence(timeout: 8))
        capture("expedition-daily-detail")
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(scene.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["trip-date-2"].isSelected)
        overview.tap()
        XCTAssertTrue(overview.isSelected)
        app.buttons["trip-detail-more"].tap()
        XCTAssertTrue(app.buttons["公共路线详情"].exists, "公共路线改由更多菜单承接")
        app.buttons["取消行程"].tap()
        XCTAssertTrue(app.staticTexts["确认取消这趟行程？"].waitForExistence(timeout: 5))
        if app.sheets.buttons["返回"].exists {
            app.sheets.buttons["返回"].tap()
        } else {
            // iOS 26 的居中确认气泡通过点按外部取消，不渲染 cancel-role 按钮。
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.85)).tap()
        }
        XCTAssertFalse(app.sheets["确认取消这趟行程？"].exists)
        XCTAssertTrue(scene.exists)
        XCTAssertTrue(overview.isSelected)
    }

    @MainActor
    func testSceneInformationAndContextComponents() {
        for (component, state) in [
            ("TripExpeditionScene", "overview"),
            ("TripExpeditionScene", "hikingDay"),
            ("TripExpeditionScene", "arrival"),
            ("TripExpeditionScene", "unavailable"),
            ("TripExpeditionScene", "noticesLong"),
            ("TripExpeditionScene", "accessible"),
            ("TripCoverHeader", "identityOverviewDate"),
            ("TripCoverHeader", "identityDayEndpoints"),
        ] {
            app.terminate()
            app.launchArguments = ["-WalkDataMode", "mock", "--component-preview", component, state]
            app.launch()
            let ready = app.descendants(matching: .any)
                .matching(identifier: "component-preview-ready:\(component):\(state)").firstMatch
            XCTAssertTrue(ready.waitForExistence(timeout: 10))
            capture("scene-information-\(component)-\(state)")
        }
    }

    @MainActor
    func testSubtleTripDetailComponents() {
        for (component, state) in [
            ("Timeline", "compactCrossMonth"),
            ("Timeline", "compactTime"),
            ("TripCoverHeader", "identityWithoutSubtitle"),
            ("TripEquipmentSummaryCard", "iconPartialWeight"),
            ("Notice", "inline"),
        ] {
            app.terminate()
            app.launchArguments = ["-WalkDataMode", "mock", "--component-preview", component, state]
            app.launch()
            let ready = app.descendants(matching: .any)
                .matching(identifier: "component-preview-ready:\(component):\(state)").firstMatch
            XCTAssertTrue(ready.waitForExistence(timeout: 10))
            capture("subtle-\(component)-\(state)")
        }
    }

    @MainActor
    func testTripDetailVisualComponentsAtCompactWidths() {
        let previews = [
            ("TripExpeditionScene", "overview"),
            ("TripExpeditionScene", "hikingDay"),
            ("TripExpeditionScene", "arrival"),
            ("TripExpeditionScene", "unavailable"),
            ("TripCoverHeader", "identity"),
            ("TripCoverHeader", "default"),
            ("TripCoverHeader", "longName"),
            ("TripCoverHeader", "largeText"),
            ("DailyWeatherSummaryRow", "compact"),
            ("DailyWeatherSummaryRow", "compactUnavailable"),
            ("DailyWeatherSummaryRow", "inline"),
            ("DailyWeatherSummaryRow", "inlineUnavailable"),
            ("TripEquipmentSummaryCard", "dashboardPartialWeight"),
            ("TripEquipmentSummaryCard", "dashboardReadonly"),
            ("TripEquipmentSummaryCard", "compactPartialWeight"),
            ("TripEquipmentSummaryCard", "compactReadonly"),
        ]
        for (component, state) in previews {
            app.terminate()
            app.launchArguments = ["-WalkDataMode", "mock", "--component-preview", component, state]
            app.launch()
            let ready = app.descendants(matching: .any)
                .matching(identifier: "component-preview-ready:\(component):\(state)").firstMatch
            XCTAssertTrue(ready.waitForExistence(timeout: 10))
            capture("trip-detail-\(component)-\(state)")
        }
    }

    @MainActor
    func testGuestTabsAndCancelledLoginPreserveEquipmentRoot() {
        XCTAssertTrue(app.tabBars.buttons["行程"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.tabBars.buttons.allElementsBoundByIndex.map(\.label), ["行程", "路线", "装备", "我的"])
        XCTAssertTrue(app.tabBars.buttons["行程"].isSelected)
        XCTAssertTrue(app.buttons["开启一次新的徒步行程"].waitForExistence(timeout: 5), "行程 Tab 应承接原首页游客场景")
        XCTAssertFalse(app.staticTexts["当前行程"].exists, "行程根页不能被全部行程列表替代")
        XCTAssertFalse(app.textFields["手机号"].exists)
        app.tabBars.buttons["装备"].tap()
        XCTAssertTrue(app.staticTexts["登录后管理个人装备与清单"].waitForExistence(timeout: 5))
        app.buttons["登录"].tap()
        XCTAssertTrue(app.textFields["手机号"].waitForExistence(timeout: 5))
        app.buttons["关闭登录"].tap()
        XCTAssertTrue(app.staticTexts["登录后管理个人装备与清单"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["装备"].isSelected)
        capture("four-tabs-guest")
    }

    @MainActor
    func testEquipmentCreateAndTripSelectionReturnToSameContext() {
        XCTAssertTrue(app.tabBars.buttons["装备"].waitForExistence(timeout: 10))
        app.tabBars.buttons["装备"].tap()
        app.buttons["登录"].tap()
        login()
        XCTAssertTrue(app.buttons["新增个人装备"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["装备"].isSelected)
        XCTAssertLessThanOrEqual(app.buttons["新增个人装备"].frame.maxY, app.tabBars.firstMatch.frame.minY,
                                 "固定新增动作不得被系统 Tab 遮挡")
        capture("equipment-tab-library")
        app.buttons["新增个人装备"].tap()
        XCTAssertTrue(app.textFields["装备名称"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.buttons["装备"].exists)
        app.textFields["装备名称"].tap()
        app.textFields["装备名称"].typeText("轻量测试头灯")
        let save = app.buttons["保存"]
        let weight = app.textFields["单件重量（克）"]
        scrollTo(weight).tap()
        XCTAssertLessThan(weight.frame.maxY, save.frame.minY)
        app.textFields["单件重量（克）"].typeText("12.5")
        XCTAssertEqual(app.textFields["单件重量（克）"].value as? String, "12.5")
        app.buttons["保存"].tap()
        let personalItem = button(containing: "轻量测试头灯")
        XCTAssertTrue(personalItem.waitForExistence(timeout: 8), "保存后装备库必须反映真实返回结果")
        XCTAssertTrue(app.tabBars.buttons["装备"].exists)

        app.tabBars.buttons["我的"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "行程日历")).firstMatch.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "我的装备，")).firstMatch.exists)
        app.tabBars.buttons["行程"].tap()
        let trip = button(containing: "继续行程：贡嘎环线")
        XCTAssertTrue(trip.waitForExistence(timeout: 8))
        trip.tap()
        scrollTo(button(containing: "行程装备")).tap()
        scrollTo(app.buttons["从我的装备选入"]).tap()
        XCTAssertTrue(app.staticTexts["从已有装备准备本次行程"].waitForExistence(timeout: 5))
        scrollTo(button(containing: "轻量测试头灯")).tap()
        scrollTo(app.buttons["选入本次行程"]).tap()
        XCTAssertTrue(app.buttons["修改轻量测试头灯"].waitForExistence(timeout: 8))
        capture("trip-selected-personal-equipment")

        scrollTo(app.buttons["追加常用清单"]).tap()
        XCTAssertTrue(app.staticTexts["从已有装备准备本次行程"].waitForExistence(timeout: 5))
        scrollTo(button(containing: "周末露营")).tap()
        scrollTo(app.buttons["追加整份清单"]).tap()
        XCTAssertTrue(app.buttons["追加常用清单"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["修改轻量帐篷"].waitForExistence(timeout: 8))
        scrollTo(app.buttons["管理我的装备"]).tap()
        XCTAssertTrue(app.buttons["新增个人装备"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.tabBars.buttons["装备"].exists, "行程来源的管理应留在原任务栈")
        app.buttons["返回"].firstMatch.tap()
        XCTAssertTrue(app.buttons["修改轻量测试头灯"].waitForExistence(timeout: 8))
        capture("trip-equipment-after-management-return")
    }

    @MainActor
    func testEquipmentFormSelectionStatesHaveIndependentPreviews() {
        for state in ["create", "typeSelected", "referenceWeightConfirmation"] {
            app.terminate()
            app.launchArguments = ["-WalkDataMode", "mock", "--component-preview", "PersonalEquipmentForm", state]
            app.launch()
            let marker = app.descendants(matching: .any)
                .matching(identifier: "component-preview-ready:PersonalEquipmentForm:\(state)").firstMatch
            XCTAssertTrue(marker.waitForExistence(timeout: 10))
            XCTAssertTrue(button(containing: "装备分类").exists)
            let type = button(containing: "装备类型")
            XCTAssertTrue(type.exists)
            if state == "create" {
                XCTAssertFalse(type.isEnabled)
            } else if state == "typeSelected" {
                XCTAssertTrue(type.label.contains("睡袋"))
            } else {
                XCTAssertTrue(app.staticTexts["更改分类或类型后，请重新输入或清空参考重量"].exists)
            }
            capture("equipment-form-\(state)")
        }
    }

    @MainActor
    func testEquipmentCategoryAndTypeSelectionsPersist() {
        XCTAssertTrue(app.tabBars.buttons["装备"].waitForExistence(timeout: 10))
        app.tabBars.buttons["装备"].tap()
        app.buttons["登录"].tap()
        login()

        for choice in [(category: "背包", type: "背包", name: "徒步背包"),
                       (category: "睡眠系统", type: "睡袋", name: "冬季睡袋")] {
            XCTAssertTrue(app.buttons["新增个人装备"].waitForExistence(timeout: 8))
            app.buttons["新增个人装备"].tap()
            XCTAssertTrue(app.textFields["装备名称"].waitForExistence(timeout: 5))
            let category = button(containing: "装备分类")
            XCTAssertTrue(category.waitForExistence(timeout: 5), "新增装备必须提供分类选择框")
            category.tap()
            app.buttons[choice.category].tap()
            let type = button(containing: "装备类型")
            scrollTo(type).tap()
            app.buttons[choice.type].tap()
            let name = app.textFields["装备名称"]
            scrollTo(name).tap()
            name.typeText(choice.name)
            app.buttons["保存"].tap()
            let item = button(containing: choice.name)
            XCTAssertTrue(item.waitForExistence(timeout: 8))
            item.tap()
            XCTAssertTrue(app.textFields["装备名称"].waitForExistence(timeout: 5))
            XCTAssertTrue(button(containing: "装备分类").label.contains(choice.category))
            XCTAssertTrue(button(containing: "装备类型").label.contains(choice.type))
            capture("equipment-selector-\(choice.type)")
            app.buttons["返回"].tap()
        }
    }

    @MainActor
    func testEquipmentListCanRenameAndEditMembers() {
        XCTAssertTrue(app.tabBars.buttons["装备"].waitForExistence(timeout: 10))
        app.tabBars.buttons["装备"].tap()
        app.buttons["登录"].tap()
        login()
        XCTAssertTrue(app.buttons["新增个人装备"].waitForExistence(timeout: 10))
        app.buttons["清单"].tap()
        XCTAssertTrue(app.staticTexts["周末露营"].waitForExistence(timeout: 5))

        scrollTo(app.buttons["重命名"]).tap()
        let name = app.textFields["清单名称"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        scrollTo(name).tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "周末露营".count))
        name.typeText("秋季露营")
        XCTAssertEqual(name.value as? String, "秋季露营")
        app.buttons["保存清单"].tap()
        XCTAssertTrue(name.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["秋季露营"].exists)

        scrollTo(app.buttons["展开"]).tap()
        let add = app.buttons["添加个人装备到清单"]
        scrollTo(add).tap()
        app.buttons["修补贴"].tap()
        let remove = app.buttons["从秋季露营移除修补贴"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        let quantity = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "秋季露营中修补贴的数量")).firstMatch
        scrollTo(quantity.buttons["增加"]).tap()
        let two = NSPredicate(format: "value == %@", "2")
        expectation(for: two, evaluatedWith: quantity)
        waitForExpectations(timeout: 5)
        capture("equipment-list-edited-members")

        scrollTo(app.buttons["收起"]).tap()
        scrollTo(app.buttons["展开"]).tap()
        XCTAssertTrue(quantity.waitForExistence(timeout: 5))
        XCTAssertEqual(quantity.value as? String, "2", "重新读取清单后数量必须保留")
        scrollTo(remove).tap()
        XCTAssertTrue(remove.waitForNonExistence(timeout: 5))
        scrollTo(app.buttons["收起"]).tap()
        scrollTo(app.buttons["展开"]).tap()
        XCTAssertTrue(app.buttons["从秋季露营移除轻量帐篷"].waitForExistence(timeout: 5))
        XCTAssertFalse(remove.exists, "重新读取清单后被移除的成员不能恢复")
        capture("equipment-list-after-member-removal")
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

    private func scrollTo(_ element: XCUIElement) -> XCUIElement {
        if element.identifier == "trip-equipment-summary", element.isHittable { return element }
        for _ in 0..<16 {
            let back = app.buttons["返回"].firstMatch
            let top = back.exists ? back.frame.maxY + 12 : app.frame.minY + 100
            var bottom = app.frame.maxY - 40
            if app.tabBars.firstMatch.exists { bottom = min(bottom, app.tabBars.firstMatch.frame.minY - 12) }
            for title in ["新增本次装备", "保存本次装备", "新增个人装备", "创建装备清单", "保存清单", "保存"] {
                let action = app.buttons[title]
                if action.exists { bottom = min(bottom, action.frame.minY - 12) }
            }
            if element.exists, element.isHittable, element.isEnabled,
               element.frame.minY >= top, element.frame.maxY <= bottom { return element }
            // 从内容区拖动，不把「部分露出」误判为可点击，也不触及固定操作。
            let down = element.exists && element.frame.minY < top
            let start = top + (bottom - top) * (down ? 0.25 : 0.75)
            let end = top + (bottom - top) * (down ? 0.75 : 0.25)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.midX, dy: start))
                .press(forDuration: 0.1, thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: end)))
        }
        XCTAssertTrue(element.isHittable, "操作必须在当前页面可达")
        return element
    }

    private func capture(_ name: String) {
        // 等待场景淡入结束，截图验证稳定状态而非转场中间帧。
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
