import XCTest
@testable import Walk

@MainActor
final class RouteDetailViewModelTests: XCTestCase {
    func testDiscoveryLoadsFeaturedPublicSummaries() async {
        let service = RouteDiscoveryServiceStub(
            featured: PublicRouteDiscoveryResult(items: [Self.browseSummary])
        )
        let sut = RouteDiscoveryViewModel(service: service)

        await sut.loadRoutes()

        XCTAssertEqual(sut.routes, [Self.browseSummary])
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testDiscoverySearchKeepsInitialStateForEmptyQuery() async {
        let service = RouteDiscoveryServiceStub(
            search: PublicRouteSearchResult(state: .initial, items: [])
        )
        let sut = RouteDiscoveryViewModel(service: service)

        await sut.search(query: "")

        XCTAssertEqual(sut.searchState, .initial)
        XCTAssertTrue(sut.searchResults.isEmpty)
    }

    func testSearchEmptyInputClearsPreviousResultsWithoutCallingServerAgain() async {
        let service = RouteDiscoveryServiceStub(
            searchResults: [
                PublicRouteSearchResult(state: .completed, items: [Self.searchSummary])
            ]
        )
        let sut = RouteDiscoveryViewModel(service: service)

        await sut.search(query: "贡嘎")
        await sut.search(query: nil)

        XCTAssertEqual(sut.searchState, .initial)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertEqual(service.searchQueries, ["贡嘎"])
    }

    func testCollectionLoadsAllPublicRoutes() async {
        let service = RouteDiscoveryServiceStub(
            all: PublicRouteCollectionResult(items: [Self.browseSummary])
        )
        let sut = RouteCollectionViewModel(service: service)

        await sut.loadRoutes()

        XCTAssertEqual(sut.routes, [Self.browseSummary])
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testRootOwnsRouteListSearchAndDetailNavigation() throws {
        let rootSource = try productionSource(at: "App/RootView.swift")
        let routeSource = try productionSource(at: "Features/Routes/RouteDiscoveryView.swift")

        XCTAssertTrue(rootSource.contains("case .routeSearch:"))
        XCTAssertTrue(rootSource.contains("RouteSearchView("))
        XCTAssertTrue(routeSource.contains("onNavigate(.routeSearch)"))
        XCTAssertTrue(routeSource.contains("onNavigate(.routeDetail(route.routeId))"))
        XCTAssertFalse(routeSource.contains("NavigationLink(destination: RouteSearchView"))
    }

    func testRouteDetailRequiresGenerateCallback() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertFalse(source.contains("onGenerateTrip: @escaping (String) -> Void = { _ in }"))
        XCTAssertTrue(source.contains("onGenerateTrip(routeId)"))
    }

    func testDetailProjectsTrackOnlyWhenServerDeclaresValid() async {
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(
                identity: "track-1",
                path: [
                    PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84"),
                    PublicRouteGeoPosition(latitude: 29.7, longitude: 101.9, referenceSystem: "WGS84"),
                ]
            )
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.routeId)

        XCTAssertEqual(sut.route, detail)
        XCTAssertEqual(sut.mapCoordinates.map(\.latitude), [29.6, 29.7])
        XCTAssertFalse(sut.hasUnavailableTrack)
    }

    func testOnlyServerDeclaredValidMainTrackRangesCreateSelectableSegments() async {
        let path = [
            PublicRouteGeoPosition(latitude: 29.0, longitude: 101.0, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 30.0, longitude: 102.0, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 31.0, longitude: 103.0, referenceSystem: "WGS84"),
        ]
        let ranged = PublicRouteSegment(
            identity: "segment-ranged",
            order: 1,
            name: "明确范围",
            mainTrackRange: PublicRouteMainTrackRange(
                startPathPosition: .init(precedingPositionIndex: 0, progressToNextPosition: 0.5),
                endPathPosition: .init(precedingPositionIndex: 2, progressToNextPosition: nil)
            )
        )
        let unranged = PublicRouteSegment(identity: "segment-unranged", order: 2, name: "无范围")
        let invalid = PublicRouteSegment(
            identity: "segment-invalid",
            order: 3,
            name: "越界范围",
            mainTrackRange: PublicRouteMainTrackRange(
                startPathPosition: .init(precedingPositionIndex: 2, progressToNextPosition: nil),
                endPathPosition: .init(precedingPositionIndex: 8, progressToNextPosition: nil)
            )
        )
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(identity: "track-1", path: path),
            segments: [ranged, unranged, invalid]
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.routeId)

