import XCTest
@testable import MapComponentCore

final class MapPresentationInputTests: XCTestCase {
    private let a = try! MapCoordinate(latitude: 30, longitude: 100)
    private let b = try! MapCoordinate(latitude: 30.01, longitude: 100.01)

    func testLegacyTrackAndPointInputsKeepDefaultPresentationAndIdentity() throws {
        let track = try MapTrack(id: "track", name: "Route", coordinates: [a, b])
        XCTAssertEqual(track.style.colorHex, "#FFD454")
        XCTAssertEqual(track.style.casingColorHex, "#AC6BD8")
        XCTAssertEqual(track.style.lineWidth, 4)
        XCTAssertEqual(track.style.casingWidth, 7.5)
        XCTAssertEqual(track.style.opacity, 1)
        let point = try MapPoint(id: "water", name: "Water", coordinate: a)
        XCTAssertEqual(point.objectID, "water")
        XCTAssertTrue(point.isInteractive)
        XCTAssertEqual(point.style.markerShape, .labeled)
        XCTAssertNil(point.style.glyphText)
        XCTAssertFalse(point.style.showsPhotoBadge)
    }

    func testOneObjectCanHaveMultipleAnnotationIdentitiesWithoutJoiningCoordinates() throws {
        let first = try MapPoint(id: "point:1", name: "Camp", coordinate: a, objectID: "camp")
        let second = try MapPoint(id: "point:2", name: "Camp", coordinate: b, objectID: "camp")
        let scene = try MapScene(points: [first, second])
        XCTAssertEqual(scene.points.map(\.id), ["point:1", "point:2"])
        XCTAssertEqual(scene.points.map(\.objectID), ["camp", "camp"])
        XCTAssertEqual(scene.coordinates, [a, b])
        XCTAssertThrowsError(try MapPoint(id: "point:3", name: "", coordinate: a, objectID: " "))
    }

    func testTrackStyleRejectsInvalidColorsWidthsAndOpacity() throws {
        XCTAssertThrowsError(try MapTrackStyle(colorHex: "red"))
        XCTAssertThrowsError(try MapTrackStyle(casingColorHex: "#12345X"))
        for width in [0.0, -1, .nan, .infinity] {
            XCTAssertThrowsError(try MapTrackStyle(lineWidth: width))
            XCTAssertThrowsError(try MapTrackStyle(casingWidth: width))
        }
        XCTAssertThrowsError(try MapTrackStyle(lineWidth: 8, casingWidth: 7))
        for opacity in [-0.1, 1.1, .nan, .infinity] {
            XCTAssertThrowsError(try MapTrackStyle(opacity: opacity))
        }
        let style = try MapTrackStyle(colorHex: "#123456", casingColorHex: "#ABCDEF", lineWidth: 5,
                                     casingWidth: 11, opacity: 0.2)
        XCTAssertEqual(try MapTrack(id: "span", name: "Span", coordinates: [a, b], style: style).style, style)
    }

    func testDecorativeTerminalAndBadgeStylesStayHostOwned() throws {
        let terminal = try MapPoint(id: "start", name: "Start", coordinate: a,
                                    style: MapPinStyle(markerShape: .circle, glyphText: "起"),
                                    isInteractive: false)
        XCTAssertFalse(terminal.isInteractive)
        XCTAssertEqual(terminal.style.glyphText, "起")
        let badge = try MapPinStyle(colorHex: "#123456", symbolName: "flag", markerShape: .badge,
                                    showsPhotoBadge: true)
        XCTAssertTrue(badge.showsPhotoBadge)
        XCTAssertEqual(badge.markerShape, .badge)
        XCTAssertThrowsError(try MapPinStyle(glyphText: " "))
    }

    func testScrubMarkerDoesNotContributeToSceneFitOrPretendToBeDevicePosition() throws {
        let scrub = MapScrubMarker(coordinate: b)
        let scene = try MapScene(points: [MapPoint(id: "start", name: "Start", coordinate: a)])
        XCTAssertEqual(scrub.coordinate, b)
        XCTAssertEqual(scene.coordinates, [a])
    }
}
