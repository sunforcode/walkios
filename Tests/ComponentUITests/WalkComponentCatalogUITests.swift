import XCTest
import UIKit
import WalkData
import WalkDesignSystem

final class WalkComponentCatalogUITests: XCTestCase {
    @MainActor
    func testEveryDefaultComponentLaunchesAndBecomesReady() throws {
        XCUIDevice.shared.orientation = .portrait

        for componentID in Self.componentIDs {
            let app = XCUIApplication()
            app.launchArguments = [
                "-WalkDataMode", "mock",
                "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
                "-WalkEnvironment", "test",
                "--component-preview", componentID, "default",
            ]
            app.launch()

            let readyID = "component-preview-ready:\(componentID):default"
            let unsupportedID = "component-preview-unsupported:\(componentID):default"
            let readyMarker = app.descendants(matching: .any).matching(identifier: readyID).firstMatch
            let unsupportedMarker = app.descendants(matching: .any).matching(identifier: unsupportedID).firstMatch
            let canvas = app.descendants(matching: .any)
                .matching(identifier: "component-preview-canvas")
                .firstMatch

            XCTAssertTrue(canvas.waitForExistence(timeout: 10), "Component canvas is missing: \(componentID)")
            XCTAssertTrue(readyMarker.exists, "Component did not become ready: \(componentID)")
            XCTAssertFalse(unsupportedMarker.exists, "Component rendered unsupported marker: \(componentID)")

            let image = try cropComponentCanvas(from: XCUIScreen.main.screenshot().image)
            let attachment = XCTAttachment(image: image)
            attachment.name = "component-\(componentID)--default.png"
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
        }
    }

