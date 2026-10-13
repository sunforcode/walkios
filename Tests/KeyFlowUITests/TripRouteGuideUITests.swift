import XCTest

final class TripRouteGuideUITests: XCTestCase {
    @MainActor
    func testReferenceGuideAndLongTextUseProductionComponent() {
        for state in ["referenceGuide", "referenceGuideLong"] {
            let app = launch(state)
            let guide = app.descendants(matching: .any).matching(identifier: "trip-route-guide").firstMatch
            XCTAssertTrue(guide.exists)
            capture(app, "route-guide-\(state)-top")
            let end = text(containing: "参考范围未确认实际活动方式", in: app)
            for _ in 0..<35 {
                if end.exists, end.isHittable, end.frame.maxY < app.frame.maxY - 80 { break }
                app.swipeUp()
            }
            XCTAssertTrue(end.isHittable, "长说明后的参考指标及置信来源必须仍可读")
            XCTAssertTrue(text(containing: "参考日行进", in: app).exists)
            XCTAssertTrue(text(containing: "9.2 km", in: app).exists)
            XCTAssertTrue(text(containing: "住宿参考：信息未知", in: app).exists)
            capture(app, "route-guide-\(state)-reference-metrics")
            app.terminate()
        }
    }

    @MainActor
    func testUnknownHikeSectionNoticeIsVisibleWithoutMetricValues() {
        let app = launch("hikeSectionUnavailable")
        XCTAssertTrue(text(containing: "徒步路段：信息不可用", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(text(containing: "预计耗时：信息不可用", in: app).exists)
        capture(app, "route-guide-hike-section-unavailable")
        app.terminate()
    }

    @MainActor
    private func launch(_ state: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-WalkDataMode", "mock", "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
                               "-WalkEnvironment", "route-guide-component", "--component-preview", "TripDayArrangement", state]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(identifier: "component-preview-ready:TripDayArrangement:\(state)").firstMatch.waitForExistence(timeout: 10))
        return app
    }

    private func text(containing value: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
