import XCTest
@testable import Walk

@MainActor
final class TripListViewModelTests: XCTestCase {
    func testLoadUsesServerGroupsAndPreservesServerOrder() async {
        let current = [
            PersonalTripTestFixtures.summary(id: "active", status: .inProgress),
            PersonalTripTestFixtures.summary(id: "planned", status: .planned),
        ]
        let historical = [
            PersonalTripTestFixtures.summary(id: "newer", status: .cancelled),
            PersonalTripTestFixtures.summary(id: "older", status: .completed),
        ]
        var loadCount = 0
        let sut = TripListViewModel(loadTrips: {
            loadCount += 1
            return PersonalTripCollection(currentTrips: current, historicalTrips: historical)
        })

        await sut.loadTrips()

        XCTAssertEqual(loadCount, 1)
        XCTAssertEqual(sut.currentTrips.map(\.tripID), ["active", "planned"])
        XCTAssertEqual(sut.historicalTrips.map(\.tripID), ["newer", "older"])
    }

    func testLoadFailureDoesNotInventTrips() async {
        let sut = TripListViewModel(loadTrips: { throw APIClientError.invalidResponse })

        await sut.loadTrips()

        XCTAssertTrue(sut.currentTrips.isEmpty)
        XCTAssertTrue(sut.historicalTrips.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }
}

@MainActor
final class PersonalTripDetailViewModelTests: XCTestCase {
    func testLoadUsesPersonalDetailDaysAndWeatherWithoutPublicRouteLookup() async {
        var calls: [String] = []
        let detail = PersonalTripTestFixtures.detail(track: [
            PublicRouteGeoPosition(latitude: 29.6, longitude: 101.8, referenceSystem: "WGS84"),
            PublicRouteGeoPosition(latitude: 29.7, longitude: 101.9, referenceSystem: "WGS84"),
        ])
        let sut = TripDetailViewModel(
            loadDetail: { tripID in
                calls.append("detail:\(tripID)")
                return detail
            },
            loadDays: { tripID in
                calls.append("days:\(tripID)")
                return PersonalTripTestFixtures.days
            },
            loadWeather: { tripID in
                calls.append("weather:\(tripID)")
                return PersonalTripTestFixtures.weather
            }
        )

        await sut.loadTrip(id: "trip-1")

        XCTAssertEqual(calls.sorted(), ["days:trip-1", "detail:trip-1", "weather:trip-1"])
        XCTAssertEqual(sut.trip?.trip.identity, "trip-1")
        XCTAssertEqual(sut.mapCoordinates.map(\.latitude), [29.6, 29.7])
        XCTAssertFalse(sut.isFrozenTrackUnavailable)
    }

    func testMissingFrozenTrackRemainsUnavailableWithoutFallback() async {
        let sut = TripDetailViewModel(
            loadDetail: { _ in PersonalTripTestFixtures.detail(track: []) },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in PersonalTripTestFixtures.weather }
        )

        await sut.loadTrip(id: "trip-1")

        XCTAssertTrue(sut.mapCoordinates.isEmpty)
        XCTAssertTrue(sut.isFrozenTrackUnavailable)
    }

    func testLoadRejectsRevisionMismatchWithoutReplacingExistingProjection() async {
        let original = PersonalTripTestFixtures.detail(track: [])
        let mismatchedDays = PersonalTripDays(
            tripID: "trip-1",
            revision: "revision-2",
            startDate: original.trip.startDate,
            endDate: original.trip.endDate,
            totalDayCount: original.trip.totalDayCount,
            hikingDayCount: original.trip.hikingDayCount,
            days: []
        )
        let sut = TripDetailViewModel(
            loadDetail: { _ in original },
            loadDays: { _ in mismatchedDays },
            loadWeather: { _ in PersonalTripTestFixtures.weather }
        )

        await sut.loadTrip(id: "trip-1")

        XCTAssertNil(sut.trip)
        XCTAssertNil(sut.days)
        XCTAssertNil(sut.weather)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testMutationFailurePreservesExistingProjection() async {
        let detail = PersonalTripTestFixtures.detail(track: [])
        let sut = TripDetailViewModel(
            loadDetail: { _ in detail },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in PersonalTripTestFixtures.weather },
            loadRouteVersionStatus: { _ in detail.routeVersionStatus },
            cancelTrip: { _, _, _, _ in throw APIClientError.invalidResponse },
            migrateTrip: { _, _, _, _ in throw APIClientError.invalidResponse },
            idempotencyKey: { "mutation-key" }
        )
        await sut.loadTrip(id: "trip-1")

        await sut.cancelTrip(id: "trip-1")

        XCTAssertEqual(sut.trip, detail)
        XCTAssertEqual(sut.days, PersonalTripTestFixtures.days)
        XCTAssertEqual(sut.weather, PersonalTripTestFixtures.weather)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testCancelReusesIdempotencyKeyForUnknownResultRetryAndRotatesAfterTerminalResponse() async {
        let initial = PersonalTripTestFixtures.detail(track: [])
        let cancelled = PersonalTripTestFixtures.detail(revision: "revision-2", status: .cancelled, track: [])
        var keys: [String] = []
        var attempts = 0
        var generatedKeys = ["cancel-1", "cancel-2"]
        let sut = TripDetailViewModel(
            loadDetail: { _ in initial },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in PersonalTripTestFixtures.weather },
            loadRouteVersionStatus: { _ in initial.routeVersionStatus },
            cancelTrip: { _, _, _, key in
                keys.append(key)
                attempts += 1
                if attempts == 1 { throw APIClientError.transport("连接中断") }
                if attempts == 2 { throw APIClientError.api(code: "trip_state_conflict", message: "状态已变化", retryable: false) }
                return cancelled
            },
            idempotencyKey: { generatedKeys.removeFirst() }
        )
        await sut.loadTrip(id: "trip-1")

        await sut.cancelTrip(id: "trip-1")
        await sut.cancelTrip(id: "trip-1")
        await sut.cancelTrip(id: "trip-1")

        XCTAssertEqual(keys, ["cancel-1", "cancel-1", "cancel-2"])
    }

