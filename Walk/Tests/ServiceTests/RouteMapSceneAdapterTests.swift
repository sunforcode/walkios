import XCTest
import CoreLocation
import UIKit
import MapComponentCore
import OutdoorMap
import WalkDesignSystem
@testable import Walk

final class RouteMapSceneAdapterTests: XCTestCase {
    private let route = [
        CLLocationCoordinate2D(latitude: 30, longitude: 102),
        CLLocationCoordinate2D(latitude: 30.01, longitude: 102.01),
        CLLocationCoordinate2D(latitude: 30.02, longitude: 102.02)
    ]

    func testMultipleLocationsRetainAnnotationIdentityAndShareBusinessSelection() throws {
        let first = poi(id: "camp-a", identity: "camp", coordinate: route[0], category: "营地")
        let second = poi(id: "camp-b", identity: "camp", coordinate: route[2], category: "营地")
        let adapter = try RouteMapSceneAdapter(coordinates: route, poiAnnotations: [first, second])
        let points = adapter.scene.points.filter(\.isInteractive)
        XCTAssertEqual(Set(points.map(\.id)).count, 2)
        XCTAssertEqual(Set(points.map(\.objectID)).count, 1)
        XCTAssertNotEqual(points[0].coordinate, points[1].coordinate)
        let selection = try XCTUnwrap(adapter.mapSelection(highlightedAnnotationIDs: [second.id]))
        XCTAssertEqual(selection, .point(points[0].objectID))
        XCTAssertEqual(adapter.selection(for: points[1].objectID)?.identity, "camp")
        XCTAssertEqual(adapter.selection(for: points[1].objectID)?.annotationID, first.id)
    }

    func testProvidedRangesAndDivisionColorsSurviveSelectionWithoutConnectingSegments() throws {
        let segments = [
            RouteMapSegment(id: "first", name: "第一段", colorHex: "#FF5522", coordinates: Array(route.prefix(2))),
            RouteMapSegment(id: "second", name: "第二段", colorHex: "#2255FF", coordinates: Array(route.suffix(2)))
        ]
        let adapter = try RouteMapSceneAdapter(coordinates: route, segments: segments, baseCoordinates: route)
        let scene = try adapter.makeScene(selectedSegmentID: "second")
        XCTAssertEqual(scene.tracks.count, 3)
        let first = try XCTUnwrap(scene.tracks.first { adapter.segmentID(for: $0.id) == "first" })
        let second = try XCTUnwrap(scene.tracks.first { adapter.segmentID(for: $0.id) == "second" })
        XCTAssertEqual(first.coordinates.count, 2)
        XCTAssertEqual(first.coordinates.last, second.coordinates.first)
        XCTAssertEqual(first.style.colorHex, "#FF5522")
        XCTAssertEqual(second.style.colorHex, "#2255FF")
        XCTAssertEqual(first.style.opacity, 0.2)
        XCTAssertEqual(second.style.opacity, 1)
        XCTAssertGreaterThan(second.style.lineWidth, first.style.lineWidth)
        XCTAssertNil(adapter.segmentID(for: scene.tracks[0].id), "主轨迹底色不是可选择的业务区间")
    }

    func testRealDivisionPaletteKeepsEachTrackAndBadgeColor() throws {
        let segments = RouteDivisionPalette.hexValues.indices.map { index in
            RouteMapSegment(id: "day-\(index)", name: "第\(index + 1)天",
                            colorHex: RouteDivisionPalette.hex(for: index), coordinates: route)
        }
        let badges = RouteDivisionPalette.hexValues.indices.map { index in
            RouteDivisionBadgeProjection(spanID: "day-\(index)", label: "D\(index + 1)",
                                         colorHex: RouteDivisionPalette.hex(for: index), coordinate: route[0])
        }
        let adapter = try RouteMapSceneAdapter(coordinates: route, segments: segments, divisionBadges: badges)
        let expected = RouteDivisionPalette.hexValues.map { "#" + $0 }
        XCTAssertEqual(adapter.scene.tracks.map(\.style.colorHex), expected)
        XCTAssertEqual(adapter.scene.points.filter { $0.style.markerShape == .badge }.map(\.style.colorHex), expected)
    }

    func testSelectingObjectWithoutMappedRangeLeavesOriginalTrackVisible() throws {
        let adapter = try RouteMapSceneAdapter(coordinates: route, segments: [
            .init(id: "mapped", name: "有范围的区间", colorHex: RouteDivisionPalette.hex(for: 0), coordinates: route)
        ])
        let selected = try adapter.makeScene(selectedSegmentID: "card-without-range")
        XCTAssertEqual(selected, adapter.scene)
        XCTAssertTrue(selected.tracks.allSatisfy { $0.style.opacity == 1 })
    }

