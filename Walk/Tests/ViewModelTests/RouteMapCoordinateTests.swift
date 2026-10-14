import CoreLocation
import XCTest
import WalkData
@testable import Walk

@MainActor
final class RouteMapCoordinateTests: XCTestCase {
    func testWGS84CoordinatesPreserveValues() async throws {
        let path = [position(29.0, 101.0), position(30.0, 102.0), position(31.0, 103.0)]
        let snapshot = try await RouteDetailViewModel.makeSnapshot(from: detail(path: path))

        XCTAssertEqual(snapshot.mapCoordinates.map(\.latitude), path.map(\.latitude))
        XCTAssertEqual(snapshot.mapCoordinates.map(\.longitude), path.map(\.longitude))
    }

    func testUnsupportedReferenceSystemsDoNotRender() async throws {
        for referenceSystem in ["", " ", "unknown", "GCJ02", "BD09", "WGS-84", "wgs84"] {
            let snapshot = try await RouteDetailViewModel.makeSnapshot(from: detail(path: [
                position(29.0, 101.0, referenceSystem: referenceSystem),
                position(30.0, 102.0, referenceSystem: referenceSystem),
            ]))

            XCTAssertTrue(snapshot.mapCoordinates.isEmpty, "Cannot interpret \(referenceSystem) as WGS84")
            XCTAssertTrue(snapshot.mapSegments.isEmpty)
            XCTAssertTrue(snapshot.dayMapSegments.isEmpty)
        }
    }

    func testMixedReferenceTrackNeverBridgesAcrossUnknownPosition() async throws {
        let path = [
            position(29.0, 101.0),
            position(30.0, 102.0, referenceSystem: "future-grid"),
            position(31.0, 103.0),
        ]
        let snapshot = try await RouteDetailViewModel.makeSnapshot(from: detail(path: path))

        XCTAssertTrue(snapshot.mapCoordinates.isEmpty, "Dropping the middle position would invent a connecting edge")
        XCTAssertTrue(snapshot.mapSegments.isEmpty)
        XCTAssertTrue(snapshot.coloredMapSegments.isEmpty)
        XCTAssertTrue(snapshot.dayMapSegments.isEmpty)
        XCTAssertEqual(snapshot.route.currentVersion.mainTrack?.path, path)
    }

    func testInvalidNumericTrackNeverBridgesAcrossRejectedPosition() async throws {
        for invalid in [position(.nan, 102), position(30, .infinity), position(91, 102), position(30, 181)] {
            let snapshot = try await RouteDetailViewModel.makeSnapshot(from: detail(path: [
                position(29, 101), invalid, position(31, 103),
            ]))

            XCTAssertTrue(snapshot.mapCoordinates.isEmpty)
            XCTAssertTrue(snapshot.mapSegments.isEmpty)
        }
    }

    func testMapCoordinateRejectionDoesNotChangeServerEligibilityOrElevationFacts() async throws {
        let source = detail(path: [
            position(29, 101), position(30, 102, referenceSystem: "future-grid"), position(31, 103),
        ])
        let model = RouteDetailViewModel(service: CoordinateRouteService(detail: source))
        await model.loadRoute(id: source.routeId)

        XCTAssertTrue(model.mapCoordinates.isEmpty)
        XCTAssertFalse(model.hasUnavailableTrack, "Server track validity remains authoritative")
        XCTAssertEqual(model.route?.currentVersion.mainTrackAvailability, .valid)
        XCTAssertEqual(model.route?.currentVersion.generationEligibility.eligible, true)
        XCTAssertEqual(model.presentation?.generationAction.isEnabled, true)
        XCTAssertEqual(model.elevationSamples.count, 3)
        XCTAssertEqual(model.route, source)
        XCTAssertNotNil(model.mapCoordinateNotice)
    }

    func testAllPointCategoriesKeepOnlyUnderstoodPositions() async throws {
        let positions = [position(29, 101, referenceSystem: "GCJ02"), position(30, 102)]
        let source = detail(
            path: [position(29, 101), position(30, 102), position(31, 103)],
            pointPositions: positions
        )
        let snapshot = try await RouteDetailViewModel.makeSnapshot(from: source)

        XCTAssertEqual(snapshot.poiAnnotations.count, 5)
        XCTAssertEqual(Set(snapshot.poiAnnotations.map(\.category)), ["兴趣点", "营地", "过夜点", "水源", "补给"])
        XCTAssertEqual(snapshot.waypointAnnotations.count, 1)
        XCTAssertEqual(snapshot.poiAnnotations.map(\.latitude), Array(repeating: 30, count: 5))
        XCTAssertEqual(snapshot.waypointAnnotations.map(\.latitude), [30])
        XCTAssertEqual(snapshot.poiAnnotations.map(\.longitude), Array(repeating: 102, count: 5))
        XCTAssertEqual(snapshot.route.currentVersion.interestPoints?.first?.positions, positions)
    }