        XCTAssertEqual(sut.mapSegments.map(\.id), ["segment-ranged"])
        XCTAssertEqual(sut.selectableSegments.map(\.id), ["segment-ranged"])
        XCTAssertEqual(sut.mapSegments[0].coordinates.map(\.latitude), [29.5, 30.0, 31.0])
        XCTAssertTrue(sut.canSelectSegment("segment-ranged"))
        XCTAssertFalse(sut.canSelectSegment("segment-unranged"))
        sut.selectSegment("segment-ranged")
        XCTAssertEqual(sut.selectedSegmentID, "segment-ranged")
    }

    func testDetailOmitsPendingReviewTrackAndShowsUnavailableState() async {
        let detail = Self.detail(availability: .pendingReview, mainTrack: nil)
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.routeId)

        XCTAssertTrue(sut.mapCoordinates.isEmpty)
        XCTAssertTrue(sut.poiAnnotations.isEmpty)
        XCTAssertTrue(sut.waypointAnnotations.isEmpty)
        XCTAssertTrue(sut.hasUnavailableTrack)
    }

    func testDetailProjectsElevationSamplesAndNamedPointMedia() async {
        let path = [
            PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 29.7, longitude: 101.9, referenceSystem: "WGS84"),
        ]
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(identity: "track-1", path: path),
            elevationProfile: PublicRouteElevationProfile(
                minElevation: RouteElevation(meters: 3_000),
                maxElevation: RouteElevation(meters: 3_200),
                samples: [
                    PublicRouteElevationSample(
                        identity: "sample-1",
                        distance: RouteDistance(meters: 0),
                        elevation: RouteElevation(meters: 3_000)
                    ),
                    PublicRouteElevationSample(
                        identity: "sample-2",
                        distance: RouteDistance(meters: 1_000),
                        elevation: RouteElevation(meters: 3_200)
                    ),
                ]
            ),
            keyPoints: [
                PublicRouteNamedPoint(
                    identity: "point-1",
                    name: "垭口",
                    positions: [path[0]],
                    media: ["https://example.test/pass.jpg"]
                )
            ],
            interestPoints: [
                PublicRouteNamedPoint(
                    identity: "poi-1",
                    name: "冰川",
                    positions: [path[1]],
                    media: ["https://example.test/glacier.jpg"]
                )
            ]
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.routeId)

        XCTAssertEqual(sut.elevationSamples.map(\.elevation), [3_000, 3_200])
        XCTAssertEqual(sut.waypointAnnotations.first?.imageURL?.absoluteString, "https://example.test/pass.jpg")
        XCTAssertEqual(sut.poiAnnotations.first?.imageURL?.absoluteString, "https://example.test/glacier.jpg")
    }

    func testDetailProjectsOnlyApprovedPublicFacts() async {
        let detail = Self.detail(availability: .missing, mainTrack: nil)
        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertEqual(presentation.name, "贡嘎环线")
        XCTAssertEqual(presentation.summaryMetrics.map(\.title), ["距离", "时长", "爬升", "下降"])
        XCTAssertEqual(presentation.sections.map(\.title), ["路线概览", "路线分段", "关键点", "通信与安全", "路线影像"])
        XCTAssertFalse(presentation.sections.flatMap(\.items).contains { ["收藏", "评分", "热度", "使用次数", "创建者", "拼车联系人", "相关路线"].contains($0.title) })
    }

    func testGenerationActionIsEnabledOnlyWhenServerDeclaresRouteEligible() {
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(
                identity: "track-1",
                path: [PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84")]
            )
        )

        let action = RouteDetailPresentation(route: detail).generationAction

        XCTAssertEqual(action.title, "生成我的行程")
        XCTAssertTrue(action.isEnabled)
        XCTAssertNil(action.unavailableMessage)
    }

    func testGenerationActionExplainsServerOrderedMissingReasonsWhenDisabled() {
        let detail = Self.detail(availability: .missing, mainTrack: nil)

        let action = RouteDetailPresentation(route: detail).generationAction

        XCTAssertEqual(action.title, "生成我的行程")
        XCTAssertFalse(action.isEnabled)
        XCTAssertEqual(action.unavailableMessage, "缺少：有效主轨迹")
    }

    func testLoadFailureCanBeRetried() async {
        let detail = Self.detail(availability: .missing, mainTrack: nil)
        let service = RouteDetailServiceStub(
            detail: detail,
            loadErrors: [APIClientError.transport("暂时不可用")]
        )
        let sut = RouteDetailViewModel(service: service)

        await sut.loadRoute(id: detail.routeId)
        XCTAssertEqual(sut.errorMessage, "暂时不可用")

        await sut.retry()
        XCTAssertEqual(sut.route, detail)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(service.loadedIDs, [detail.routeId, detail.routeId])
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static let browseSummary = PublicRouteBrowseSummary(
        routeId: "route-1",
        currentVersionId: "version-1",
        cover: "https://example.test/cover.jpg",
        name: "贡嘎环线",
        region: "四川甘孜",
        difficulty: "中等",
        distance: RouteDistance(meters: 42_500),
        ascent: RouteElevationGain(meters: 2_300),
        estimatedDuration: RouteDuration(seconds: 259_200)
    )

    private static let searchSummary = PublicRouteSearchSummary(
        routeId: "route-1",
        currentVersionId: "version-1",
        cover: nil,
        name: "贡嘎环线",
        region: "四川甘孜",
        difficulty: "中等",
        distance: RouteDistance(meters: 42_500),
        estimatedDuration: RouteDuration(seconds: 259_200)
    )

    private static func detail(
        availability: MainTrackAvailability,
        mainTrack: PublicRouteMainTrack?,
        segments: [PublicRouteSegment]? = nil,
        elevationProfile: PublicRouteElevationProfile? = nil,
        keyPoints: [PublicRouteNamedPoint]? = nil,
        interestPoints: [PublicRouteNamedPoint]? = nil
    ) -> PublicRouteDetail {
        PublicRouteDetail(
            routeId: "route-1",
            currentVersion: PublicRouteVersionDetail(
                versionId: "version-1",
                summary: PublicRouteSummary(
                    routeType: .multiDay,
                    name: "贡嘎环线",
                    region: "四川甘孜",
                    start: PublicRoutePlace(name: "起点"),
                    end: PublicRoutePlace(name: "终点"),
                    estimatedDuration: RouteDuration(seconds: 259_200),
                    difficulty: "中等",
                    direction: "环线",
                    distance: RouteDistance(meters: 42_500),
                    ascent: RouteElevationGain(meters: 2_300),
                    descent: RouteElevationLoss(meters: 2_200),
                    introduction: "高山徒步路线"
                ),
                mainTrackAvailability: availability,
                generationEligibility: RouteGenerationEligibility(
                    eligible: availability == .valid,
                    missingReasons: availability == .valid ? nil : [.validMainTrack]
                ),
                mainTrack: mainTrack,
                elevationProfile: elevationProfile,
                segments: segments ?? [
                    PublicRouteSegment(identity: "segment-1", order: 1, name: "第一段")
                ],
                keyPoints: keyPoints ?? [
                    PublicRouteNamedPoint(
                        identity: "point-1",
                        name: "垭口",
                        positions: [PublicRouteGeoPosition(latitude: 29.65, longitude: 101.85, referenceSystem: "WGS84")]
                    )
                ],
                interestPoints: interestPoints,
                communicationAndSafety: PublicRouteCommunicationAndSafety(
                    notices: [
                        PublicRouteSafetyNotice(
                            identity: "notice-1",
                            kind: "signal",
                            title: "通信提示",
                            description: "部分路段无信号",
                            positions: nil
                        )
                    ]
                ),
                images: [
                    PublicRouteImage(identity: "image-1", mediaReference: "https://example.test/cover.jpg", role: .cover)
                ]
            )
        )
    }
}