    func testRepeatedPositionAnnotationDoesNotInvalidateWholeScene() throws {
        let repeated = poi(id: "camp-same-coordinate", identity: "camp", coordinate: route[1], category: "营地")
        let adapter = try RouteMapSceneAdapter(coordinates: route, poiAnnotations: [repeated, repeated])
        let repeatedAdapter = try RouteMapSceneAdapter(coordinates: route, poiAnnotations: [repeated, repeated])
        let points = adapter.scene.points.filter(\.isInteractive)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(Set(points.map(\.id)).count, 2)
        XCTAssertEqual(Set(points.map(\.objectID)).count, 1)
        XCTAssertEqual(adapter.scene, repeatedAdapter.scene, "同一输入必须产生稳定的instance身份")
        XCTAssertEqual(adapter.scene.tracks.count, 1)
        XCTAssertNotNil(adapter.mapSelection(highlightedAnnotationIDs: [repeated.id]))
    }

    func testTrackUnavailableKeepsVerifiedPointsWithoutMakingPolyline() throws {
        let adapter = try RouteMapSceneAdapter(
            poiAnnotations: [poi(id: "water", identity: "water", coordinate: route[1], category: "水源")],
            startCoordinate: route[0], endCoordinate: route[2]
        )
        XCTAssertTrue(adapter.scene.tracks.isEmpty)
        XCTAssertEqual(adapter.scene.points.count, 3)
        XCTAssertEqual(adapter.scene.points.filter { !$0.isInteractive }.count, 2)
        XCTAssertNil(adapter.mapSelection(highlightedAnnotationIDs: []))
    }

    func testAllSixCategoriesUseTheirSemanticTokenAndPhotoRemainsInterestBadge() throws {
        let categories = ["兴趣点", "营地", "过夜点", "水源", "补给点", "拍照点"]
        let annotations = categories.enumerated().map {
            poi(id: "point-\($0.offset)", identity: "object-\($0.offset)", coordinate: route[1], category: $0.element)
        }
        let waypoint = RouteWaypointAnnotation(id: "pass", objectIdentity: "pass", title: "垭口", detail: "", elevation: "", type: "关键点", imageURL: nil, latitude: 30, longitude: 102)
        let adapter = try RouteMapSceneAdapter(poiAnnotations: annotations, waypointAnnotations: [waypoint])
        let expected: [(String, RouteMapPointCategory)] = [
            ("object-0", .interest), ("object-1", .camp), ("object-2", .overnight),
            ("object-3", .water), ("object-4", .supply), ("object-5", .interest), ("pass", .keyPoint)
        ]
        for (identity, category) in expected {
            let point = try XCTUnwrap(adapter.scene.points.first { adapter.selection(for: $0.objectID)?.identity == identity })
            XCTAssertEqual(point.style.colorHex, RouteMapSceneAdapter.colorHex(category.color))
            XCTAssertEqual(point.style.glyphText, category.glyph)
            XCTAssertEqual(point.style.markerShape, .circle)
            XCTAssertEqual(point.style.showsPhotoBadge, identity == "object-5")
        }
    }

    func testDivisionBadgeUsesSpanEventAndCannotOpenPointDetail() throws {
        let adapter = try RouteMapSceneAdapter(divisionBadges: [
            .init(spanID: "day-2", label: "D2", colorHex: "#8844CC", coordinate: route[1])
        ])
        let badge = try XCTUnwrap(adapter.scene.points.first)
        XCTAssertEqual(badge.name, "D2")
        XCTAssertEqual(badge.style.markerShape, .badge)
        XCTAssertEqual(adapter.spanID(for: badge.objectID), "day-2")
        XCTAssertNil(adapter.selection(for: badge.objectID))
    }

    func testInvalidTrackCoordinateRejectsWholePathInsteadOfBridging() {
        XCTAssertThrowsError(try RouteMapSceneAdapter(coordinates: [
            route[0], .init(latitude: .nan, longitude: 102), route[2]
        ]))
    }

    func testCameraRetainsManualBrowseForSourceRefreshButUpdatesVisibleArea() throws {
        let adapter = try RouteMapSceneAdapter(coordinates: route)
        var driver = RouteMapCameraDriver()
        let initial = driver.update(adapter: adapter, sourceChanged: true, coordinatesChanged: true,
                                    edgeInsets: .zero, selectedSegmentID: nil, highlightedAnnotationIDs: [], recenterRequest: 0)
        driver.userHasInteracted = true
        let afterSourceRefresh = driver.update(adapter: adapter, sourceChanged: true, coordinatesChanged: true,
                                                edgeInsets: .zero,
                                                selectedSegmentID: nil, highlightedAnnotationIDs: [], recenterRequest: 0)
        XCTAssertEqual(initial, afterSourceRefresh)
        let visibleArea = UIEdgeInsets(top: 20, left: 24, bottom: 300, right: 24)
        let afterLayout = driver.update(adapter: adapter, sourceChanged: false, coordinatesChanged: false,
                                        edgeInsets: visibleArea,
                                        selectedSegmentID: nil, highlightedAnnotationIDs: [], recenterRequest: 0)
        XCTAssertGreaterThan(afterLayout.id, initial.id)
        XCTAssertEqual(afterLayout.padding, visibleArea)
        XCTAssertEqual(afterLayout.target, .coordinates(adapter.mainCoordinates, maxZoom: 15))
        let recentered = driver.update(adapter: adapter, sourceChanged: false, coordinatesChanged: false,
                                       edgeInsets: .zero, selectedSegmentID: nil, highlightedAnnotationIDs: [], recenterRequest: 1)
        XCTAssertGreaterThan(recentered.id, initial.id)
        XCTAssertEqual(recentered.target, .coordinates(adapter.mainCoordinates, maxZoom: 15))
    }

