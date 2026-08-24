import XCTest
import CoreLocation
@testable import Walk

@MainActor
final class RouteDetailViewModelTests: XCTestCase {
    func testLoadPublishesSuccessAndProjectsSortedMapData() async throws {
        let detail = try Self.fixture { data in
            var points = data["track_points"] as? [[String: Any]] ?? []
            guard var later = points.first else { return }
            later["id"] = "track-2"
            later["name"] = "终点"
            later["latitude"] = 30.0
            later["sequence_number"] = 2
            points.insert(later, at: 0)
            data["track_points"] = points
        }
        let service = RouteDetailServiceStub(detail: detail)
        let sut = RouteDetailViewModel(service: service)

        await sut.loadRoute(id: detail.id)

        XCTAssertEqual(sut.route, detail)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.mapCoordinates.map(\.latitude), [29.6001, 30.0])
        XCTAssertEqual(sut.poiAnnotations.map(\.title), ["垭口"])
        XCTAssertEqual(sut.selectableTrackPoints.map(\.title), ["起点", "终点"])
        XCTAssertEqual(sut.waypointAnnotations.map(\.id), ["waypoint-start"])
        XCTAssertEqual(sut.waypointAnnotations.map(\.title), ["起点"])
        XCTAssertFalse(sut.isFavorite)
    }

    func testLoadFailureCanBeRetried() async throws {
        let detail = try Self.fixture()
        let service = RouteDetailServiceStub(detail: detail, loadErrors: [APIClientError.transport("暂时不可用")])
        let sut = RouteDetailViewModel(service: service)

        await sut.loadRoute(id: detail.id)
        XCTAssertEqual(sut.errorMessage, "暂时不可用")

        await sut.retry()
        XCTAssertEqual(sut.route, detail)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(service.loadedIDs, [detail.id, detail.id])
    }

    func testEmptyCollectionsKeepExplicitEmptyMapState() async throws {
        let detail = try Self.fixture { data in
            data["poi_points"] = []
            data["track_points"] = []
        }
        let service = RouteDetailServiceStub(detail: detail)
        let sut = RouteDetailViewModel(service: service)

        await sut.loadRoute(id: detail.id)

        XCTAssertTrue(sut.mapCoordinates.isEmpty)
        XCTAssertTrue(sut.poiAnnotations.isEmpty)
        XCTAssertTrue(sut.selectableTrackPoints.isEmpty)
        XCTAssertFalse(sut.waypointAnnotations.isEmpty)
        XCTAssertTrue(sut.hasMissingTrack)
    }

    func testUnknownEnumsUseMissingDataText() async throws {
        let detail = try Self.fixture { data in
            data["difficulty"] = 999
            data["route_type"] = 999
        }
        let sut = RouteDetailPresentation(route: detail)

        XCTAssertEqual(sut.difficulty, "暂无数据")
        XCTAssertEqual(sut.routeType, "暂无数据")
    }

    func testFavoriteFailureRollsBackOptimisticState() async throws {
        let detail = try Self.fixture()
        let service = RouteDetailServiceStub(detail: detail, favoriteError: APIClientError.transport("收藏失败"))
        let sut = RouteDetailViewModel(service: service)
        await sut.loadRoute(id: detail.id)

        await sut.toggleFavorite()

        XCTAssertFalse(sut.isFavorite)
        XCTAssertEqual(sut.actionMessage, "收藏失败")
    }

    func testLoadPublishesLoadingBeforeServiceCompletes() async throws {
        let detail = try Self.fixture()
        let service = RouteDetailServiceStub(detail: detail, suspended: true)
        let sut = RouteDetailViewModel(service: service)

        let task = Task { await sut.loadRoute(id: detail.id) }
        while !service.didStart { await Task.yield() }
        XCTAssertTrue(sut.isLoading)
        service.resume()
        await task.value
        XCTAssertFalse(sut.isLoading)
    }

    func testPhoneIsWrittenOnlyAfterExplicitCopyAction() async throws {
        let detail = try Self.fixture()
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))
        var copiedValue: String?

        XCTAssertNil(copiedValue)
        sut.copyPhone(detail.hitchhikeContacts[0].phone) { copiedValue = $0 }

        XCTAssertEqual(copiedValue, "13800000000")
        XCTAssertEqual(sut.actionMessage, "号码已复制")
    }

    func testCompletePresentationDescribesCollapsedSummarySectionsAndActionPolicies() async throws {
        let detail = try Self.fixture()
        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertEqual(presentation.actionPolicy.shareText, "贡嘎环线")
        XCTAssertTrue(presentation.actionPolicy.usesSystemShareSheet)
        XCTAssertFalse(presentation.actionPolicy.initiatesPhoneCall)
        XCTAssertTrue(RouteDetailActionPolicy.canCopyPhone("13800000000"))
        XCTAssertFalse(RouteDetailActionPolicy.canCopyPhone("  "))
        XCTAssertEqual(Array(presentation.collapsedSummaryFields.prefix(6)), [
            "贡嘎环线", "山野行者", "中等", "环线", "环线", "四川甘孜"
        ])
        XCTAssertEqual(presentation.summaryMetrics.map(\.title), ["距离", "时长", "爬升", "下降"])
        XCTAssertEqual(presentation.collapsedSummaryFields.count, 10)
        XCTAssertFalse(presentation.summaryMetrics.contains { $0.value == "—" })
        XCTAssertEqual(presentation.sections.map(\.id), RouteDetailSectionID.allCases)
        XCTAssertEqual(presentation.sections.map(\.title), [
            "概览与环境", "行程安排", "沿途保障", "出行准备", "路线影像与热度", "相关内容"
        ])
        XCTAssertEqual(presentation.sections.map { $0.items.isEmpty }, [false, false, true, false, false, true])
        XCTAssertEqual(presentation.sections[0].items, [
            .init(id: "description", title: "路线描述", value: "高山徒步路线"),
            .init(id: "tags", title: "标签", value: "雪山、高海拔"),
            .init(id: "rating-overall", title: "总评分", value: "4.8"),
            .init(id: "rating-count", title: "评分人数", value: "36"),
            .init(id: "rating-scenery", title: "风景评分", value: "4.9"),
            .init(id: "rating-difficulty", title: "难度评分", value: "4.2"),
            .init(id: "rating-experience", title: "体验评分", value: "4.7"),
            .init(id: "rating-facilities", title: "设施评分", value: "—"),
            .init(id: "region", title: "区域", value: "四川甘孜"),
            .init(id: "route-type", title: "路线类型", value: "环线"),
            .init(id: "is-loop", title: "路线形态", value: "环线"),
            .init(id: "weather-description", title: "天气描述", value: "昼夜温差大"),
            .init(id: "weather-precautions", title: "天气注意事项", value: "暂无数据"),
            .init(id: "best-seasons", title: "最佳季节", value: "秋季"),
            .init(id: "seasonal-weather", title: "季节天气", value: "秋季：晴朗干燥")
        ])
        XCTAssertTrue(presentation.sections[1].items.contains { $0.id == "daily-plans" && $0.value == "进山" })
        XCTAssertEqual(presentation.sections[2].emptyState, "营地、水源、补给暂无数据")
        XCTAssertTrue(presentation.sections[3].items.contains { $0.id == "contacts" && $0.value == "王师傅" })
        XCTAssertTrue(presentation.sections[4].items.contains { $0.id == "popularity" && $0.value == "128" })
        XCTAssertEqual(presentation.sections[5].emptyState, "相关路线、相关行程暂无数据")
        XCTAssertTrue(presentation.images.allSatisfy { $0.failurePlaceholderSystemImage == "photo" })
        XCTAssertFalse(presentation.contacts.first?.showsPhoneByDefault ?? true)
    }

    func testEmptyPresentationStillDescribesAllSixSectionsWithEmptyStates() throws {
        let detail = try Self.fixture { data in
            data["description"] = nil
            data["region"] = nil
            data["route_type"] = nil
            data["tags"] = []
            data["ratings"] = nil
            data["weather_info"] = nil
            data["daily_plans"] = []
            data["segment_schemes"] = []
            data["poi_points"] = []
            data["hitchhike_contacts"] = []
            data["cover_url"] = nil
            data["image_urls"] = []
        }
        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertEqual(presentation.sections.map(\.id), RouteDetailSectionID.allCases)
        XCTAssertEqual(presentation.sections.map(\.title), [
            "概览与环境", "行程安排", "沿途保障", "出行准备", "路线影像与热度", "相关内容"
        ])
        XCTAssertEqual(presentation.sections.map { $0.items.isEmpty }, [false, true, true, true, false, true])
        XCTAssertEqual(presentation.sections[0].items, [
            .init(id: "description", title: "路线描述", value: "暂无数据"),
            .init(id: "tags", title: "标签", value: "暂无数据"),
            .init(id: "rating-overall", title: "总评分", value: "—"),
            .init(id: "rating-count", title: "评分人数", value: "—"),
            .init(id: "rating-scenery", title: "风景评分", value: "—"),
            .init(id: "rating-difficulty", title: "难度评分", value: "—"),
            .init(id: "rating-experience", title: "体验评分", value: "—"),
            .init(id: "rating-facilities", title: "设施评分", value: "—"),
            .init(id: "region", title: "区域", value: "暂无数据"),
            .init(id: "route-type", title: "路线类型", value: "暂无数据"),
            .init(id: "is-loop", title: "路线形态", value: "环线"),
            .init(id: "weather-description", title: "天气描述", value: "暂无数据"),
            .init(id: "weather-precautions", title: "天气注意事项", value: "暂无数据"),
            .init(id: "best-seasons", title: "最佳季节", value: "暂无数据"),
            .init(id: "seasonal-weather", title: "季节天气", value: "暂无数据")
        ])
        XCTAssertEqual(presentation.sections[1].emptyState, "暂无数据")
        XCTAssertEqual(presentation.sections[3].emptyState, "季节装备、拼车联系人暂无数据")
        XCTAssertTrue(presentation.images.isEmpty)
    }

    func testPOIProjectionRejectsInvalidCoordinates() async throws {
        let detail = try Self.fixture { data in
            var points = data["poi_points"] as? [[String: Any]] ?? []
            guard var invalid = points.first else { return }
            invalid["id"] = "poi-invalid"
            invalid["name"] = "非法点位"
            invalid["latitude"] = 95.0
            points.append(invalid)
            data["poi_points"] = points
        }
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.id)

        XCTAssertEqual(sut.poiAnnotations.map(\.id), ["poi-1"])
    }

    func testWaypointProjectionUsesAllSegmentsRejectsInvalidCoordinatesAndDeduplicatesByID() async throws {
        let detail = try Self.fixture { data in
            var schemes = data["segment_schemes"] as? [[String: Any]] ?? []
            guard var scheme = schemes.first,
                  var segments = scheme["segments"] as? [[String: Any]],
                  var segment = segments.first,
                  let start = segment["start_point"] as? [String: Any] else { return }

            var end = start
            end["id"] = "waypoint-end"
            end["name"] = "终点"
            end["description"] = "下撤点"
            end["latitude"] = 29.8
            end["longitude"] = 101.95
            end["elevation"] = 2800.0
            end["type"] = "exit"
            end["image_url"] = NSNull()
            end["icon_url"] = "https://example.test/end.png"

            var invalid = start
            invalid["id"] = "waypoint-invalid"
            invalid["latitude"] = 95.0

            segment["end_point"] = end
            segment["keypoints"] = [start, invalid]
            segments[0] = segment
            scheme["segments"] = segments
            schemes.append(scheme)
            data["segment_schemes"] = schemes
        }
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.id)

        XCTAssertEqual(sut.waypointAnnotations.map(\.id), ["waypoint-start", "waypoint-end"])
        XCTAssertEqual(sut.waypointAnnotations.map(\.title), ["起点", "终点"])
        XCTAssertEqual(sut.waypointAnnotations[1].detail, "下撤点")
        XCTAssertEqual(sut.waypointAnnotations[1].elevation, "2,800m")
        XCTAssertEqual(sut.waypointAnnotations[1].type, "exit")
        XCTAssertEqual(sut.waypointAnnotations[1].imageURL?.absoluteString, "https://example.test/end.png")
    }

    private static func fixture(
        mutate: ((inout [String: Any]) -> Void)? = nil
    ) throws -> RouteDetailResponse {
        let url = try XCTUnwrap(Bundle(for: RouteDetailViewModelTests.self).url(forResource: "route-detail-route-1", withExtension: "json"))
        let source = try Data(contentsOf: url)
        var envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: source) as? [String: Any])
        var data = try XCTUnwrap(envelope["data"] as? [String: Any])
        mutate?(&data)
        envelope["data"] = data
        return try APIJSONDecoder.decode(RouteDetailResponse.self, from: JSONSerialization.data(withJSONObject: envelope))
    }
}

@MainActor
private final class RouteDetailServiceStub: RouteDetailServicing {
    private let detail: RouteDetailResponse
    private var loadErrors: [Error]
    private let favoriteError: Error?
    private var continuation: CheckedContinuation<Void, Never>?
    private let suspended: Bool
    var loadedIDs: [String] = []
    var didStart = false

    init(detail: RouteDetailResponse, loadErrors: [Error] = [], favoriteError: Error? = nil, suspended: Bool = false) {
        self.detail = detail
        self.loadErrors = loadErrors
        self.favoriteError = favoriteError
        self.suspended = suspended
    }

    func getRouteDetailResponse(id: String) async throws -> RouteDetailResponse {
        loadedIDs.append(id)
        didStart = true
        if suspended {
            await withCheckedContinuation { continuation = $0 }
        }
        if !loadErrors.isEmpty { throw loadErrors.removeFirst() }
        return detail
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }

    func setFavorite(routeID: String, isFavorite: Bool) async throws {
        if let favoriteError { throw favoriteError }
    }
}
