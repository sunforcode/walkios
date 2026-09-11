import XCTest
import WalkData
import WalkDesignSystem
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

    func testSearchWhitespaceEquivalentQueryKeepsInitialStateWithoutCallingService() async {
        let service = RouteDiscoveryServiceStub(
            searchError: APIClientError.transport("搜索服务不应被调用")
        )
        let sut = RouteDiscoveryViewModel(service: service)

        await sut.search(query: " \t\n\r\u{3000}")

        XCTAssertEqual(sut.searchState, .initial)
        XCTAssertTrue(sut.searchResults.isEmpty)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(service.searchQueries.isEmpty)
    }

    func testSearchPassesNonEmptyQueryToServiceUnchanged() async {
        let service = RouteDiscoveryServiceStub(
            search: PublicRouteSearchResult(state: .completed, items: [])
        )
        let sut = RouteDiscoveryViewModel(service: service)
        let query = " \t贡嘎\u{3000}\n"

        await sut.search(query: query)

        XCTAssertEqual(service.searchQueries, [query])
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

    func testSelectingSegmentAgainRestoresFullRoute() async {
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
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(identity: "track-1", path: path),
            segments: [ranged, unranged]
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))
        await sut.loadRoute(id: detail.routeId)

        sut.selectSegment("segment-ranged")
        XCTAssertEqual(sut.selectedSegmentID, "segment-ranged")

        sut.selectSegment("segment-ranged")
        XCTAssertNil(sut.selectedSegmentID)

        sut.selectSegment("segment-unranged")
        XCTAssertNil(sut.selectedSegmentID)
    }

    func testHighlightingInfoPointTargetsAllMapMarkersOfSameObject() async {
        let path = [
            PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 29.7, longitude: 101.9, referenceSystem: "WGS84"),
        ]
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(identity: "track-1", path: path),
            keyPoints: [
                PublicRouteNamedPoint(identity: "point-1", name: "埄口", positions: [path[0], path[1]])
            ]
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))
        await sut.loadRoute(id: detail.routeId)

        sut.togglePointHighlight(for: "point-1")
        XCTAssertEqual(sut.highlightedAnnotationIDs.count, 2)

        sut.togglePointHighlight(for: "point-1")
        XCTAssertTrue(sut.highlightedAnnotationIDs.isEmpty)
    }

    func testReloadingRouteClearsMapHighlight() async {
        let detail = Self.detail(availability: .valid, mainTrack: PublicRouteMainTrack(
            identity: "track-1",
            path: [
                PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84"),
                PublicRouteGeoPosition(latitude: 29.7, longitude: 101.9, referenceSystem: "WGS84"),
            ]
        ))
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))
        await sut.loadRoute(id: detail.routeId)
        sut.togglePointHighlight(for: "point-1")
        XCTAssertFalse(sut.highlightedAnnotationIDs.isEmpty)

        await sut.retry()

        XCTAssertTrue(sut.highlightedAnnotationIDs.isEmpty)
        XCTAssertNil(sut.selectedSegmentID)
    }

    func testRouteDetailRequiresGenerateCallback() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertFalse(source.contains("onGenerateTrip: @escaping (String) -> Void = { _ in }"))
        XCTAssertTrue(source.contains("onGenerateTrip(routeId)"))
    }

    func testRouteDetailUsesProductionComponentsForEveryAuditedSafeSection() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        let componentCalls = [
            "RouteBusinessComponents.RouteSummary(",
            "RouteBusinessComponents.RouteIntroduction(",
            "RouteBusinessComponents.ElevationProfile(",
            "RouteBusinessComponents.RouteReferenceDayList(",
            "RouteBusinessComponents.RouteSegmentList(",
            "RouteBusinessComponents.RoutePointSection(",
            "RouteBusinessComponents.RouteFactSection(",
        ]

        let ranges = try componentCalls.map { call in
            try XCTUnwrap(source.range(of: call), "Missing production component call: \(call)")
        }
        for (earlier, later) in zip(ranges, ranges.dropFirst()) {
            XCTAssertLessThan(earlier.lowerBound, later.lowerBound)
        }

        XCTAssertFalse(source.contains("private struct RouteDetailSummary"))
        XCTAssertFalse(source.contains("private struct RouteElevationProfileChart"))
        XCTAssertFalse(source.contains("private struct RouteDetailItemList"))
    }

    func testRouteDetailKeepsPausedMapPointDetailAndMediaStructuresUnchanged() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertTrue(source.contains("RouteMapView("))
        XCTAssertTrue(source.contains("private struct RoutePointBottomDetail"))
        XCTAssertTrue(source.contains("private struct RouteImageGrid"))
        XCTAssertTrue(source.contains("private struct RouteImageViewer"))
        XCTAssertTrue(source.contains("@State private var selectedImage: RouteDetailImagePresentation?"))
    }

    func testRouteDetailSafeProjectionAPIsPreserveOptionalityAndConfidence() throws {
        let viewModelSource = try productionSource(at: "Features/Routes/RouteDetailViewModel.swift")
        let introductionSource = try productionSource(
            at: "Features/Routes/Components/RouteIntroduction.swift"
        )
        let referenceDaySource = try productionSource(
            at: "Features/Routes/Components/RouteReferenceDayList.swift"
        )
        let segmentSource = try productionSource(
            at: "Features/Routes/Components/RouteSegmentList.swift"
        )

        [
            "var routeSummaryProjection: RouteSummaryProjection",
            "var routeIntroductionProjection: RouteIntroductionProjection?",
            "var elevationProfileProjection: ElevationProfileProjection?",
            "var referenceDayProjections: [RouteReferenceDayProjection]",
            "var routeSegmentListProjection: RouteSegmentListProjection?",
            "var routePointSectionProjections: [RoutePointSectionProjection]",
            "var routeFactSectionProjections: [RouteFactSectionProjection]",
        ].forEach { declaration in
            XCTAssertTrue(viewModelSource.contains(declaration), "Missing projection: \(declaration)")
        }
        XCTAssertTrue(introductionSource.contains("var confidence: InformationConfidence?"))
        XCTAssertTrue(referenceDaySource.contains("var title: String?"))
        XCTAssertTrue(segmentSource.contains("var start: String?"))
        XCTAssertTrue(segmentSource.contains("var end: String?"))
    }

    func testRouteDetailKeepsMapLayerBehindLoadingErrorAndContentStates() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        let mapLayer = try XCTUnwrap(source.range(of: "mapLayer(viewportHeight: geometry.size.height)"))
        let loading = try XCTUnwrap(source.range(of: "if viewModel.isLoading", range: mapLayer.upperBound..<source.endIndex))
        let error = try XCTUnwrap(source.range(of: "else if let message = viewModel.errorMessage", range: loading.upperBound..<source.endIndex))
        let content = try XCTUnwrap(source.range(of: "else if let presentation = viewModel.presentation", range: error.upperBound..<source.endIndex))

        XCTAssertLessThan(mapLayer.lowerBound, loading.lowerBound)
        XCTAssertLessThan(loading.lowerBound, error.lowerBound)
        XCTAssertLessThan(error.lowerBound, content.lowerBound)
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

    func testDetailOmitsPendingOrInvalidTrackButKeepsReliablyPositionedPoints() async {
        let position = PublicRouteGeoPosition(
            latitude: 29.65,
            longitude: 101.85,
            referenceSystem: "WGS84"
        )

        for availability in [MainTrackAvailability.pendingReview, .invalidated] {
            let detail = Self.detail(
                availability: availability,
                mainTrack: nil,
                segments: [
                    PublicRouteSegment(
                        identity: "segment-1",
                        order: 1,
                        name: "不可选分段",
                        mainTrackRange: PublicRouteMainTrackRange(
                            startPathPosition: .init(precedingPositionIndex: 0, progressToNextPosition: 0),
                            endPathPosition: .init(precedingPositionIndex: 1, progressToNextPosition: nil)
                        )
                    )
                ],
                keyPoints: [
                    PublicRouteNamedPoint(identity: "point-1", name: "垭口", positions: [position])
                ],
                interestPoints: [
                    PublicRouteNamedPoint(identity: "poi-1", name: "冰川", positions: [position])
                ],
                overnightPlaces: [
                    PublicRouteOvernightPlace(
                        identity: "overnight-1",
                        name: "山屋",
                        positions: [position],
                        elevation: RouteElevation(meters: 3_200),
                        type: "山屋",
                        facilities: ["床位"],
                        details: "需提前确认",
                        status: "待核验"
                    )
                ]
            )
            let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

            await sut.loadRoute(id: detail.routeId)

            XCTAssertTrue(sut.mapCoordinates.isEmpty)
            XCTAssertTrue(sut.mapSegments.isEmpty)
            XCTAssertEqual(sut.waypointAnnotations.map(\.title), ["垭口"])
            XCTAssertEqual(Set(sut.poiAnnotations.map(\.title)), ["冰川", "山屋"])
            XCTAssertTrue(sut.hasUnavailableTrack)
        }
    }

    func testOvernightPlacesBecomeSelectableMapAnnotations() async {
        let position = PublicRouteGeoPosition(
            latitude: 29.65,
            longitude: 101.85,
            referenceSystem: "WGS84"
        )
        let detail = Self.detail(
            availability: .valid,
            mainTrack: PublicRouteMainTrack(identity: "track-1", path: [position]),
            overnightPlaces: [
                PublicRouteOvernightPlace(
                    identity: "overnight-1",
                    name: "山屋",
                    positions: [position],
                    elevation: RouteElevation(meters: 3_200),
                    type: "山屋",
                    facilities: ["床位"],
                    details: "需提前确认",
                    status: "待核验"
                )
            ]
        )
        let sut = RouteDetailViewModel(service: RouteDetailServiceStub(detail: detail))

        await sut.loadRoute(id: detail.routeId)

        let annotation = sut.poiAnnotations.first { $0.id.hasPrefix("overnight-1-") }
        XCTAssertEqual(annotation?.title, "山屋")
        XCTAssertEqual(annotation?.category, "过夜点")
        XCTAssertEqual(annotation?.subCategory, "山屋")
        XCTAssertEqual(annotation?.detail, "床位 · 需提前确认 · 待核验")
    }

    func testInvalidMainTrackDoesNotExposeElevationCurve() {
        let detail = Self.detail(
            availability: .invalidated,
            mainTrack: nil,
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
            )
        )

        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertNil(presentation.elevationProfile)
        XCTAssertFalse(presentation.sections.contains { $0.id == .elevation })
    }

    func testDetailProjectsElevationSamplesAndNamedPointMedia() async throws {
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
        let sampleDistances = sut.elevationSamples.compactMap { sample in
            Mirror(reflecting: sample).children.first(where: { $0.label == "distance" })?.value as? Double
        }
        XCTAssertEqual(sampleDistances, [0, 1_000])
        XCTAssertEqual(sut.waypointAnnotations.first?.imageURL?.absoluteString, "https://example.test/pass.jpg")
        XCTAssertEqual(sut.poiAnnotations.first?.imageURL?.absoluteString, "https://example.test/glacier.jpg")

        let presentation = RouteDetailPresentation(route: detail)
        XCTAssertEqual(presentation.elevationProfile?.samples, sut.elevationSamples)
        XCTAssertEqual(presentation.elevationProfile?.minElevation, 3_000)
        XCTAssertEqual(presentation.elevationProfile?.maxElevation, 3_200)
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        XCTAssertTrue(source.contains("RouteBusinessComponents.ElevationProfile("))
    }

    func testOneDayPresentationNeverBuildsReferenceDaysSection() {
        let referenceDay = PublicRouteReferenceDay(
            identity: "reference-day-1",
            dayNumber: 1,
            title: "D1",
            start: nil,
            end: nil,
            distance: nil,
            estimatedDuration: nil,
            ascent: nil,
            descent: nil,
            maxElevation: nil,
            minElevation: nil,
            accommodation: nil,
            notes: nil
        )
        let detail = Self.detail(
            routeType: .oneDay,
            availability: .missing,
            mainTrack: nil,
            referenceDays: [referenceDay]
        )

        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertFalse(presentation.sections.contains { $0.id == .referenceDays })
        XCTAssertTrue(presentation.referenceDayProjections.isEmpty)
    }

    func testSafeComponentProjectionsPreserveOptionalityConfidenceAndServerOrder() {
        let confidence = InformationConfidence(status: "verified", category: .publicRouteFact)
        let referenceDays = [
            PublicRouteReferenceDay(
                identity: "day-1",
                dayNumber: 1,
                title: nil,
                start: PublicRoutePlace(name: "甲"),
                end: nil,
                distance: RouteDistance(meters: 1_000),
                estimatedDuration: nil,
                ascent: nil,
                descent: nil,
                maxElevation: nil,
                minElevation: nil,
                accommodation: "营地",
                notes: "先到先得"
            ),
            PublicRouteReferenceDay(
                identity: "day-2",
                dayNumber: 2,
                title: "翻越垭口",
                start: nil,
                end: PublicRoutePlace(name: "乙"),
                distance: nil,
                estimatedDuration: nil,
                ascent: nil,
                descent: nil,
                maxElevation: nil,
                minElevation: nil,
                accommodation: nil,
                notes: nil
            ),
        ]
        let segments = [
            PublicRouteSegment(identity: "segment-2", order: 2, name: "第二段", notes: "保留备注"),
            PublicRouteSegment(
                identity: "segment-1",
                order: 1,
                name: "第一段",
                start: PublicRoutePlace(name: "起点"),
                end: PublicRoutePlace(name: "终点")
            ),
        ]
        let detail = Self.detail(
            availability: .missing,
            mainTrack: nil,
            professionalAnalysis: PublicRouteProfessionalAnalysis(
                fitnessRequirement: QualifiedString(value: "高负重能力", confidence: confidence),
                experienceRequirement: nil,
                mainTerrain: nil,
                technicalDifficulty: nil,
                highAltitudeImpact: nil,
                exposedSections: nil,
                dangerAreas: nil,
                signalCoverage: nil,
                evacuationDifficulty: nil
            ),
            referenceDays: referenceDays,
            segments: segments,
            campsites: [
                PublicRouteCampsite(
                    identity: "camp-1",
                    name: "河谷营地",
                    positions: [],
                    elevation: RouteElevation(meters: 3_100),
                    details: "近水源",
                    status: "开放"
                )
            ],
            waterSources: [
                PublicRouteWaterSource(
                    identity: "water-1",
                    name: "溪流",
                    positions: [],
                    elevation: nil,
                    sourceType: "季节性溪流",
                    seasonalReliability: "雨季稳定",
                    treatmentRecommended: true,
                    treatmentAdvice: "过滤",
                    description: "流量较小"
                )
            ]
        )

        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertEqual(
            presentation.routeIntroductionProjection?.analysisItems.first?.confidence,
            confidence
        )
        XCTAssertEqual(presentation.referenceDayProjections.map(\.id), ["day-1", "day-2"])
        XCTAssertNil(presentation.referenceDayProjections.first?.title)
        XCTAssertEqual(presentation.routeSegmentListProjection?.segments.map(\.id), ["segment-2", "segment-1"])
        XCTAssertNil(presentation.routeSegmentListProjection?.segments.first?.start)
        XCTAssertNil(presentation.routeSegmentListProjection?.segments.first?.end)
        XCTAssertEqual(presentation.routeSegmentListProjection?.segments.first?.description, "保留备注")
        XCTAssertEqual(
            presentation.routePointSectionProjections.map(\.title),
            ["关键点", "营地", "水源"]
        )
        XCTAssertEqual(presentation.routePointSectionProjections[1].points.first?.type, "开放")
        XCTAssertEqual(
            presentation.routePointSectionProjections[2].points.first?.description,
            "雨季稳定 · 建议处理后饮用 · 过滤 · 流量较小"
        )
        XCTAssertEqual(presentation.routeFactSectionProjections.map(\.title), ["通信与安全"])
    }

    func testDetailProjectsOnlyApprovedPublicFacts() async {
        let detail = Self.detail(availability: .missing, mainTrack: nil)
        let presentation = RouteDetailPresentation(route: detail)

        XCTAssertEqual(presentation.name, "贡嘎环线")
        XCTAssertEqual(presentation.summaryMetrics.map(\.title), ["距离", "预计用时", "累计爬升", "累计下降"])
        XCTAssertEqual(presentation.sections.map(\.title), ["路线介绍与专业分析", "路线分段", "关键点", "通信与安全", "路线影像"])
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
        routeType: PublicRouteType = .multiDay,
        availability: MainTrackAvailability,
        mainTrack: PublicRouteMainTrack?,
        professionalAnalysis: PublicRouteProfessionalAnalysis? = nil,
        referenceDays: [PublicRouteReferenceDay]? = nil,
        segments: [PublicRouteSegment]? = nil,
        elevationProfile: PublicRouteElevationProfile? = nil,
        keyPoints: [PublicRouteNamedPoint]? = nil,
        interestPoints: [PublicRouteNamedPoint]? = nil,
        campsites: [PublicRouteCampsite]? = nil,
        overnightPlaces: [PublicRouteOvernightPlace]? = nil,
        waterSources: [PublicRouteWaterSource]? = nil
    ) -> PublicRouteDetail {
        PublicRouteDetail(
            routeId: "route-1",
            currentVersion: PublicRouteVersionDetail(
                versionId: "version-1",
                summary: PublicRouteSummary(
                    routeType: routeType,
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
                professionalAnalysis: professionalAnalysis,
                referenceDays: referenceDays,
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
                campsites: campsites,
                overnightPlaces: overnightPlaces,
                waterSources: waterSources,
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
    private let searchError: Error?
    private(set) var searchQueries: [String?] = []

    init(
        featured: PublicRouteDiscoveryResult = PublicRouteDiscoveryResult(items: []),
        all: PublicRouteCollectionResult = PublicRouteCollectionResult(items: []),
        search: PublicRouteSearchResult = PublicRouteSearchResult(state: .initial, items: []),
        searchResults: [PublicRouteSearchResult]? = nil,
        searchError: Error? = nil
    ) {
        self.featured = featured
        self.allRoutes = all
        self.searchResults = searchResults ?? [search]
        self.searchError = searchError
    }

    func getFeaturedRoutes() async throws -> PublicRouteDiscoveryResult { featured }
    func getRoutes() async throws -> PublicRouteCollectionResult { allRoutes }
    func searchRoutes(query: String?) async throws -> PublicRouteSearchResult {
        searchQueries.append(query)
        if let searchError { throw searchError }
        guard !searchResults.isEmpty else {
            return PublicRouteSearchResult(state: .initial, items: [])
        }
        return searchResults.removeFirst()
    }
}