    func testCancelReusesIdempotencyKeyAfterHTTPServerFailure() async {
        let initial = PersonalTripTestFixtures.detail(track: [])
        var keys: [String] = []
        var generatedKeys = ["cancel-1", "cancel-2"]
        let sut = TripDetailViewModel(
            loadDetail: { _ in initial },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in PersonalTripTestFixtures.weather },
            loadRouteVersionStatus: { _ in initial.routeVersionStatus },
            cancelTrip: { _, _, _, key in
                keys.append(key)
                throw APIClientError.http(statusCode: 503)
            },
            idempotencyKey: { generatedKeys.removeFirst() }
        )
        await sut.loadTrip(id: "trip-1")

        await sut.cancelTrip(id: "trip-1")
        await sut.cancelTrip(id: "trip-1")

        XCTAssertEqual(keys, ["cancel-1", "cancel-1"])
    }

    func testMigrationTargetChangedRotatesIdempotencyKeyForNewTarget() async {
        let initial = PersonalTripTestFixtures.detail(track: [], routeVersionStatus: PersonalTripTestFixtures.newerStatus)
        let changedStatus = PersonalTripRouteVersionStatus(
            tripID: "trip-1",
            tripRevision: "revision-1",
            adoptedVersion: PersonalTripTestFixtures.newerStatus.adoptedVersion,
            currentPublicVersion: PersonalTripRouteVersionReference(routeVersionID: "route-version-3", versionLabel: "v3"),
            versionRelationship: .newerPublicVersionAvailable,
            migrationEligible: true,
            difference: nil
        )
        var statusCalls = 0
        var keys: [String] = []
        var targets: [String] = []
        var generatedKeys = ["migration-1", "migration-2"]
        let sut = TripDetailViewModel(
            loadDetail: { _ in initial },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in PersonalTripTestFixtures.weather },
            loadRouteVersionStatus: { _ in
                defer { statusCalls += 1 }
                return statusCalls == 0 ? PersonalTripTestFixtures.newerStatus : changedStatus
            },
            cancelTrip: { _, _, _, _ in initial },
            migrateTrip: { _, _, target, key in
                targets.append(target)
                keys.append(key)
                if targets.count == 1 {
                    throw APIClientError.api(
                        code: "migration_target_changed",
                        message: "目标版本已变化",
                        retryable: false,
                        details: APIErrorDetails(
                            requestedTargetRouteVersionId: "route-version-2",
                            currentPublicRouteVersionId: "route-version-3"
                        )
                    )
                }
                return initial
            },
            idempotencyKey: { generatedKeys.removeFirst() }
        )
        await sut.loadTrip(id: "trip-1")

        await sut.migrateTrip(id: "trip-1")
        await sut.migrateTrip(id: "trip-1")

        XCTAssertEqual(targets, ["route-version-2", "route-version-3"])
        XCTAssertEqual(keys, ["migration-1", "migration-2"])
    }

    func testMigrationUsesLatestStatusTargetAndReplacesEntireProjection() async {
        let initial = PersonalTripTestFixtures.detail(
            track: [],
            routeVersionStatus: PersonalTripTestFixtures.newerStatus
        )
        let migrated = PersonalTripTestFixtures.detail(
            revision: "revision-2",
            status: .planned,
            adoptedRouteVersionID: "route-version-2",
            track: [PublicRouteGeoPosition(latitude: 30.0, longitude: 101.0, referenceSystem: "WGS84")]
        )
        var receivedTarget: String?
        var receivedRevision: String?
        let sut = TripDetailViewModel(
            loadDetail: { _ in initial },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in PersonalTripTestFixtures.weather },
            loadRouteVersionStatus: { _ in PersonalTripTestFixtures.newerStatus },
            cancelTrip: { _, _, _, _ in XCTFail("cancel must not run"); return initial },
            migrateTrip: { _, revision, target, _ in
                receivedRevision = revision
                receivedTarget = target
                return migrated
            },
            idempotencyKey: { "migration-key" }
        )
        await sut.loadTrip(id: "trip-1")

        await sut.refreshRouteVersionStatus(id: "trip-1")
        await sut.migrateTrip(id: "trip-1")

        XCTAssertEqual(receivedRevision, "revision-1")
        XCTAssertEqual(receivedTarget, "route-version-2")
        XCTAssertEqual(sut.trip, migrated)
        XCTAssertEqual(sut.days?.revision, "revision-2")
        XCTAssertEqual(sut.weather?.revision, "revision-2")
        XCTAssertEqual(sut.mapCoordinates.count, 1)
    }

    func testActionPolicyAllowsOnlyPlannedEligibleOperations() {
        XCTAssertEqual(
            TripDetailActionPolicy(status: .planned, migrationEligible: true),
            .init(canCancel: true, canMigrate: true, isReadOnly: false)
        )
        XCTAssertEqual(
            TripDetailActionPolicy(status: .planned, migrationEligible: false),
            .init(canCancel: true, canMigrate: false, isReadOnly: false)
        )
        XCTAssertEqual(
            TripDetailActionPolicy(status: .completed, migrationEligible: true),
            .init(canCancel: false, canMigrate: false, isReadOnly: true)
        )
    }

    func testDetailPresentationUsesApprovedBlockOrderAndOnlyRealNotices() {
        let detail = PersonalTripTestFixtures.detail(
            track: [],
            importantNotices: [
                PersonalTripImportantNotice(
                    sequence: 1,
                    type: "weather",
                    content: QualifiedString(value: "午后降雨", confidence: nil)
                ),
                PersonalTripImportantNotice(
                    sequence: 2,
                    type: "equipment",
                    content: QualifiedString(value: "核对冰爪", confidence: nil)
                ),
            ]
        )
        let presentation = TripDetailPresentation(
            detail: detail,
            days: PersonalTripTestFixtures.populatedDays,
            weather: PersonalTripTestFixtures.populatedWeather,
            routeVersionStatus: detail.routeVersionStatus
        )

        XCTAssertEqual(
            presentation.blocks,
            [.identity, .days, .route, .weather, .equipment, .routeVersion, .notices]
        )
        XCTAssertEqual(presentation.notices.map(\.content.value), ["午后降雨", "核对冰爪"])
        XCTAssertTrue(presentation.showsPageLevelCancel)
    }

    func testDetailPresentationOmitsNoticesAndCancelForCompletedTrip() {
        let detail = PersonalTripTestFixtures.detail(
            status: .completed,
            track: [],
            importantNotices: []
        )
        let presentation = TripDetailPresentation(
            detail: detail,
            days: PersonalTripTestFixtures.days,
            weather: PersonalTripTestFixtures.weather,
            routeVersionStatus: detail.routeVersionStatus
        )

        XCTAssertEqual(
            presentation.blocks,
            [.identity, .days, .route, .weather, .equipment, .routeVersion]
        )
        XCTAssertFalse(presentation.showsPageLevelCancel)
    }

    func testTripDetailKeepsCancelOutsideScrollAndMigrationInsideVersionSection() throws {
        let source = try productionSource(at: "Features/Trips/TripDetailView.swift")
        let scrollStart = try XCTUnwrap(source.range(of: "ScrollView {"))
        let scrollEnd = try XCTUnwrap(source.range(
            of: ".refreshable { await viewModel.loadTrip(id: tripID) }",
            range: scrollStart.upperBound..<source.endIndex
        ))
        let cancel = try XCTUnwrap(source.range(of: "private var pageLevelCancelAction"))
        let migration = try XCTUnwrap(source.range(of: "Button(\"整体迁移到当前公开新版\")"))
        let versionSection = try XCTUnwrap(source.range(of: "private func routeVersionSection"))

        XCTAssertGreaterThan(cancel.lowerBound, scrollEnd.upperBound)
        XCTAssertGreaterThan(migration.lowerBound, versionSection.lowerBound)
        XCTAssertFalse(source.contains("title: \"关联路线\""))
        XCTAssertFalse(source.contains("title: \"本次准备\""))
        XCTAssertFalse(source.contains("title: \"行程操作\""))
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

@MainActor
final class CreateTripViewModelTests: XCTestCase {
    func testSelectionRequiredPreservesInputAndUsesSelectionOnContinuation() async {
        var requests: [PersonalTripCreateRequest] = []
        var responses: [PersonalTripGenerationResult] = [
            .transportSelectionRequired(PersonalTripTestFixtures.transportSelection),
            .tripCreated(PersonalTripTestFixtures.detail(track: [])),
        ]
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in PersonalTripTestFixtures.generationContext },
            createTrip: { request, _ in
                requests.append(request)
                return responses.removeFirst()
            },
            idempotencyKey: { "request-\(requests.count + 1)" }
        )
        await sut.load()
        sut.departureCity = "成都"
        sut.startDate = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 8, day: 25)
        )!
        sut.selectedEquipmentListID = "equipment-list-1"

        await sut.submit()

        XCTAssertEqual(sut.departureCity, "成都")
        XCTAssertEqual(sut.selectedEquipmentListID, "equipment-list-1")
        XCTAssertEqual(sut.transportSelection?.selectionID, "selection-1")

        sut.selectedTransportOptionID = "option-2"
        await sut.submit()

        XCTAssertEqual(requests.count, 2)
        XCTAssertNil(requests[0].transportSelection)
        XCTAssertEqual(requests[1].transportSelection?.selectionID, "selection-1")
        XCTAssertEqual(requests[1].transportSelection?.transportOptionID, "option-2")
        XCTAssertEqual(sut.createdTripID, "trip-1")
    }

    func testCreateTripRouteSummaryContainsOnlySelectedRouteFacts() {
        let presentation = CreateTripRouteSummaryPresentation(
            route: PersonalTripTestFixtures.generationContext.route
        )

        XCTAssertEqual(presentation.title, "贡嘎环线")
        XCTAssertEqual(
            presentation.facts,
            ["v1", "多日路线", "四川甘孜", "中等", "老榆林 → 草科", "42.5 km", "48 小时"]
        )
    }

    func testTripCreatedOutcomeExposesCreatedTripIdentity() async {
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in PersonalTripTestFixtures.generationContext },
            createTrip: { _, _ in .tripCreated(PersonalTripTestFixtures.detail(track: [])) },
            idempotencyKey: { "request-1" }
        )
        await sut.load()
        sut.departureCity = "成都"
        sut.startDate = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 8, day: 25)
        )!

        await sut.submit()

        XCTAssertEqual(sut.createdTripID, "trip-1")
        XCTAssertNil(sut.transportSelection)
    }

    func testReturningFromPersonalEquipmentRefreshesContextAndPreservesValidInputs() async {
        var contexts = [
            PersonalTripTestFixtures.generationContext,
            PersonalTripTestFixtures.generationContext,
        ]
        var loadCount = 0
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in
                loadCount += 1
                return contexts.removeFirst()
            },
            createTrip: { _, _ in .tripCreated(PersonalTripTestFixtures.detail(track: [])) }
        )
        let selectedDate = Calendar.business.date(
            from: DateComponents(year: 2026, month: 9, day: 3)
        )!

        await sut.handleAppearance()
        sut.departureCity = "上海"
        sut.startDate = selectedDate
        sut.selectedEquipmentListID = "equipment-list-1"
        sut.prepareForPersonalEquipment()
        await sut.handleAppearance()

        XCTAssertEqual(loadCount, 2)
        XCTAssertEqual(sut.departureCity, "上海")
        XCTAssertEqual(sut.startDate, selectedDate)
        XCTAssertEqual(sut.selectedEquipmentListID, "equipment-list-1")
    }

    func testReturningFromPersonalEquipmentClearsDeletedSelectedList() async {
        let updatedContext = PersonalTripGenerationContext(
            route: PersonalTripTestFixtures.generationContext.route,
            personalEquipmentSummary: PersonalTripTestFixtures.generationContext.personalEquipmentSummary,
            equipmentLists: []
        )
        var contexts = [PersonalTripTestFixtures.generationContext, updatedContext]
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in contexts.removeFirst() },
            createTrip: { _, _ in .tripCreated(PersonalTripTestFixtures.detail(track: [])) }
        )

        await sut.handleAppearance()
        sut.departureCity = "上海"
        sut.selectedEquipmentListID = "equipment-list-1"
        sut.prepareForPersonalEquipment()
        await sut.handleAppearance()

        XCTAssertEqual(sut.departureCity, "上海")
        XCTAssertNil(sut.selectedEquipmentListID)
    }

    func testCreateTripViewRefreshesOnReturnWithoutDuplicateInitialTask() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let sourceURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Features/Trips/CreateTripView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(".onAppear { Task { await viewModel.handleAppearance() } }"))
        XCTAssertFalse(source.contains(".task { await viewModel.load() }"))
    }
}