    @MainActor
    func testTripExpeditionSceneUsesSingleArtworkInEveryLocalState() {
        XCUIDevice.shared.orientation = .portrait
        for state in ["overview", "hikingDay", "arrival", "unavailable", "noticesLong", "accessible"] {
            let app = XCUIApplication()
            app.launchArguments = [
                "-WalkDataMode", "mock",
                "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
                "-WalkEnvironment", "test",
                "--component-preview", "TripExpeditionScene", state,
            ]
            app.launch()
            let ready = app.descendants(matching: .any)
                .matching(identifier: "component-preview-ready:TripExpeditionScene:\(state)").firstMatch
            XCTAssertTrue(ready.waitForExistence(timeout: 10))
            let scene = app.buttons["trip-expedition-scene"]
            XCTAssertTrue(scene.exists)
            XCTAssertTrue(scene.label.contains("AIGC 场景示意"))
            let elevation = app.descendants(matching: .any).matching(identifier: "trip-scene-elevation").firstMatch
            XCTAssertTrue(elevation.exists)
            XCTAssertFalse(app.staticTexts["AIGC 场景示意"].exists)
            XCTAssertFalse(app.staticTexts["行程提醒"].exists)
            XCTAssertFalse(app.scrollViews.matching(identifier: "trip-scene-notices").firstMatch.exists,
                           "noticesLong 保持非空样例输入，也不恢复集中提醒")
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "compact-TripExpeditionScene-\(state)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    @MainActor
    func testTimelineCompactHierarchyAndStandardDetails() {
        XCUIDevice.shared.orientation = .portrait
        for state in ["default", "compact", "compactTitleOnly", "compactWithoutTime", "compactLongTitle", "compactQualified", "compactAccessible"] {
            let app = XCUIApplication()
            app.launchArguments = ["-WalkDataMode", "mock", "--component-preview", "Timeline", state]
            app.launch()
            let ready = app.descendants(matching: .any)
                .matching(identifier: "component-preview-ready:Timeline:\(state)").firstMatch
            XCTAssertTrue(ready.waitForExistence(timeout: 10))
            switch state {
            case "default":
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "这是一段固定的长内容")).firstMatch.exists,
                              "standard 保留完整正文")
            case "compact":
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "出发城市 → 进山口")).firstMatch.exists)
                XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "乘车抵达后核对进山登记")).firstMatch.exists)
            case "compactTitleOnly":
                XCTAssertTrue(app.staticTexts["起点"].exists)
                XCTAssertFalse(app.staticTexts["timeline-item-subtitle"].exists)
            case "compactWithoutTime":
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "海拔 4700 m · 参考")).firstMatch.exists)
                XCTAssertFalse(app.staticTexts["08:30"].exists)
            case "compactLongTitle":
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "需要完整显示的高山垭口与营地连接点名称")).firstMatch.exists)
            default:
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "6 km处 · 待核验")).firstMatch.exists)
                XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "湖畔营地 · 备选")).firstMatch.exists)
            }
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "timeline-hierarchy-\(state)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    private func cropComponentCanvas(from image: UIImage) throws -> UIImage {
        let targetSize = CGSize(width: 390, height: 844)
        guard image.size.width >= targetSize.width,
              image.size.height >= targetSize.height else {
            throw ScreenshotError.screenTooSmall(actual: image.size)
        }

        let offset = CGPoint(
            x: (image.size.width - targetSize.width) / 2,
            y: (image.size.height - targetSize.height) / 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(at: CGPoint(x: -offset.x, y: -offset.y))
        }
    }

    private enum ScreenshotError: Error {
        case screenTooSmall(actual: CGSize)
    }

    @MainActor
    func testUnknownComponentUsesUnsupportedMarker() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-WalkDataMode", "mock",
            "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
            "-WalkEnvironment", "test",
            "--component-preview", "UnknownComponent", "default",
        ]
        app.launch()

        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "component-preview-canvas")
                .firstMatch
                .waitForExistence(timeout: 10)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(identifier: "component-preview-unsupported:UnknownComponent:default")
                .firstMatch
                .exists
        )
        XCTAssertFalse(
            app.descendants(matching: .any)
                .matching(identifier: "component-preview-ready:UnknownComponent:default")
                .firstMatch
                .exists
        )
        app.terminate()
    }

    @MainActor
    func testUnknownStateUsesUnsupportedMarkerWithoutDefaultFallback() {
        let app = XCUIApplication()
        app.launchArguments = ["--component-preview", "AvatarButton", "unknown-state"]
        app.launch()
        defer { app.terminate() }

        let unsupported = app.descendants(matching: .any)
            .matching(identifier: "component-preview-unsupported:AvatarButton:unknown-state").firstMatch
        XCTAssertTrue(unsupported.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(identifier: "component-preview-ready:AvatarButton:default").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)
            .matching(identifier: "component-preview-ready:AvatarButton:unknown-state").firstMatch.exists)
    }

    private static let componentIDs = [
        "AvatarButton", "Card", "ConfirmationDialog", "ContentSection", "DangerAction", "DateInput",
        "EmptyState", "ErrorView", "FixedActionArea", "FormField", "IconButton", "InfoTag", "ListRow",
        "LoadingState", "MetricGroup", "MetricItem", "MixedPageShell", "ModalBottomSheet", "Notice",
        "PageTitleBlock", "Panel", "PrimaryAction", "QuantityStepper", "SearchField",
        "SecondaryAction", "SectionHeader", "SegmentedControl", "SelectInput", "SelectableOptionCard",
        "SettingsListRow", "SheetHandle", "SourceNote", "TextInput", "Timeline", "UnavailableState",
        "UtilityNavigationHeader", "UtilityPage",
        "AuthPanel", "ChecklistItemRow", "ChecklistPanel", "DailyWeatherCard", "DailyWeatherSummaryRow",
        "ElevationProfile", "EquipmentDeletionImpact", "EquipmentListRow", "FocusTripSummary",
        "GenerationRouteSummaryCard", "GenerationWaitingView", "HeatmapCalendar", "InlineEquipmentEditor",
        "InlineListNameEditor", "PersonalEquipmentForm", "PersonalEquipmentSummaryCard", "ProfileIdentityHeader",
        "RouteFactSection", "RouteImageGallery", "RouteIntroduction", "RouteListRow",
        "RouteMap", "RoutePointDetail", "RoutePointSection", "RouteReferenceDayList", "RouteScene",
        "RouteSegmentList", "RouteSummary", "TripCalendarCard", "TripCoverHeader", "TripDayArrangement",
        "TripDayOverviewEntry", "TripEquipmentSourcePicker", "TripEquipmentSummaryCard", "TripListRow", "TripRouteSummaryCard",
        "TripStatusBadge", "TripWeatherSummaryCard", "WeatherOverview", "WeatherSummary",
    ]
}
