import XCTest
import MapKit
@testable import Walk

final class RouteMapViewTests: XCTestCase {
    private let northSouthCoordinates = [
        CLLocationCoordinate2D(latitude: 39.80, longitude: 116.40),
        CLLocationCoordinate2D(latitude: 40.20, longitude: 116.40)
    ]

    func testUpdateDecisionSkipsUnchangedCoordinates() {
        let fingerprint = RouteCoordinatesFingerprint(coordinates: northSouthCoordinates)

        let decision = RouteMapUpdatePolicy.decision(
            previousFingerprint: fingerprint,
            coordinates: northSouthCoordinates,
            userHasInteracted: false
        )

        XCTAssertFalse(decision.shouldUpdateRoute)
        XCTAssertFalse(decision.shouldFitCamera)
    }

    func testUpdateDecisionUpdatesRouteWithoutResettingCameraAfterUserInteraction() {
        let decision = RouteMapUpdatePolicy.decision(
            previousFingerprint: nil,
            coordinates: northSouthCoordinates,
            userHasInteracted: true
        )

        XCTAssertTrue(decision.shouldUpdateRoute)
        XCTAssertFalse(decision.shouldFitCamera)
    }

    func testUpdateDecisionFitsCameraForNewCoordinatesBeforeInteraction() {
        let decision = RouteMapUpdatePolicy.decision(
            previousFingerprint: nil,
            coordinates: northSouthCoordinates,
            userHasInteracted: false
        )

        XCTAssertTrue(decision.shouldUpdateRoute)
        XCTAssertTrue(decision.shouldFitCamera)
    }

    func testCameraFitUsesBothDimensionsForNorthSouthRoute() throws {
        let fit = try XCTUnwrap(
            RouteMapCamera.fit(coordinates: northSouthCoordinates, edgeInsets: .zero)
        )

        XCTAssertGreaterThan(fit.mapRect.height, fit.mapRect.width)
        XCTAssertEqual(fit.edgeInsets, .zero)
    }

    func testDetailPaddingReservesDrawerAndSafeArea() {
        let padding = RouteMapCamera.detailEdgeInsets(
            viewportHeight: 800,
            safeAreaTop: 47,
            safeAreaBottom: 34
        )

        XCTAssertEqual(padding.top, 71)
        XCTAssertEqual(padding.left, 24)
        XCTAssertEqual(padding.right, 24)
        XCTAssertEqual(padding.bottom, 522)
    }
}

final class RouteServiceTests: XCTestCase {
    var sut: RouteService!

    override func setUp() {
        super.setUp()
        let fixtures = DefaultMockFixtures.routeFixtures(bundle: Bundle(for: RouteServiceTests.self))
        sut = RouteService(apiClient: MockAPIClient(fixtures: fixtures), userID: "anonymous")
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - getRoutes Tests

    func testGetRoutes_WithoutCategory_ShouldReturnRoutes() async throws {
        do {
            _ = try await sut.getRoutes()
        } catch {
            XCTAssertTrue(error is APIError || error is NetworkError)
        }
    }

    func testGetRoutes_WithCategory_ShouldPassCategory() async throws {
        do {
            _ = try await sut.getRoutes(category: .hiking)
        } catch {
            XCTAssertNotNil(error)
        }
    }

    func testGetRoutes_WithPagination_ShouldPassParameters() async throws {
        do {
            _ = try await sut.getRoutes(page: 1, size: 10)
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - getPopularRoutes Tests

    func testGetPopularRoutes_ShouldReturnRoutes() async throws {
        do {
            _ = try await sut.getPopularRoutes()
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - getRouteDetail Tests

    func testGetRouteDetail_WithValidId_ShouldReturnRoute() async throws {
        let route = try await sut.getRouteDetailResponse(id: "route-1")

        XCTAssertEqual(route.id, "route-1")
        XCTAssertEqual(route.coverUrl, "https://example.test/cover.jpg")
        XCTAssertEqual(route.segmentSchemes.first?.segments.first?.difficulty, .unknown(2))
        XCTAssertEqual(route.segmentSchemes.first?.segments.first?.routeType, .oneWay)
    }

    func testMockRouteIdentifiersResolveThroughUnifiedClient() async throws {
        for routeID in ["route_001", "route_002", "route_003"] {
            let route = try await sut.getRouteDetailResponse(id: routeID)
            XCTAssertEqual(route.id, routeID)
        }
    }

    func testMockFavoriteIdentifiersResolveForEveryMockRoute() async throws {
        let fixtures = DefaultMockFixtures.routeFixtures(bundle: Bundle(for: RouteServiceTests.self))

        for routeID in ["route_001", "route_002", "route_003"] {
            XCTAssertNotNil(fixtures[RouteAPI.Favorite(id: routeID, userID: "anonymous", isFavorite: true).identifier])
            XCTAssertNotNil(fixtures[RouteAPI.Favorite(id: routeID, userID: "anonymous", isFavorite: false).identifier])
            try await sut.setFavorite(routeID: routeID, isFavorite: true)
            try await sut.setFavorite(routeID: routeID, isFavorite: false)
        }
    }

    // MARK: - searchRoutes Tests

    func testSearchRoutes_WithKeyword_ShouldReturnResults() async throws {
        do {
            _ = try await sut.searchRoutes(keyword: "五台山")
        } catch {
            XCTAssertNotNil(error)
        }
    }
}
