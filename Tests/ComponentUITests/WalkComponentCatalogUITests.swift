import XCTest
import UIKit

final class WalkComponentCatalogUITests: XCTestCase {
    @MainActor
    func testEveryDefaultComponentLaunchesAndBecomesReady() throws {
        XCUIDevice.shared.orientation = .portrait

        for componentID in Self.componentIDs {
            let app = XCUIApplication()
            app.launchArguments = [
                "-DataSourceMode", "mock",
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
            "-DataSourceMode", "mock",
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

    private static let componentIDs = [
        "AvatarButton", "Card", "ConfirmationDialog", "ContentSection", "DangerAction", "DateInput",
        "EmptyState", "ErrorView", "FixedActionArea", "FormField", "IconButton", "InfoTag", "ListRow",
        "LoadingState", "MetricGroup", "MetricItem", "MixedPageShell", "ModalBottomSheet", "Notice",
        "PageTitleBlock", "Panel", "PrimaryAction", "PrimaryTabBar", "QuantityStepper", "SearchField",
        "SecondaryAction", "SectionHeader", "SegmentedControl", "SelectInput", "SelectableOptionCard",
        "SettingsListRow", "SheetHandle", "SourceNote", "TextInput", "Timeline", "UnavailableState",
        "UtilityNavigationHeader", "UtilityPage",
        "AccountMenuSheet", "AuthPanel", "ChecklistItemRow", "ChecklistPanel", "DailyWeatherCard",
        "ElevationProfile", "EquipmentDeletionImpact", "EquipmentListRow", "FocusTripSummary",
        "GenerationRouteSummaryCard", "GenerationWaitingView", "HeatmapCalendar", "InlineEquipmentEditor",
        "InlineListNameEditor", "PersonalEquipmentForm", "PersonalEquipmentSummaryCard", "ProfileIdentityHeader",
        "RouteFactSection", "RouteImageGallery", "RouteImageViewer", "RouteIntroduction", "RouteListRow",
        "RouteMap", "RoutePointDetail", "RoutePointSection", "RouteReferenceDayList", "RouteScene",
        "RouteSegmentList", "RouteSummary", "TripCalendarCard", "TripCoverHeader", "TripDayArrangement",
        "TripDaySummaryCard", "TripEquipmentSummaryCard", "TripListRow", "TripRouteSummaryCard",
        "TripStatusBadge", "TripWeatherSummaryCard", "WeatherOverview", "WeatherSummary",
    ]
}
