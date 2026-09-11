import XCTest
import UIKit
import WalkData
import WalkDesignSystem

final class WalkBaselineScreenshotTests: XCTestCase {
    @MainActor
    func testCurrentTripListScenarios() throws {
        XCUIDevice.shared.orientation = .portrait

        for scenarioID in Self.tripListScenarioIDs {
            let app = XCUIApplication()
            app.launchArguments = [
                "-DataSourceMode", "mock",
                "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
                "-WalkEnvironment", "test",
                "-WalkBaselineScenario", scenarioID,
            ]
            app.launch()

            let readyMarker = app.descendants(matching: .any)
                .matching(identifier: "baseline.ready.\(scenarioID)")
                .firstMatch
            XCTAssertTrue(
                readyMarker.waitForExistence(timeout: 10),
                "Current scenario did not become ready: \(scenarioID)"
            )
            XCTAssertFalse(
                app.descendants(matching: .any)
                    .matching(identifier: "baseline.unsupported.\(scenarioID)")
                    .firstMatch
                    .exists,
                "Supported current scenario rendered the unsupported marker: \(scenarioID)"
            )

            let image = try cropReferenceCanvas(from: XCUIScreen.main.screenshot().image)
            let attachment = XCTAttachment(image: image)
            attachment.name = "\(scenarioID).png"
            attachment.lifetime = .keepAlways
            add(attachment)

            app.terminate()
        }
    }

    private func cropReferenceCanvas(from image: UIImage) throws -> UIImage {
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

    private static let tripListScenarioIDs = [
        "page-trips--loaded",
        "page-trips--current-empty",
        "page-trips--history-empty",
        "page-trips--loading",
        "page-trips--global-empty",
        "page-trips--error",
    ]
}