    func testUnknownEndpointsAndCursorCannotProduceMapCoordinates() async {
        let source = detail(
            path: [position(29, 101), position(30, 102, referenceSystem: "GCJ02"), position(31, 103)],
            start: position(29, 101, referenceSystem: "GCJ02"),
            end: position(31, 103)
        )
        let model = RouteDetailViewModel(service: CoordinateRouteService(detail: source))
        await model.loadRoute(id: source.routeId)

        XCTAssertNil(model.mapStartCoordinate)
        XCTAssertEqual(model.mapEndCoordinate?.latitude, 31)
        XCTAssertNil(model.pathCoordinate(at: .init(precedingPositionIndex: 0, progressToNextPosition: 0.5)))
        XCTAssertNil(model.pathCoordinate(at: .init(precedingPositionIndex: 2, progressToNextPosition: nil)),
                     "A cursor must not reconstruct even an isolated tail of a rejected main track")
        XCTAssertTrue(model.divisionBadges(for: .day).isEmpty)
        XCTAssertTrue(model.divisionBadges(for: .segment).isEmpty)
    }

    func testReloadWithUnknownTrackClearsPriorGeometry() async {
        let service = CoordinateRouteService(detail: detail(path: [
            position(29, 101), position(30, 102), position(31, 103),
        ]))
        let model = RouteDetailViewModel(service: service)
        await model.loadRoute(id: service.detail.routeId)
        XCTAssertEqual(model.mapCoordinates.count, 3)

        service.detail = detail(path: [
            position(29, 101), position(30, 102, referenceSystem: "future-grid"), position(31, 103),
        ])
        await model.loadRoute(id: service.detail.routeId)

        XCTAssertTrue(model.mapCoordinates.isEmpty)
        XCTAssertTrue(model.mapSegments.isEmpty)
        XCTAssertTrue(model.divisionMapSegments(for: .day).isEmpty)
        XCTAssertNil(model.errorMessage)
    }

    func testCoordinateNoticeIsLocalToRejectedCoordinates() async {
        let path = [position(29, 101), position(30, 102), position(31, 103)]
        let service = CoordinateRouteService(detail: detail(path: path))
        let model = RouteDetailViewModel(service: service)
        await model.loadRoute(id: service.detail.routeId)
        XCTAssertNil(model.mapCoordinateNotice)

        service.detail = detail(path: path, pointPositions: [position(30, 102, referenceSystem: "future-grid")])
        await model.loadRoute(id: service.detail.routeId)
        XCTAssertNotNil(model.mapCoordinateNotice)
        XCTAssertEqual(model.mapCoordinates.count, 3)
        XCTAssertTrue(model.poiAnnotations.isEmpty)
        XCTAssertTrue(model.waypointAnnotations.isEmpty)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.presentation?.generationAction.isEnabled, true)
    }

    private func position(_ latitude: Double, _ longitude: Double, referenceSystem: String = "WGS84") -> PublicRouteGeoPosition {
        .init(latitude: latitude, longitude: longitude, referenceSystem: referenceSystem)
    }

    private func detail(
        path: [PublicRouteGeoPosition],
        start: PublicRouteGeoPosition? = nil,
        end: PublicRouteGeoPosition? = nil,
        pointPositions: [PublicRouteGeoPosition] = []
    ) -> PublicRouteDetail {
        let range = PublicRouteMainTrackRange(
            startPathPosition: .init(precedingPositionIndex: 0, progressToNextPosition: 0),
            endPathPosition: .init(precedingPositionIndex: max(path.count - 1, 0), progressToNextPosition: nil)
        )
        return .init(routeId: "coordinate-route", currentVersion: .init(
            versionId: "coordinate-version",
            summary: .init(routeType: .multiDay, name: "坐标测试路线",
                           start: .init(name: "起点", position: start), end: .init(name: "终点", position: end)),
            mainTrackAvailability: .valid,
            generationEligibility: .init(eligible: true),
            mainTrack: .init(identity: "main", path: path),
            elevationProfile: .init(minElevation: .init(meters: 100), maxElevation: .init(meters: 300),
                samples: path.indices.map { index in
                    .init(identity: "sample-\(index)", distance: .init(meters: Double(index) * 100),
                          elevation: .init(meters: Double(index + 1) * 100))
                }),
            referenceDays: [.init(identity: "day", dayNumber: 1, title: nil, start: nil, end: nil,
                distance: nil, estimatedDuration: nil, ascent: nil, descent: nil, maxElevation: nil,
                minElevation: nil, accommodation: nil, notes: nil, mainTrackRange: range)],
            segments: [.init(identity: "segment", order: 1, name: "分段", mainTrackRange: range)],
            keyPoints: [.init(identity: "key", name: "关键点", positions: pointPositions)],
            interestPoints: [.init(identity: "interest", name: "兴趣点", positions: pointPositions)],
            campsites: [.init(identity: "camp", name: "营地", positions: pointPositions,
                elevation: nil, details: nil, status: nil)],
            overnightPlaces: [.init(identity: "overnight", name: "过夜点", positions: pointPositions,
                elevation: nil, type: nil, facilities: nil, details: nil, status: nil)],
            waterSources: [.init(identity: "water", name: "水源", positions: pointPositions,
                elevation: nil, sourceType: nil, seasonalReliability: nil, treatmentRecommended: nil,
                treatmentAdvice: nil, description: nil)],
            supplyPoints: [.init(identity: "supply", name: "补给", positions: pointPositions,
                supplyType: nil, availableItems: nil, description: nil)]
        ))
    }
}

private final class CoordinateRouteService: RouteDetailServicing {
    var detail: PublicRouteDetail

    init(detail: PublicRouteDetail) { self.detail = detail }

    func getRouteDetail(id: String) async throws -> PublicRouteDetail { detail }
}