    func testVisibleAreaChangeRefitsCurrentPointAfterManualBrowse() throws {
        let point = poi(id: "camp", identity: "camp", coordinate: route[1], category: "营地")
        let adapter = try RouteMapSceneAdapter(coordinates: route, poiAnnotations: [point])
        var driver = RouteMapCameraDriver()
        _ = driver.update(adapter: adapter, sourceChanged: true, coordinatesChanged: true,
                          edgeInsets: .zero, selectedSegmentID: nil, highlightedAnnotationIDs: [], recenterRequest: 0)
        let selected = driver.update(adapter: adapter, sourceChanged: false, coordinatesChanged: false,
                                      edgeInsets: .zero, selectedSegmentID: nil, highlightedAnnotationIDs: [point.id], recenterRequest: 0)
        driver.userHasInteracted = true
        let visibleArea = UIEdgeInsets(top: 20, left: 24, bottom: 320, right: 24)
        let resized = driver.update(adapter: adapter, sourceChanged: false, coordinatesChanged: false,
                                     edgeInsets: visibleArea, selectedSegmentID: nil, highlightedAnnotationIDs: [point.id], recenterRequest: 0)
        XCTAssertGreaterThan(resized.id, selected.id)
        XCTAssertEqual(resized.target, selected.target)
        XCTAssertEqual(resized.padding, visibleArea)
    }

    func testSingleAcceptedPathPositionRemainsCameraInputWithoutMakingLine() throws {
        let adapter = try RouteMapSceneAdapter(coordinates: [route[1]])
        XCTAssertTrue(adapter.scene.tracks.isEmpty)
        XCTAssertEqual(adapter.mainCoordinates, [try RouteMapSceneAdapter.mapCoordinate(route[1])])
        var driver = RouteMapCameraDriver()
        let request = driver.update(adapter: adapter, sourceChanged: true, coordinatesChanged: true,
                                     edgeInsets: .zero, selectedSegmentID: nil, highlightedAnnotationIDs: [], recenterRequest: 0)
        XCTAssertEqual(request.target, .coordinates(adapter.mainCoordinates, maxZoom: 15))
    }

    func testPointAndSegmentSelectionsIssueOneCameraActionAndCursorRefreshDoesNotRepeatIt() throws {
        let point = poi(id: "camp", identity: "camp", coordinate: route[1], category: "营地")
        let segment = RouteMapSegment(id: "day", name: "第一天", colorHex: nil, coordinates: route)
        let adapter = try RouteMapSceneAdapter(coordinates: route, segments: [segment], poiAnnotations: [point])
        var driver = RouteMapCameraDriver()
        _ = driver.update(adapter: adapter, sourceChanged: true, coordinatesChanged: true,
                          edgeInsets: .zero, selectedSegmentID: nil, highlightedAnnotationIDs: [], recenterRequest: 0)
        driver.userHasInteracted = true
        let segmentRequest = driver.update(adapter: adapter, sourceChanged: false, coordinatesChanged: false,
                                           edgeInsets: .zero, selectedSegmentID: "day", highlightedAnnotationIDs: [], recenterRequest: 0)
        XCTAssertEqual(segmentRequest.target, .track(try XCTUnwrap(adapter.trackID(for: "day"))))
        let pointRequest = driver.update(adapter: adapter, sourceChanged: false, coordinatesChanged: false,
                                         edgeInsets: .zero, selectedSegmentID: "day", highlightedAnnotationIDs: [point.id], recenterRequest: 0)
        let interactivePoint = try XCTUnwrap(adapter.scene.points.first { $0.isInteractive })
        XCTAssertEqual(pointRequest.target, .point(interactivePoint.objectID))
        let cursorRefresh = driver.update(adapter: adapter, sourceChanged: false, coordinatesChanged: false,
                                          edgeInsets: .zero, selectedSegmentID: "day", highlightedAnnotationIDs: [point.id], recenterRequest: 0)
        XCTAssertEqual(cursorRefresh, pointRequest)
    }

    private func poi(id: String, identity: String, coordinate: CLLocationCoordinate2D, category: String) -> RoutePOIAnnotation {
        .init(id: id, objectIdentity: identity, title: id, category: category, subCategory: "", detail: "", elevation: "", imageURL: nil,
              latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