@MainActor
private final class RouteDetailServiceStub: RouteDetailServicing {
    private let detail: PublicRouteDetail
    private var loadErrors: [Error]
    var loadedIDs: [String] = []

    init(detail: PublicRouteDetail, loadErrors: [Error] = []) {
        self.detail = detail
        self.loadErrors = loadErrors
    }

    func getRouteDetail(id: String) async throws -> PublicRouteDetail {
        loadedIDs.append(id)
        if !loadErrors.isEmpty { throw loadErrors.removeFirst() }
        return detail
    }
}

private final class RouteDiscoveryServiceStub: RouteDiscoveryServicing {
    private let featured: PublicRouteDiscoveryResult
    private let allRoutes: PublicRouteCollectionResult
    private var searchResults: [PublicRouteSearchResult]
    private(set) var searchQueries: [String?] = []

    init(
        featured: PublicRouteDiscoveryResult = PublicRouteDiscoveryResult(items: []),
        all: PublicRouteCollectionResult = PublicRouteCollectionResult(items: []),
        search: PublicRouteSearchResult = PublicRouteSearchResult(state: .initial, items: []),
        searchResults: [PublicRouteSearchResult]? = nil
    ) {
        self.featured = featured
        self.allRoutes = all
        self.searchResults = searchResults ?? [search]
    }

    func getFeaturedRoutes() async throws -> PublicRouteDiscoveryResult { featured }
    func getRoutes() async throws -> PublicRouteCollectionResult { allRoutes }
    func searchRoutes(query: String?) async throws -> PublicRouteSearchResult {
        searchQueries.append(query)
        guard !searchResults.isEmpty else {
            return PublicRouteSearchResult(state: .initial, items: [])
        }
        return searchResults.removeFirst()
    }
}
