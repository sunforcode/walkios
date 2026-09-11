import XCTest
import CoreLocation
import WalkData
import WalkDesignSystem
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
        let fit = try XCTUnwrap(RouteMapCamera.fit(coordinates: northSouthCoordinates, edgeInsets: .zero))
        XCTAssertGreaterThan(fit.mapRect.height, fit.mapRect.width)
        XCTAssertEqual(fit.edgeInsets, .zero)
    }

    func testDetailPaddingReservesVisibleDrawerWithoutSystemInsetInputs() {
        let padding = RouteMapCamera.detailEdgeInsets(viewportHeight: 800)
        XCTAssertEqual(padding.top, 24, accuracy: 0.001)
        XCTAssertEqual(padding.left, 24, accuracy: 0.001)
        XCTAssertEqual(padding.right, 24, accuracy: 0.001)
        XCTAssertEqual(padding.bottom, 488, accuracy: 0.001)
    }

    func testOverlayPlanUsesWholeDeclaredMainTrack() {
        let plan = RouteMapOverlayPlan(coordinates: northSouthCoordinates, segments: [])
        XCTAssertTrue(plan.usesWholeRoute)
        XCTAssertEqual(plan.overlays.count, 1)
        XCTAssertNil(plan.overlays[0].segmentID)
    }
}

final class RouteServiceTests: XCTestCase {
    func testPublicRouteRequestsUseFixedPathsDataEnvelopeAndNoUserQuery() {
        let featured = PublicRouteAPI.Featured()
        let all = PublicRouteAPI.All()
        let search = PublicRouteAPI.Search(query: "贡嘎 山")
        let detail = PublicRouteAPI.Detail(id: "route-1")

        XCTAssertEqual(featured.identifier, "GET /public-routes/featured")
        XCTAssertEqual(all.identifier, "GET /public-routes")
        XCTAssertEqual(search.identifier, "GET /public-routes/search?query=贡嘎 山")
        XCTAssertEqual(detail.identifier, "GET /public-routes/route-1")
        XCTAssertEqual(featured.responseEnvelope, .data)
        XCTAssertEqual(all.responseEnvelope, .data)
        XCTAssertEqual(search.responseEnvelope, .data)
        XCTAssertEqual(detail.responseEnvelope, .data)
        XCTAssertEqual(featured.storagePolicy, .store)
        XCTAssertEqual(all.storagePolicy, .store)
        XCTAssertEqual(search.storagePolicy, .none)
        XCTAssertEqual(detail.storagePolicy, .store)
        XCTAssertTrue(detail.query.isEmpty)
    }

    func testServiceLoadsFeaturedAllSearchAndDetailThroughTypedClient() async throws {
        let fixtures = Self.fixtures()
        let service = RouteService(apiClient: MockAPIClient(fixtures: fixtures))

        let featured = try await service.getFeaturedRoutes()
        let all = try await service.getRoutes()
        let search = try await service.searchRoutes(query: "贡嘎")
        let detail = try await service.getRouteDetail(id: "route-1")

        XCTAssertEqual(featured.items.map(\.routeId), ["route-1"])
        XCTAssertEqual(all.items.map(\.routeId), ["route-1"])
        XCTAssertEqual(search.state, .completed)
        XCTAssertEqual(search.items.map(\.routeId), ["route-1"])
        XCTAssertEqual(detail.routeId, "route-1")
        XCTAssertEqual(detail.currentVersion.versionId, "version-1")
        XCTAssertEqual(detail.currentVersion.summary.distance?.meters, 42_500)
        XCTAssertEqual(detail.currentVersion.summary.estimatedDuration?.seconds, 259_200)
    }

