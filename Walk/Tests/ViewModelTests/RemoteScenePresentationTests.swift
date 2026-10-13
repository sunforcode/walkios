import XCTest
import WalkData
@testable import Walk

@MainActor
final class RemoteScenePresentationTests: XCTestCase {
    func testRealTripSelectsRemoteScenesByDayIdentityRatherThanArrayPosition() async throws {
        let source = try await fixture()
        let images = scenes(source, days: [source.days.days[2], source.days.days[0]])
        let overview = TripExpeditionPresentation(source: source, selection: .overview, remoteScenes: images)
        XCTAssertEqual(overview.artwork, .remoteURL(URL(string: "https://scene.test/overview.png")!))
        let third = TripExpeditionPresentation(source: source, selection: .day(3), remoteScenes: images)
        XCTAssertEqual(third.artwork, .remoteURL(URL(string: "https://scene.test/\(source.days.days[2].identity).png")!))
        XCTAssertTrue(third.routePath.isEmpty)
        XCTAssertTrue(third.landmarks.isEmpty)
        XCTAssertNil(third.elevationProfile, "场景图不能授权模拟数据的剖面映射")
        let missing = TripExpeditionPresentation(source: source, selection: .day(2), remoteScenes: images)
        XCTAssertEqual(missing.artwork, .unavailable)
        XCTAssertFalse(missing.timeline.isEmpty)
    }

    func testInvalidRevisionRejectsAllImagesAndMockStillUsesLocalAssets() async throws {
        let source = try await fixture()
        let wrong = scenes(source, revision: "stale")
        XCTAssertEqual(TripExpeditionPresentation(source: source, selection: .overview, remoteScenes: wrong).artwork, .unavailable)
        XCTAssertEqual(TripExpeditionPresentation(source: source, selection: .overview).artwork, .unavailable)
        XCTAssertEqual(TripExpeditionPresentation(source: source, selection: .day(1), demoScenesEnabled: true).artwork, .bundledAsset("YadingSceneDay1"))
    }

    func testSceneFailureDoesNotBlockMainTripAndRetryCanLoadArtwork() async throws {
        let source = try await fixture()
        var fail = true
        let sut = model(source) { _ in
            if fail { throw APIClientError.http(statusCode: 404) }
            return self.scenes(source)
        }
        await sut.loadTrip(id: source.detail.trip.identity)
        XCTAssertNotNil(sut.trip)
        XCTAssertFalse(sut.isLoading)
        await sut.refreshScenes()
        XCTAssertNil(sut.scenes)
        XCTAssertNil(sut.errorMessage)
        fail = false
        await sut.refreshScenes()
        XCTAssertEqual(sut.scenes?.sceneRevision, "scene-1")
    }

    func testLateSceneReadCannotPublishAfterTaskCancellationOrReload() async throws {
        let source = try await fixture()
        let gate = SceneResponseGate()
        let sut = model(source) { _ in await gate.read() }
        await sut.loadTrip(id: source.detail.trip.identity)
        let request = Task { await sut.refreshScenes() }
        await gate.waitUntilRequested()
        request.cancel()
        await sut.loadTrip(id: source.detail.trip.identity)
        await gate.finish(scenes(source))
        await request.value
        XCTAssertNil(sut.scenes)
        XCTAssertNotNil(sut.trip)
    }

