import XCTest

@MainActor
final class IsolationUITests: XCTestCase {
    func testBuildSpecificEntry() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
#if DEBUG
        let entry = app.buttons["probe.open-debug-tools"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "The SDK panel must actually open")
        XCTAssertTrue(app.staticTexts["W0 Probe"].waitForExistence(timeout: 3), "The SDK must display injected custom data")
        app.staticTexts["W0 Probe"].tap()
        XCTAssertTrue(app.navigationBars["W0 Probe"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["SDK\nDebugSwift 1.19.0"].waitForExistence(timeout: 3), "The SDK exposes its title and injected value as one accessibility label")
#else
        XCTAssertTrue(app.staticTexts["probe.production"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["probe.open-debug-tools"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
#endif
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "isolation-probe"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