    func testSearchInitialStateDecodesFromDataEnvelope() async throws {
        let initial = Data(#"{"data":{"state":"initial","items":[]}}"#.utf8)
        let request = PublicRouteAPI.Search(query: nil)
        let service = RouteService(apiClient: MockAPIClient(fixtures: [request.identifier: initial]))

        let result = try await service.searchRoutes(query: nil)

        XCTAssertEqual(result.state, .initial)
        XCTAssertTrue(result.items.isEmpty)
    }

    func testDetailDecodesStableOptionalFieldsAndMainTrackRange() async throws {
        let request = PublicRouteAPI.Detail(id: "route-1")
        let detailData = Data(#"{"data":{"routeId":"route-1","currentVersion":{"versionId":"version-1","summary":{"routeType":"multi_day","name":"贡嘎环线","region":"四川甘孜","start":{"name":"起点"},"end":{"name":"终点"},"estimatedDuration":{"seconds":259200},"maxElevation":{"meters":4700},"suggestedDays":3,"tags":["高山"]},"mainTrackAvailability":"valid","generationEligibility":{"eligible":true},"mainTrack":{"identity":"track-1","path":[{"latitude":29.6,"longitude":101.8,"referenceSystem":"WGS84"},{"latitude":29.7,"longitude":101.9,"referenceSystem":"WGS84"}]},"elevationProfile":{"minElevation":{"meters":3000},"maxElevation":{"meters":4700},"samples":[{"identity":"sample-1","distance":{"meters":0},"elevation":{"meters":3000}}]},"segments":[{"identity":"segment-1","order":1,"name":"第一段","mainTrackRange":{"startPathPosition":{"precedingPositionIndex":0,"progressToNextPosition":0},"endPathPosition":{"precedingPositionIndex":1}}}],"keyPoints":[{"identity":"point-1","name":"垭口","positions":[{"latitude":29.6,"longitude":101.8,"referenceSystem":"WGS84"}],"media":["https://example.test/pass.jpg"]}],"waterSources":[{"identity":"water-1","name":"溪流","positions":[{"latitude":29.6,"longitude":101.8,"referenceSystem":"WGS84"}],"sourceType":"溪流","seasonalReliability":"雨季稳定","treatmentRecommended":true,"treatmentAdvice":"过滤后饮用"}],"supplyPoints":[{"identity":"supply-1","name":"补给站","positions":[{"latitude":29.7,"longitude":101.9,"referenceSystem":"WGS84"}],"availableItems":["饮用水","能量棒"]}],"communicationAndSafety":{"coverageSummary":"部分路段无信号"},"seasonalWeather":{"bestSeasons":["秋季"]},"seasonalEquipmentRecommendations":[{"identity":"gear-1","seasonOrCondition":"雨季","name":"雨衣","level":"required"}]}}}"#.utf8)
        let service = RouteService(apiClient: MockAPIClient(fixtures: [request.identifier: detailData]))

        let detail = try await service.getRouteDetail(id: "route-1")
        let version = detail.currentVersion

        XCTAssertEqual(version.summary.maxElevation?.meters, 4_700)
        XCTAssertEqual(version.summary.suggestedDays, 3)
        XCTAssertEqual(version.summary.tags, ["高山"])
        XCTAssertEqual(version.elevationProfile?.samples.first?.elevation.meters, 3_000)
        XCTAssertEqual(version.segments?.first?.mainTrackRange?.endPathPosition.precedingPositionIndex, 1)
        XCTAssertEqual(version.keyPoints?.first?.media, ["https://example.test/pass.jpg"])
        XCTAssertEqual(version.waterSources?.first?.treatmentAdvice, "过滤后饮用")
        XCTAssertEqual(version.supplyPoints?.first?.availableItems, ["饮用水", "能量棒"])
        XCTAssertEqual(version.communicationAndSafety?.coverageSummary, "部分路段无信号")
        XCTAssertEqual(version.seasonalWeather?.bestSeasons, ["秋季"])
        XCTAssertEqual(version.seasonalEquipmentRecommendations?.first?.level, .required)
    }

    private static func fixtures() -> [String: Data] {
        let browse = Data(#"{"data":{"items":[{"routeId":"route-1","currentVersionId":"version-1","cover":"https://example.test/cover.jpg","name":"贡嘎环线","region":"四川甘孜","difficulty":"中等","distance":{"meters":42500},"ascent":{"meters":2300},"estimatedDuration":{"seconds":259200}}]}}"#.utf8)
        let search = Data(#"{"data":{"state":"completed","items":[{"routeId":"route-1","currentVersionId":"version-1","name":"贡嘎环线","region":"四川甘孜","distance":{"meters":42500},"estimatedDuration":{"seconds":259200}}]}}"#.utf8)
        let detail = Data(#"{"data":{"routeId":"route-1","currentVersion":{"versionId":"version-1","summary":{"routeType":"multi_day","name":"贡嘎环线","region":"四川甘孜","start":{"name":"起点"},"end":{"name":"终点"},"estimatedDuration":{"seconds":259200},"distance":{"meters":42500}},"mainTrackAvailability":"pending_review","generationEligibility":{"eligible":false,"missingReasons":["validMainTrack"]}}}}"#.utf8)
        return [
            PublicRouteAPI.Featured().identifier: browse,
            PublicRouteAPI.All().identifier: browse,
            PublicRouteAPI.Search(query: "贡嘎").identifier: search,
            PublicRouteAPI.Detail(id: "route-1").identifier: detail,
        ]
    }
}