    func testRevisionChangingMutationDiscardsPendingAndPublishedArtwork() async throws {
        let source = try await fixture()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source.detail)) as? [String: Any])
        object["revision"] = "after-cancel"
        var status = try XCTUnwrap(object["routeVersionStatus"] as? [String: Any])
        status["tripRevision"] = "after-cancel"
        object["routeVersionStatus"] = status
        let changed = try JSONDecoder().decode(PersonalTripDetail.self, from: JSONSerialization.data(withJSONObject: object))
        let gate = SceneResponseGate()
        var shouldDelay = false
        let sut = TripDetailViewModel(
            loadDetail: { _ in source.detail }, loadDays: { _ in source.days },
            loadWeather: { _ in throw APIClientError.http(statusCode: 404) },
            loadScenes: { _ in shouldDelay ? await gate.read() : self.scenes(source) },
            cancelTrip: { _, _, _, _ in changed }
        )
        await sut.loadTrip(id: source.detail.trip.identity)
        await sut.refreshScenes()
        XCTAssertNotNil(sut.scenes)
        shouldDelay = true
        let request = Task { await sut.refreshScenes() }
        await gate.waitUntilRequested()
        await sut.cancelTrip(id: source.detail.trip.identity)
        XCTAssertEqual(sut.trip?.revision, "after-cancel")
        XCTAssertNil(sut.scenes)
        await gate.finish(scenes(source))
        await request.value
        XCTAssertNil(sut.scenes)
    }

    func testRouteGalleryPreservesLegacyImagesAndLabelsExplicitReferenceDays() async throws {
        let client = MockAPIClient(fixtures: DefaultMockFixtures.all(bundle: .main))
        let route = try await client.execute(PublicRouteAPI.Detail(id: "route-yading-5d"))
        let day = try XCTUnwrap(route.currentVersion.referenceDays?.last)
        let artwork = PublicRouteScenes(routeID: route.routeId, routeVersionID: route.currentVersion.versionId, sceneRevision: "s", overview: image("overview"), days: [.init(referenceDayID: day.identity, image: image("last"))])
        let presentation = RouteDetailPresentation(route: route, scenes: artwork)
        XCTAssertEqual(presentation.images.count, route.currentVersion.images?.count ?? 0)
        XCTAssertEqual(presentation.sceneImages.count, 2)
        XCTAssertEqual(presentation.sceneImages.last?.contextLabel, "第\(day.dayNumber)天 · AIGC 场景示意")
        let wrong = PublicRouteScenes(routeID: route.routeId, routeVersionID: "stale", sceneRevision: "s", overview: image("wrong"), days: [])
        XCTAssertEqual(RouteDetailPresentation(route: route, scenes: wrong).images.count, route.currentVersion.images?.count ?? 0)
        XCTAssertTrue(RouteDetailPresentation(route: route, scenes: wrong).sceneImages.isEmpty)
    }

    func testRouteScenesAreIndependentAndUseLoadedVersion() async throws {
        let route = try await MockAPIClient(fixtures: DefaultMockFixtures.all(bundle: .main)).execute(PublicRouteAPI.Detail(id: "route-yading-5d"))
        let service = SceneRouteService(route: route)
        let sut = RouteDetailViewModel(service: service)
        await sut.loadRoute(id: route.routeId)
        XCTAssertNotNil(sut.route)
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(service.sceneRequests.isEmpty)
        await sut.refreshScenes()
        XCTAssertEqual(service.sceneRequests, [route.currentVersion.versionId])
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.presentation?.sceneImages.last?.source, "https://scene.test/overview.png")
    }

    private func fixture() async throws -> TripDetailPresentation {
        let client = MockAPIClient(fixtures: DefaultMockFixtures.all(bundle: .main))
        let detail = try await client.execute(PersonalTripAPI.Detail(tripID: "trip-yading-5d"))
        let days = try await client.execute(PersonalTripAPI.Days(tripID: "trip-yading-5d"))
        return .init(detail: detail, days: days, routeVersionStatus: detail.routeVersionStatus)
    }

    private func image(_ id: String) -> SceneImage {
        .init(mediaID: id, imageURL: "https://scene.test/\(id).png", width: 1448, height: 1086, kind: .aigc)
    }

    private func scenes(_ source: TripDetailPresentation, revision: String? = nil, days: [PersonalTripDay]? = nil) -> PersonalTripScenes {
        .init(tripID: source.detail.trip.identity, tripRevision: revision ?? source.detail.revision, routeVersionID: source.detail.routeReference.adoptedRouteVersionID, sceneRevision: "scene-1", overview: image("overview"), days: (days ?? source.days.days).map { .init(tripDayID: $0.identity, image: image($0.identity)) })
    }

    private func model(_ source: TripDetailPresentation, loadScenes: @escaping (String) async throws -> PersonalTripScenes) -> TripDetailViewModel {
        .init(loadDetail: { _ in source.detail }, loadDays: { _ in source.days }, loadWeather: { _ in throw APIClientError.http(statusCode: 404) }, loadScenes: loadScenes)
    }
}

private actor SceneResponseGate {
    private var continuation: CheckedContinuation<PersonalTripScenes, Never>?
    private var requested: CheckedContinuation<Void, Never>?
    func read() async -> PersonalTripScenes {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            requested?.resume()
            requested = nil
        }
    }
    func waitUntilRequested() async {
        if continuation != nil { return }
        await withCheckedContinuation { requested = $0 }
    }
    func finish(_ value: PersonalTripScenes) { continuation?.resume(returning: value); continuation = nil }
}

private final class SceneRouteService: RouteDetailServicing {
    let route: PublicRouteDetail
    var sceneRequests: [String] = []
    init(route: PublicRouteDetail) { self.route = route }
    func getRouteDetail(id: String) async throws -> PublicRouteDetail { route }
    func getRouteScenes(id: String, routeVersionID: String) async throws -> PublicRouteScenes {
        sceneRequests.append(routeVersionID)
        return .init(routeID: id, routeVersionID: routeVersionID, sceneRevision: "s", overview: .init(mediaID: "o", imageURL: "https://scene.test/overview.png", width: 1448, height: 1086, kind: .aigc), days: [])
    }
}