@MainActor
final class TripDayWeatherViewModelTests: XCTestCase {
    func testTripDayPresentationPreservesServerActionAndPointOrder() {
        let day = PersonalTripTestFixtures.populatedDays.days[0]

        let presentation = TripDayPresentation(day: day)

        XCTAssertEqual(presentation.actionSequence, day.actions.map(\.sequence))
        XCTAssertEqual(presentation.pointSequence, day.points?.map(\.sequence))
        XCTAssertEqual(presentation.primaryStage, day.primaryStage)
        XCTAssertEqual(presentation.dayLabel, "D1")
    }

    func testTripDayFocusStartsAtRequestedDayAndClampsWhenDaysShrink() {
        let days = PersonalTripTestFixtures.twoDays.days

        XCTAssertEqual(TripDayFocusPolicy.initialIndex(days: days, initialDayID: "day-2"), 1)
        XCTAssertEqual(TripDayFocusPolicy.initialIndex(days: days, initialDayID: "missing-day"), 0)
        XCTAssertEqual(TripDayFocusPolicy.clampedIndex(5, dayCount: days.count), 1)
        XCTAssertEqual(TripDayFocusPolicy.clampedIndex(-3, dayCount: days.count), 0)
        XCTAssertEqual(TripDayFocusPolicy.clampedIndex(0, dayCount: 0), 0)
    }

    func testTripDayPresentationSeparatesDailyRouteTransportAndCategorizedPoints() {
        let day = PersonalTripTestFixtures.populatedDays.days[0]

        let presentation = TripDayPresentation(day: day)

        XCTAssertEqual(presentation.dailyRouteActions.map(\.sequence), [2])
        XCTAssertTrue(presentation.dailyRouteActions.allSatisfy { $0.actionType == "hike" })
        XCTAssertEqual(presentation.transportActions.map(\.sequence), [1])
        XCTAssertTrue(presentation.transportActions.allSatisfy { $0.actionType != "hike" })
        XCTAssertEqual(presentation.groupedPoints.map(\.category), ["campsite", "water_source"])
        XCTAssertEqual(presentation.groupedPoints.map(\.title), ["营地", "水源"])
        XCTAssertEqual(presentation.groupedPoints.first?.points.map(\.sequence), [3])
        XCTAssertTrue(presentation.hasDayContent)
    }

    func testTripDayPageUsesFullScreenPagingWithoutDayJumpControls() throws {
        let source = try productionSource(at: "Features/Trips/TripDayWeatherViews.swift")

        XCTAssertFalse(source.contains("\"前一天\""))
        XCTAssertFalse(source.contains("\"后一天\""))
        XCTAssertFalse(source.contains("TripDaySelection"))
        XCTAssertTrue(source.contains("tabViewStyle(.page"))
        XCTAssertTrue(source.contains("scrollBoundaryHandoff"))
        XCTAssertTrue(source.contains("每日路程"))
    }

    func testTripWeatherPresentationIncludesOverviewImpactsDailyWeatherAndFreshness() {
        let presentation = TripWeatherPresentation(weather: PersonalTripTestFixtures.populatedWeather)

        XCTAssertEqual(presentation.overview, "整体多云")
        XCTAssertEqual(presentation.importantImpacts, ["午后降雨"])
        XCTAssertEqual(presentation.days.map(\.dayNumber), [1])
        XCTAssertEqual(presentation.sources, ["气象服务"])
        XCTAssertEqual(presentation.updatedTimes, ["2026-08-24T08:00:00+08:00"])
    }

    func testTripDayRejectsProjectionFromDifferentCurrentRevision() async {
        let sut = TripDayViewModel(
            tripID: "trip-1",
            initialDayID: "day-1",
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadCurrentRevision: { _ in "revision-2" }
        )

        await sut.load()

        XCTAssertNil(sut.result)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testTripWeatherAcceptsProjectionMatchingCurrentRevision() async {
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in PersonalTripTestFixtures.weather },
            loadCurrentRevision: { _ in "revision-1" }
        )

        await sut.load()

        XCTAssertEqual(sut.weather, PersonalTripTestFixtures.weather)
        XCTAssertNil(sut.errorMessage)
    }

    func testBusinessCalendarUsesShanghaiWhenUTCDateIsPreviousDay() {
        let utcDate = ISO8601DateFormatter().date(from: "2026-08-24T16:30:00Z")!

        XCTAssertEqual(BusinessCalendar.timeZone.identifier, "Asia/Shanghai")
        XCTAssertEqual(
            LocalDate(date: utcDate, calendar: .business),
            LocalDate(year: 2026, month: 8, day: 25)
        )
        XCTAssertEqual(
            BusinessCalendar.calendar.dateComponents(
                [.year, .month, .day, .hour],
                from: BusinessCalendar.startOfToday(now: utcDate)
            ),
            DateComponents(year: 2026, month: 8, day: 25, hour: 0)
        )
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

enum PersonalTripTestFixtures {
    static func summary(
        id: String = "trip-1",
        status: PersonalTripStatus = .planned
    ) -> PersonalTripSummary {
        PersonalTripSummary(
            tripID: id,
            revision: "revision-1",
            name: "贡嘎行程",
            status: status,
            routeReference: PersonalTripRouteReference(
                routeID: "route-1",
                adoptedRouteVersionID: "route-version-1"
            ),
            routeName: "贡嘎环线",
            routeType: "multi_day",
            start: PublicRoutePlace(name: "老榆林"),
            end: PublicRoutePlace(name: "草科"),
            estimatedDuration: RouteDuration(seconds: 172_800),
            startDate: LocalDate(year: 2026, month: 8, day: 25),
            endDate: LocalDate(year: 2026, month: 8, day: 27),
            totalDayCount: 3,
            hikingDayCount: 2,
            versionLabel: "v1",
            cover: nil,
            direction: "环线",
            distance: RouteDistance(meters: 42_500),
            ascent: RouteElevationGain(meters: 2_300)
        )
    }

    static func detail(
        revision: String = "revision-1",
        status: PersonalTripStatus = .planned,
        adoptedRouteVersionID: String = "route-version-1",
        track: [PublicRouteGeoPosition],
        routeVersionStatus: PersonalTripRouteVersionStatus? = nil,
        importantNotices: [PersonalTripImportantNotice]? = nil
    ) -> PersonalTripDetail {
        PersonalTripDetail(
            revision: revision,
            trip: PersonalTripProjection(
                identity: "trip-1",
                name: "贡嘎行程",
                firstGeneratedAt: Date(timeIntervalSince1970: 1_785_578_400),
                status: status,
                departureCity: "成都",
                startDate: LocalDate(year: 2026, month: 8, day: 25),
                endDate: LocalDate(year: 2026, month: 8, day: 27),
                totalDayCount: 3,
                hikingDayCount: 2,
                frozenRouteBasis: FrozenRouteBasis(
                    routeName: "贡嘎环线",
                    routeType: "multi_day",
                    region: "四川甘孜",
                    start: PublicRoutePlace(name: "老榆林"),
                    end: PublicRoutePlace(name: "草科"),
                    estimatedDuration: RouteDuration(seconds: 172_800),
                    mainTrackPath: track,
                    versionLabel: "v1",
                    cover: nil,
                    direction: "环线",
                    distance: RouteDistance(meters: 42_500),
                    ascent: RouteElevationGain(meters: 2_300),
                    descent: RouteElevationLoss(meters: 2_200),
                    maxElevation: RouteElevation(meters: 4_700)
                ),
                weatherOverview: QualifiedString(value: "多云，午后可能有雨", confidence: nil),
                importantNotices: importantNotices
            ),
            routeReference: PersonalTripRouteReference(
                routeID: "route-1",
                adoptedRouteVersionID: adoptedRouteVersionID
            ),
            days: [],
            equipmentSnapshot: PersonalTripEquipmentSnapshotReference(
                snapshotID: "snapshot-1",
                summary: PersonalTripEquipmentSummary(
                    itemCount: 0,
                    knownTotalWeight: EquipmentWeight(grams: 0),
                    missingWeightItemCount: 0,
                    ownedItemCount: 0,
                    unconfirmedOwnedItemCount: 0
                )
            ),
            routeVersionStatus: routeVersionStatus ?? PersonalTripRouteVersionStatus(
                tripID: "trip-1",
                tripRevision: revision,
                adoptedVersion: PersonalTripRouteVersionReference(
                    routeVersionID: adoptedRouteVersionID,
                    versionLabel: "v1"
                ),
                currentPublicVersion: PersonalTripRouteVersionReference(
                    routeVersionID: adoptedRouteVersionID,
                    versionLabel: "v1"
                ),
                versionRelationship: .current,
                migrationEligible: false,
                difference: nil
            )
        )
    }

    static let newerStatus = PersonalTripRouteVersionStatus(
        tripID: "trip-1",
        tripRevision: "revision-1",
        adoptedVersion: PersonalTripRouteVersionReference(
            routeVersionID: "route-version-1",
            versionLabel: "v1"
        ),
        currentPublicVersion: PersonalTripRouteVersionReference(
            routeVersionID: "route-version-2",
            versionLabel: "v2"
        ),
        versionRelationship: .newerPublicVersionAvailable,
        migrationEligible: true,
        difference: PersonalTripRouteVersionDifference(
            minimumComparisonStatus: .partial,
            differences: [],
            unavailableCategories: [.planningSupportAndSafety],
            otherRelevantChangeStatus: .none,
            otherRelevantChanges: []
        )
    )

    static let days = PersonalTripDays(
        tripID: "trip-1",
        revision: "revision-1",
        startDate: LocalDate(year: 2026, month: 8, day: 25),
        endDate: LocalDate(year: 2026, month: 8, day: 27),
        totalDayCount: 3,
        hikingDayCount: 2,
        days: []
    )

    static let weather = PersonalTripWeather(
        tripID: "trip-1",
        revision: "revision-1",
        routeName: "贡嘎环线",
        startDate: LocalDate(year: 2026, month: 8, day: 25),
        endDate: LocalDate(year: 2026, month: 8, day: 27),
        days: [],
        weatherOverview: QualifiedString(value: "多云", confidence: nil)
    )

    static let populatedWeather = PersonalTripWeather(
        tripID: "trip-1",
        revision: "revision-1",
        routeName: "贡嘎环线",
        startDate: LocalDate(year: 2026, month: 8, day: 25),
        endDate: LocalDate(year: 2026, month: 8, day: 25),
        days: [PersonalTripWeatherDay(
            tripDayID: "day-1",
            dayNumber: 1,
            date: LocalDate(year: 2026, month: 8, day: 25),
            primaryStage: "徒步日 1",
            hikingDayNumber: 1,
            weather: populatedDayWeather
        )],
        weatherOverview: QualifiedString(value: "整体多云", confidence: nil)
    )

    static let populatedDayWeather = PersonalTripDayWeather(
        condition: QualifiedJSON(value: .string("多云"), confidence: nil),
        temperatureRange: QualifiedJSON(value: .string("8–16°C"), confidence: nil),
        precipitation: QualifiedJSON(value: .string("午后降雨"), confidence: InformationConfidence(status: "pending_verification", category: nil)),
        wind: QualifiedJSON(value: .string("微风"), confidence: InformationConfidence(status: "verified", category: nil)),
        placeContext: QualifiedJSON(value: .string("老榆林"), confidence: nil),
        routeSectionContext: QualifiedJSON(value: .string("日乌且垭口段"), confidence: nil),
        source: QualifiedString(value: "气象服务", confidence: InformationConfidence(status: "verified", category: nil)),
        updatedAt: QualifiedString(value: "2026-08-24T08:00:00+08:00", confidence: InformationConfidence(status: "verified", category: nil))
    )

    static let populatedDays = PersonalTripDays(
        tripID: "trip-1",
        revision: "revision-1",
        startDate: LocalDate(year: 2026, month: 8, day: 25),
        endDate: LocalDate(year: 2026, month: 8, day: 25),
        totalDayCount: 1,
        hikingDayCount: 1,
        days: [PersonalTripDay(
            identity: "day-1",
            dayNumber: 1,
            date: LocalDate(year: 2026, month: 8, day: 25),
            primaryStage: "徒步日 1",
            hikingDayNumber: 1,
            actions: [
                PersonalTripAction(
                    sequence: 2,
                    actionType: "hike",
                    origin: nil,
                    destination: nil,
                    mode: nil,
                    keyTimes: nil,
                    estimatedDuration: QualifiedDuration(value: RouteDuration(seconds: 18_000), confidence: nil),
                    transferNotes: nil,
                    routeSectionSnapshot: PersonalTripRouteSectionSnapshot(
                        start: PublicRoutePlace(name: "老榆林"),
                        end: PublicRoutePlace(name: "垭口"),
                        name: "日乌且垭口段",
                        path: nil
                    ),
                    start: QualifiedPlace(value: PublicRoutePlace(name: "老榆林"), confidence: nil),
                    end: QualifiedPlace(value: PublicRoutePlace(name: "垭口"), confidence: nil),
                    distance: QualifiedDistance(value: RouteDistance(meters: 12_000), confidence: nil),
                    ascent: QualifiedDistance(value: RouteDistance(meters: 900), confidence: nil)
                ),
                PersonalTripAction(
                    sequence: 1,
                    actionType: "long_distance_transport",
                    origin: QualifiedPlace(value: PublicRoutePlace(name: "成都"), confidence: nil),
                    destination: QualifiedPlace(value: PublicRoutePlace(name: "康定"), confidence: nil),
                    mode: QualifiedString(value: "大巴", confidence: nil),
                    keyTimes: QualifiedStringList(value: ["06:30"], confidence: nil),
                    estimatedDuration: QualifiedDuration(value: RouteDuration(seconds: 12_600), confidence: nil),
                    transferNotes: QualifiedStringList(value: ["康定换乘"], confidence: nil),
                    routeSectionSnapshot: nil,
                    start: nil,
                    end: nil,
                    distance: nil,
                    ascent: nil
                ),
            ],
            weather: populatedDayWeather,
            points: [
                PersonalTripPoint(
                    sequence: 8,
                    category: "water_source",
                    type: "溪流",
                    name: "补水点",
                    distance: nil,
                    location: nil,
                    details: QualifiedString(value: "需过滤", confidence: nil),
                    isAlternative: nil
                ),
                PersonalTripPoint(
                    sequence: 3,
                    category: "campsite",
                    type: "营地",
                    name: "日乌且营地",
                    distance: nil,
                    location: nil,
                    details: QualifiedString(value: "避风处", confidence: nil),
                    isAlternative: false
                ),
            ]
        )]
    )

    static let twoDays = PersonalTripDays(
        tripID: "trip-1",
        revision: "revision-1",
        startDate: LocalDate(year: 2026, month: 8, day: 25),
        endDate: LocalDate(year: 2026, month: 8, day: 26),
        totalDayCount: 2,
        hikingDayCount: 2,
        days: [
            PersonalTripDay(
                identity: "day-1",
                dayNumber: 1,
                date: LocalDate(year: 2026, month: 8, day: 25),
                primaryStage: "徒步日 1",
                hikingDayNumber: 1,
                actions: [],
                weather: populatedDayWeather,
                points: nil
            ),
            PersonalTripDay(
                identity: "day-2",
                dayNumber: 2,
                date: LocalDate(year: 2026, month: 8, day: 26),
                primaryStage: "徒步日 2",
                hikingDayNumber: 2,
                actions: [],
                weather: populatedDayWeather,
                points: nil
            ),
        ]
    )

    static let generationContext = PersonalTripGenerationContext(
        route: PersonalTripGenerationRoute(
            routeID: "route-1",
            currentPublicRouteVersionID: "route-version-1",
            routeType: "multi_day",
            generationEligibility: RouteGenerationEligibility(eligible: true),
            versionLabel: "v1",
            name: "贡嘎环线",
            region: "四川甘孜",
            start: PublicRoutePlace(name: "老榆林"),
            end: PublicRoutePlace(name: "草科"),
            difficulty: "中等",
            distance: RouteDistance(meters: 42_500),
            estimatedDuration: RouteDuration(seconds: 172_800)
        ),
        personalEquipmentSummary: PersonalEquipmentSummary(
            equipmentItemCount: 1,
            equipmentListCount: 1,
            knownTotalWeight: EquipmentWeight(grams: 1_200),
            missingWeightItemCount: 0
        ),
        equipmentLists: [
            PersonalTripGenerationEquipmentListOption(
                equipmentListID: "equipment-list-1",
                name: "轻装",
                summary: EquipmentListSummary(
                    itemCount: 1,
                    knownTotalWeight: EquipmentWeight(grams: 1_200),
                    missingWeightItemCount: 0
                )
            )
        ]
    )

    static let transportSelection = PersonalTripTransportSelection(
        selectionID: "selection-1",
        options: [
            PersonalTripTransportOption(
                transportOptionID: "option-1",
                transferCount: QualifiedInteger(value: 1, confidence: nil),
                estimatedArrivalAt: QualifiedString(value: "08:00", confidence: nil),
                estimatedDuration: QualifiedDuration(
                    value: RouteDuration(seconds: 7_200),
                    confidence: nil
                ),
                verificationItems: ["确认班次"]
            ),
            PersonalTripTransportOption(
                transportOptionID: "option-2",
                transferCount: QualifiedInteger(value: 0, confidence: nil),
                estimatedArrivalAt: QualifiedString(value: "09:00", confidence: nil),
                estimatedDuration: QualifiedDuration(
                    value: RouteDuration(seconds: 9_000),
                    confidence: nil
                ),
                verificationItems: []
            ),
        ]
    )
}
