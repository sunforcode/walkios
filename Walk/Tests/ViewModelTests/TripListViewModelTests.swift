import XCTest
import WalkData
import WalkDesignSystem
@testable import Walk

@MainActor
final class TripListViewModelTests: XCTestCase {
    func testDuplicateLoadIsIgnoredAndCancelledLateResultCannotReplaceRetry() async {
        let gate = TripRequestGate<PersonalTripCollection>()
        var calls = 0
        let sut = TripListViewModel(loadTrips: {
            calls += 1
            if calls == 1 { return await gate.wait() }
            return PersonalTripCollection(currentTrips: [PersonalTripTestFixtures.summary(id: "new")], historicalTrips: [])
        })
        let task = Task { await sut.loadTrips() }
        await gate.waitUntilStarted()
        await sut.loadTrips()
        XCTAssertEqual(calls, 1)
        task.cancel()
        await sut.retry()
        gate.resume(PersonalTripCollection(currentTrips: [PersonalTripTestFixtures.summary(id: "old")], historicalTrips: []))
        await task.value
        XCTAssertEqual(sut.currentTrips.map(\.tripID), ["new"])
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testTransportCancellationIsNotAListFailure() async {
        let sut = TripListViewModel(loadTrips: { throw APIClientError.transport(.cancelled) })
        await sut.loadTrips()
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

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
        XCTAssertEqual(sut.currentTrips.map(\.status), [.inProgress, .planned])
        XCTAssertEqual(sut.historicalTrips.map(\.status), [.cancelled, .completed])
    }

    func testLoadFailureDoesNotInventTrips() async {
        let sut = TripListViewModel(loadTrips: { throw APIClientError.invalidResponse })

        await sut.loadTrips()

        XCTAssertTrue(sut.currentTrips.isEmpty)
        XCTAssertTrue(sut.historicalTrips.isEmpty)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testTripListPageUsesProductionTripListRowWithoutLegacyWrapper() throws {
        let pageSource = try productionSource(at: "Features/Trips/TripListView.swift")

        XCTAssertTrue(pageSource.contains("TripBusinessComponents.TripListRow("))
        XCTAssertFalse(pageSource.contains("TripRowView(trip:"))
        // W4：遗留包装文件已删除。
        XCTAssertThrowsError(try productionSource(at: "Features/Trips/TripRowView.swift"))
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
final class PersonalTripDetailViewModelTests: XCTestCase {
    func testLateWeatherLoadCannotOverwriteSuccessfulMutation() async {
        let initial = PersonalTripTestFixtures.detail(track: [])
        let replacement = PersonalTripTestFixtures.detail(revision: "revision-2", status: .cancelled, track: [])
        let gate = TripRequestGate<PersonalTripWeather>()
        var weatherCalls = 0
        let sut = TripDetailViewModel(
            loadDetail: { _ in initial },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in
                weatherCalls += 1
                if weatherCalls == 2 { return await gate.wait() }
                return PersonalTripTestFixtures.populatedWeatherProjection
            },
            cancelTrip: { _, _, _, _ in replacement }
        )
        await sut.loadTrip(id: "trip-1")
        let task = Task { await sut.loadTrip(id: "trip-1") }
        await gate.waitUntilStarted()
        await sut.cancelTrip(id: "trip-1")
        gate.resume(PersonalTripTestFixtures.populatedWeatherProjection)
        await task.value
        XCTAssertEqual(sut.trip, replacement)
        XCTAssertEqual(sut.days?.revision, "revision-2")
        XCTAssertTrue(sut.isWeatherUnavailable)
        XCTAssertNil(sut.errorMessage)
    }

    func testCancelledMutationKeepsLockUntilResponseAndReusesIntentOnRetry() async {
        let initial = PersonalTripTestFixtures.detail(track: [])
        let replacement = PersonalTripTestFixtures.detail(revision: "revision-2", status: .cancelled, track: [])
        let gate = TripRequestGate<PersonalTripDetail>()
        var keys: [String] = []
        var generatedKeys = 0
        var loads = 0
        let sut = TripDetailViewModel(
            loadDetail: { _ in loads += 1; return initial },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection },
            cancelTrip: { _, _, _, key in
                keys.append(key)
                if keys.count == 1 { return await gate.wait() }
                return replacement
            },
            idempotencyKey: { generatedKeys += 1; return "cancel-\(generatedKeys)" }
        )
        await sut.loadTrip(id: "trip-1")
        let task = Task { await sut.cancelTrip(id: "trip-1") }
        await gate.waitUntilStarted()
        task.cancel()
        await sut.cancelTrip(id: "trip-1")
        await sut.migrateTrip(id: "trip-1")
        await sut.loadTrip(id: "trip-1")
        XCTAssertTrue(sut.isMutating)
        XCTAssertEqual(keys.count, 1)
        XCTAssertEqual(loads, 1)
        gate.resume(replacement)
        await task.value
        XCTAssertEqual(sut.trip, initial)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isMutating)
        await sut.cancelTrip(id: "trip-1")
        XCTAssertEqual(keys, ["cancel-1", "cancel-1"])
        XCTAssertEqual(sut.trip, replacement)
    }

    func testCancelledDetailReadCanRetryBeforeLateReadFinishes() async {
        let gate = TripRequestGate<PersonalTripDetail>()
        var calls = 0
        let current = PersonalTripTestFixtures.detail(track: [])
        let sut = TripDetailViewModel(
            loadDetail: { _ in
                calls += 1
                if calls == 1 { return await gate.wait() }
                return current
            },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection }
        )
        let first = Task { await sut.loadTrip(id: "trip-1") }
        await gate.waitUntilStarted()
        await sut.loadTrip(id: "trip-1")
        XCTAssertEqual(calls, 1)
        first.cancel()
        await sut.loadTrip(id: "trip-1")
        gate.resume(PersonalTripTestFixtures.detail(revision: "old", track: []))
        await first.value
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(sut.trip, current)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testLateVersionStatusCannotOverwriteMutationProjection() async {
        let initial = PersonalTripTestFixtures.detail(track: [])
        let replacement = PersonalTripTestFixtures.detail(revision: "revision-2", status: .cancelled, track: [])
        let gate = TripRequestGate<PersonalTripRouteVersionStatus>()
        let sut = TripDetailViewModel(
            loadDetail: { _ in initial },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection },
            loadRouteVersionStatus: { _ in await gate.wait() },
            cancelTrip: { _, _, _, _ in replacement }
        )
        await sut.loadTrip(id: "trip-1")
        let status = Task { await sut.refreshRouteVersionStatus(id: "trip-1") }
        await gate.waitUntilStarted()
        await sut.cancelTrip(id: "trip-1")
        gate.resume(initial.routeVersionStatus)
        await status.value
        XCTAssertEqual(sut.routeVersionStatus, replacement.routeVersionStatus)
        XCTAssertNil(sut.errorMessage)
    }

    func testCancelledWeatherDoesNotPublishDetailOrUnavailable() async {
        let sut = TripDetailViewModel(
            loadDetail: { _ in PersonalTripTestFixtures.detail(track: []) },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in throw APIClientError.transport(.cancelled) }
        )
        await sut.loadTrip(id: "trip-1")
        XCTAssertNil(sut.trip)
        XCTAssertFalse(sut.isWeatherUnavailable)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

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
                return PersonalTripTestFixtures.populatedWeatherProjection
            }
        )

        await sut.loadTrip(id: "trip-1")

        XCTAssertEqual(calls.sorted(), ["days:trip-1", "detail:trip-1", "weather:trip-1"])
        XCTAssertEqual(sut.trip?.trip.identity, "trip-1")
    }

    func testLoadKeepsDetailAndDaysWhenWeatherProjectionIsTemporarilyUnavailable() async {
        let detail = PersonalTripTestFixtures.detail(track: [])
        let sut = TripDetailViewModel(
            loadDetail: { _ in detail },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in
                throw APIClientError.api(
                    code: "trip_weather_projection_unavailable",
                    message: "行程天气关联尚未形成完整投影",
                    retryable: true
                )
            }
        )

        await sut.loadTrip(id: "trip-1")

        XCTAssertEqual(sut.trip, detail)
        XCTAssertEqual(sut.days, PersonalTripTestFixtures.days)
        XCTAssertNil(sut.weather)
        XCTAssertTrue(sut.isWeatherUnavailable)
        XCTAssertNil(sut.errorMessage)
        // app-flow（ui-component-restructure）：天气结果可用时天气入口必须呈现，
        // 不因天气关联投影的装配方式被静默省略；冻结逐日样本仍然可用。
        XCTAssertTrue(
            TripDetailPresentation(
                detail: detail,
                days: PersonalTripTestFixtures.days,
                routeVersionStatus: detail.routeVersionStatus
            ).blocks.contains(.weather)
        )
    }

    func testLoadDegradesWeatherWhenProjectionDecodeFailsInsteadOfFailingDetailPage() async {
        let detail = PersonalTripTestFixtures.detail(track: [])
        let sut = TripDetailViewModel(
            loadDetail: { _ in detail },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in
                throw DecodingError.typeMismatch(
                    String.self,
                    .init(codingPath: [], debugDescription: "production contract mismatch")
                )
            }
        )

        await sut.loadTrip(id: "trip-1")

        XCTAssertEqual(sut.trip, detail)
        XCTAssertEqual(sut.days, PersonalTripTestFixtures.days)
        XCTAssertNil(sut.weather)
        XCTAssertTrue(sut.isWeatherUnavailable)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadDegradesWeatherWhenProjectionIsInvalidInsteadOfFailingDetailPage() async {
        let detail = PersonalTripTestFixtures.detail(track: [])
        let sut = TripDetailViewModel(
            loadDetail: { _ in detail },
            loadDays: { _ in PersonalTripTestFixtures.days },
            loadWeather: { _ in throw APIClientError.invalidResponse }
        )

        await sut.loadTrip(id: "trip-1")

        XCTAssertEqual(sut.trip, detail)
        XCTAssertEqual(sut.days, PersonalTripTestFixtures.days)
        XCTAssertNil(sut.weather)
        XCTAssertTrue(sut.isWeatherUnavailable)
        XCTAssertNil(sut.errorMessage)
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
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection }
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
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection },
            loadRouteVersionStatus: { _ in detail.routeVersionStatus },
            cancelTrip: { _, _, _, _ in throw APIClientError.invalidResponse },
            migrateTrip: { _, _, _, _ in throw APIClientError.invalidResponse },
            idempotencyKey: { "mutation-key" }
        )
        await sut.loadTrip(id: "trip-1")

        await sut.cancelTrip(id: "trip-1")

        XCTAssertEqual(sut.trip, detail)
        XCTAssertEqual(sut.days, PersonalTripTestFixtures.days)
        XCTAssertEqual(sut.weather, PersonalTripTestFixtures.populatedWeatherProjection)
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
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection },
            loadRouteVersionStatus: { _ in initial.routeVersionStatus },
            cancelTrip: { _, _, _, key in
                keys.append(key)
                attempts += 1
                if attempts == 1 { throw APIClientError.transport(.connectionLost) }
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
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection },
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
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection },
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
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection },
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
        XCTAssertNil(sut.weather)
        XCTAssertTrue(sut.isWeatherUnavailable)
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
            routeVersionStatus: detail.routeVersionStatus
        )

        XCTAssertEqual(
            presentation.blocks,
            [.identity, .weather, .equipment, .days, .route, .notices]
        )
        XCTAssertEqual(TripDetailBlock.allCases, [.identity, .weather, .equipment, .days, .route, .notices])
        // personal-trip：每日行动按 sequence 表达的实际发生顺序组织；TripDayPresentation 按 sequence 升序提供。
        XCTAssertEqual(presentation.dayProjections[0].actions.map(\.id), ["1", "2"])
        XCTAssertEqual(presentation.dayProjections[0].points.map(\.id), ["3", "8"])
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
            routeVersionStatus: detail.routeVersionStatus
        )

        XCTAssertEqual(
            presentation.blocks,
            [.identity, .weather, .equipment, .days, .route]
        )
        XCTAssertFalse(presentation.showsPageLevelCancel)
    }

    func testDetailPresentationMapsSafeComponentFieldsWithoutInventingMissingFacts() throws {
        let detail = PersonalTripTestFixtures.detail(track: [], versionLabel: nil)
        let presentation = TripDetailPresentation(
            detail: detail,
            days: PersonalTripTestFixtures.populatedDays,
            routeVersionStatus: detail.routeVersionStatus
        )

        XCTAssertEqual(presentation.coverProjection.conditionTags.count, 3)
        XCTAssertFalse(presentation.coverProjection.coverAvailable)
        XCTAssertEqual(presentation.dayProjections[0].tripDayID, "day-1")
        // personal-trip：每日行动按 sequence 表达的实际发生顺序组织；TripDayPresentation 按 sequence 升序提供。
        XCTAssertEqual(presentation.dayProjections[0].actions.map(\.id), ["1", "2"])
        XCTAssertEqual(presentation.dayProjections[0].points.map(\.id), ["3", "8"])
        XCTAssertEqual(presentation.dayProjections[0].weather.condition.value, "多云")
        XCTAssertEqual(presentation.weatherSummaryProjection?.samples.map(\.id), ["day-1"])
        XCTAssertNil(presentation.weatherSummaryProjection?.notice)
        XCTAssertEqual(presentation.equipmentSummaryProjection.itemCount, 0)
        XCTAssertEqual(presentation.equipmentSummaryProjection.knownTotalWeight, "0 g")
        XCTAssertTrue(presentation.equipmentSummaryProjection.editable)
    }

    func testTripCoverProjectionCarriesExactlyOneRowOfConditionTags() {
        let projection = TripCoverHeaderProjection(
            name: "贡嘎行程",
            status: .planned,
            departureCity: "成都",
            startDate: "2026-08-25",
            endDate: "2026-08-27",
            totalDayCount: 3,
            hikingDayCount: 2,
            coverAvailable: false
        )

        // 封面只保留一行条件标签：出发城市、日期范围与天数，不展示版本依据。
        XCTAssertEqual(projection.conditionTags, ["成都出发", "2026-08-25–2026-08-27", "3 天 · 徒步 2 天"])
    }

    func testTripDetailPageUsesOnlySafeProductionComponentsAndKeepsBlockedRouteRegion() throws {
        let source = try productionSource(at: "Features/Trips/TripDetailView.swift")
        let cover = try productionSource(at: "Features/Trips/Components/TripCoverHeader.swift")

        XCTAssertTrue(source.contains("TripBusinessComponents.TripCoverHeader("))
        XCTAssertTrue(source.contains("Timeline("), "全程/每日摘要由同一时间线承载")
        XCTAssertTrue(source.contains("TripBusinessComponents.DailyWeatherSummaryRow("), "行程天气以每日摘要行呈现，明细归天气页")
        XCTAssertTrue(source.contains("weatherSummaryProjection == nil ? \"暂不可用\""))
        XCTAssertTrue(source.contains("TripBusinessComponents.TripEquipmentSummaryCard("))
        XCTAssertFalse(source.contains("private struct TripCoverHeader: View"))
        XCTAssertFalse(source.contains("private struct TripDaySummaryCard: View"))
        XCTAssertFalse(source.contains("private struct TripWeatherSummaryCard: View"))
        XCTAssertFalse(source.contains("private struct TripEquipmentSummaryCard: View"))
        XCTAssertFalse(source.contains("RouteMapView("), "冻结轨迹不得冒充行程封面")
        XCTAssertFalse(source.contains("adoptedRouteVersionID"), "封面不得回退显示不透明版本 ID")

        // DETAIL 的指标归场景，正文不再重复路线卡；公共路线导航仍由页面转发。
        let routeCard = try productionSource(at: "Features/Trips/Components/TripRouteSummaryCard.swift")
        XCTAssertTrue(source.contains("TripBusinessComponents.TripExpeditionScene("))
        XCTAssertFalse(source.contains("TripBusinessComponents.TripRouteMetricsSummary("))
        XCTAssertFalse(source.contains("TripBusinessComponents.TripRouteVersionCard("))
        XCTAssertTrue(routeCard.contains("TripBusinessComponents.TripRouteMetricsSummary("))
        XCTAssertFalse(routeCard.contains("生成依据"), "走向卡不再展示生成依据标签")

        // 封面条件标签不含版本依据。
        XCTAssertFalse(cover.contains("versionLabel"))
        XCTAssertFalse(cover.contains("生成依据"))
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
    func testSubmitEnforcesMissingContextCityEligibilityAndTransportChoice() async {
        var calls = 0
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in PersonalTripTestFixtures.generationContext },
            createTrip: { _, _ in
                calls += 1
                return .transportSelectionRequired(PersonalTripTestFixtures.transportSelection)
            }
        )
        await sut.submit()
        await sut.load()
        sut.updateDepartureCity("   ")
        await sut.submit()
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(sut.departureCityError, "请先填写城市，再生成个人行程。")
        sut.updateDepartureCity("成都")
        await sut.submit()
        await sut.submit()
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(sut.canSubmit)

        let blockedRoute = PersonalTripGenerationRoute(
            routeID: "route-1",
            currentPublicRouteVersionID: "route-version-1",
            routeType: "multi_day",
            generationEligibility: RouteGenerationEligibility(eligible: false, missingReasons: [.validMainTrack]),
            versionLabel: nil, name: nil, region: nil, start: nil, end: nil,
            difficulty: nil, distance: nil, estimatedDuration: nil
        )
        let blocked = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in PersonalTripGenerationContext(
                route: blockedRoute,
                personalEquipmentSummary: PersonalTripTestFixtures.generationContext.personalEquipmentSummary,
                equipmentLists: []
            ) },
            createTrip: { _, _ in calls += 1; return .tripCreated(PersonalTripTestFixtures.detail(track: [])) }
        )
        await blocked.load()
        blocked.updateDepartureCity("成都")
        await blocked.submit()
        XCTAssertFalse(blocked.canSubmit)
        XCTAssertEqual(calls, 1)
    }

    func testSubmitRejectsDuplicateAndLoadWhileSubmitting() async {
        let gate = TripRequestGate<PersonalTripGenerationResult>()
        var calls = 0
        var loads = 0
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in loads += 1; return PersonalTripTestFixtures.generationContext },
            createTrip: { _, _ in calls += 1; return await gate.wait() }
        )
        await sut.load()
        sut.updateDepartureCity("成都")
        let task = Task { await sut.submit() }
        await gate.waitUntilStarted()
        XCTAssertFalse(sut.canSubmit)
        await sut.submit()
        await sut.load()
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(loads, 1)
        task.cancel()
        gate.resume(.tripCreated(PersonalTripTestFixtures.detail(track: [])))
        await task.value
        XCTAssertNil(sut.createdTripID)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isSubmitting)
    }

    func testCancelledButtonWriteKeepsLockOnReappearanceAndRetryReusesKey() async {
        let gate = TripRequestGate<PersonalTripGenerationResult>()
        var keys: [String] = []
        var loads = 0
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in loads += 1; return PersonalTripTestFixtures.generationContext },
            createTrip: { _, key in
                keys.append(key)
                if keys.count == 1 { return await gate.wait() }
                return .tripCreated(PersonalTripTestFixtures.detail(track: []))
            }
        )
        await sut.handleAppearance()
        sut.updateDepartureCity("成都")
        let write = Task { await sut.submit() }
        await gate.waitUntilStarted()
        write.cancel() // The View explicitly cancels its button task on disappearance.
        await sut.handleAppearance()
        await sut.load()
        await sut.submit()
        sut.updateDepartureCity("上海")
        XCTAssertTrue(sut.isSubmitting)
        XCTAssertEqual(sut.departureCity, "成都")
        XCTAssertEqual(loads, 1)
        XCTAssertEqual(keys.count, 1)
        gate.resume(.tripCreated(PersonalTripTestFixtures.detail(track: [])))
        await write.value
        XCTAssertNil(sut.createdTripID)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isSubmitting)
        await sut.handleAppearance()
        XCTAssertNil(sut.createdTripID, "再次出现不自动重放离页前的成功结果")
        await sut.submit()
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(keys.first, keys.last)
        XCTAssertEqual(sut.createdTripID, "trip-1")
    }

    func testConflictCannotResubmitOldVersionAndRetryReusesUnknownResultKey() async {
        var keys: [String] = []
        var attempts = 0
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in PersonalTripTestFixtures.generationContext },
            createTrip: { _, key in
                keys.append(key)
                attempts += 1
                if attempts == 1 { throw APIClientError.transport(.connectionLost) }
                throw APIClientError.api(code: "route_version_conflict", message: "冲突", retryable: true)
            }
        )
        await sut.load()
        sut.updateDepartureCity("成都")
        await sut.submit()
        await sut.submit()
        await sut.submit()
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(keys.first, keys.last)
        XCTAssertTrue(sut.isVersionConflict)
    }

    func testCancelledAppearanceDoesNotPublishAndCanRetry() async {
        let gate = TripRequestGate<PersonalTripGenerationContext>()
        var loads = 0
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in
                loads += 1
                if loads == 1 { return await gate.wait() }
                return PersonalTripTestFixtures.generationContext
            },
            createTrip: { _, _ in .tripCreated(PersonalTripTestFixtures.detail(track: [])) }
        )
        let first = Task { await sut.handleAppearance() }
        await gate.waitUntilStarted()
        first.cancel()
        await sut.handleAppearance()
        gate.resume(PersonalTripTestFixtures.generationContext)
        await first.value
        await sut.handleAppearance()
        XCTAssertEqual(loads, 2)
        XCTAssertNotNil(sut.context)
        XCTAssertNil(sut.errorMessage)
    }

    func testTransportSelectionRequiredWithOneOptionIsRejectedAsInvalidResponse() async {
        let selection = PersonalTripTransportSelection(
            selectionID: "selection-1",
            options: [PersonalTripTestFixtures.transportSelection.options[0]]
        )
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in PersonalTripTestFixtures.generationContext },
            createTrip: { _, _ in .transportSelectionRequired(selection) }
        )
        await sut.load()
        sut.updateDepartureCity("成都")

        await sut.submit()

        XCTAssertNil(sut.transportSelection)
        XCTAssertNil(sut.selectedTransportOptionID)
        XCTAssertEqual(sut.errorMessage, APIClientError.invalidResponse.errorDescription)
        XCTAssertFalse(sut.isSubmitting)
    }

    func testTransportSelectionRequiredWithTwoOptionsPreservesInputAndUsesSelectionOnContinuation() async {
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
        sut.updateDepartureCity("成都")
        sut.updateStartDate(Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 8, day: 25)
        )!)
        sut.selectEquipmentList("equipment-list-1")

        await sut.submit()

        XCTAssertEqual(sut.departureCity, "成都")
        XCTAssertEqual(sut.selectedEquipmentListID, "equipment-list-1")
        XCTAssertEqual(sut.transportSelection?.selectionID, "selection-1")
        XCTAssertEqual(sut.transportSelection?.options.count, 2)

        sut.selectTransportOption("option-2")
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

    func testCreateTripRouteSummaryListsEveryGenerationMissingReasonInChinese() {
        let route = PersonalTripGenerationRoute(
            routeID: "route-1",
            currentPublicRouteVersionID: "route-version-1",
            routeType: "multi_day",
            generationEligibility: RouteGenerationEligibility(
                eligible: false,
                missingReasons: [.name, .region, .estimatedDuration, .start, .end, .validMainTrack]
            ),
            versionLabel: nil,
            name: nil,
            region: nil,
            start: nil,
            end: nil,
            difficulty: nil,
            distance: nil,
            estimatedDuration: nil
        )

        let presentation = CreateTripRouteSummaryPresentation(route: route)

        XCTAssertEqual(
            presentation.generationUnavailableMessage,
            "缺少：路线名称、所在地区、预计用时、起点、终点、有效主轨迹"
        )
    }

    func testEquipmentListPickerPresentationIncludesEverySummaryField() {
        let option = PersonalTripGenerationEquipmentListOption(
            equipmentListID: "equipment-list-1",
            name: "轻装",
            summary: EquipmentListSummary(
                itemCount: 3,
                knownTotalWeight: EquipmentWeight(grams: 1_250),
                missingWeightItemCount: 2
            )
        )

        let presentation = CreateTripEquipmentListPresentation(option: option)

        XCTAssertEqual(
            presentation.text,
            "轻装 · 3 类 · 已知总重量 1250 克 · 2 类未计入重量"
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
        sut.updateDepartureCity("成都")
        sut.updateStartDate(Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2026, month: 8, day: 25)
        )!)

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
        sut.updateDepartureCity("上海")
        sut.updateStartDate(selectedDate)
        sut.selectEquipmentList("equipment-list-1")
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
        sut.updateDepartureCity("上海")
        sut.selectEquipmentList("equipment-list-1")
        sut.prepareForPersonalEquipment()
        await sut.handleAppearance()

        XCTAssertEqual(sut.departureCity, "上海")
        XCTAssertNil(sut.selectedEquipmentListID)
    }

    func testChangingGenerationInputClearsTransportSelectionBoundToPreviousInput() async {
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in PersonalTripTestFixtures.generationContext },
            createTrip: { _, _ in .transportSelectionRequired(PersonalTripTestFixtures.transportSelection) }
        )
        await sut.load()
        sut.updateDepartureCity("成都")
        await sut.submit()
        sut.selectTransportOption("option-1")

        sut.updateDepartureCity("上海")

        XCTAssertNil(sut.transportSelection)
        XCTAssertNil(sut.selectedTransportOptionID)
        XCTAssertTrue(sut.canSubmit, "输入变化后应从新上下文重新生成，而不是继续提交旧 selectionId")
    }

    func testVersionConflictRefreshClearsTransportSelectionBoundToOldContext() async {
        let refreshedContext = PersonalTripGenerationContext(
            route: PersonalTripGenerationRoute(
                routeID: "route-1",
                currentPublicRouteVersionID: "route-version-2",
                routeType: "multi_day",
                generationEligibility: RouteGenerationEligibility(eligible: true),
                versionLabel: "v2",
                name: "贡嘎环线",
                region: "四川甘孜",
                start: PublicRoutePlace(name: "老榆林"),
                end: PublicRoutePlace(name: "草科"),
                difficulty: "中等",
                distance: RouteDistance(meters: 42_500),
                estimatedDuration: RouteDuration(seconds: 172_800)
            ),
            personalEquipmentSummary: PersonalTripTestFixtures.generationContext.personalEquipmentSummary,
            equipmentLists: PersonalTripTestFixtures.generationContext.equipmentLists
        )
        var contexts = [PersonalTripTestFixtures.generationContext, refreshedContext]
        var submission = 0
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in contexts.removeFirst() },
            createTrip: { _, _ in
                submission += 1
                if submission == 1 {
                    return .transportSelectionRequired(PersonalTripTestFixtures.transportSelection)
                }
                throw APIClientError.api(
                    code: "route_version_conflict",
                    message: "路线版本已变化",
                    retryable: true
                )
            }
        )
        await sut.load()
        sut.updateDepartureCity("成都")
        await sut.submit()
        sut.selectTransportOption("option-1")
        await sut.submit()

        XCTAssertTrue(sut.isVersionConflict)
        XCTAssertNil(sut.transportSelection, "版本冲突后旧 selectionId 已失效")
        XCTAssertNil(sut.selectedTransportOptionID)

        await sut.load()

        XCTAssertFalse(sut.isVersionConflict)
        XCTAssertEqual(sut.context?.route.currentPublicRouteVersionID, "route-version-2")
        XCTAssertNil(sut.transportSelection)
        XCTAssertNil(sut.selectedTransportOptionID)
        XCTAssertTrue(sut.canSubmit, "清除旧交通候选后应允许按新上下文重新生成")
    }

    func testVersionConflictRefreshFailureKeepsConflictAndExposesError() async {
        var loadCount = 0
        let sut = CreateTripViewModel(
            routeID: "route-1",
            loadContext: { _ in
                loadCount += 1
                if loadCount == 1 { return PersonalTripTestFixtures.generationContext }
                throw APIClientError.invalidResponse
            },
            createTrip: { _, _ in
                throw APIClientError.api(
                    code: "route_version_conflict",
                    message: "路线版本已变化",
                    retryable: true
                )
            }
        )
        await sut.load()
        sut.updateDepartureCity("成都")
        await sut.submit()

        await sut.load()

        XCTAssertTrue(sut.isVersionConflict)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testCreateTripViewRefreshesOnReturnWithoutDuplicateInitialTask() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let sourceURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Features/Trips/CreateTripView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains(".task { await viewModel.handleAppearance() }"))
        XCTAssertFalse(source.contains(".onAppear { Task"))
        XCTAssertFalse(source.contains(".task { await viewModel.load() }"))
    }

    func testCreateTripButtonTaskHasExplicitDepartureAndNavigationGuards() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Features/Trips/CreateTripView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("@State private var submissionTask: Task<Void, Never>?"))
        XCTAssertTrue(source.contains(".onAppear { isVisible = true }"))
        XCTAssertTrue(source.contains(".onDisappear {"))
        XCTAssertTrue(source.contains("isVisible = false\n            submissionTask?.cancel()"))
        XCTAssertTrue(source.contains("guard isVisible, submissionTask == nil, viewModel.canSubmit else { return }"))
        XCTAssertTrue(source.contains("defer { submissionTask = nil }"))
        XCTAssertTrue(source.contains("guard !Task.isCancelled, isVisible, let tripID = viewModel.createdTripID else { return }"))
        XCTAssertTrue(source.contains("action: submitTrip"))
        XCTAssertTrue(source.contains("retry: submitTrip"))
        XCTAssertFalse(source.contains(".onChange(of: viewModel.createdTripID)"))
        XCTAssertFalse(source.contains("Task { await viewModel.submit() }"))
    }

    func testCreateTripPageUsesProductionRouteSummaryAndWaitingComponents() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let sourceURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Features/Trips/CreateTripView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("SharedBusinessComponents.GenerationRouteSummaryCard("))
        XCTAssertTrue(source.contains("SharedBusinessComponents.GenerationWaitingView("))
        XCTAssertFalse(source.contains("private struct GenerationRouteSummaryCard"))
        XCTAssertFalse(source.contains("private struct GenerationWaitingView"))
    }
}

@MainActor
final class TripDayWeatherViewModelTests: XCTestCase {
    func testCancelledFallbackCannotReplaceNewWeatherProjection() async {
        let gate = TripRequestGate<PersonalTripDetail>()
        var calls = 0
        var details = 0
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in
                calls += 1
                if calls == 1 {
                    throw APIClientError.api(code: "trip_weather_projection_unavailable", message: "不可用", retryable: true)
                }
                return PersonalTripTestFixtures.populatedWeatherProjection
            },
            loadDetail: { _ in
                details += 1
                if details == 1 { return await gate.wait() }
                return PersonalTripTestFixtures.detail(track: [])
            }
        )
        let first = Task { await sut.load() }
        await gate.waitUntilStarted()
        first.cancel()
        await sut.load()
        gate.resume(PersonalTripTestFixtures.detail(revision: "old", track: []))
        await first.value
        XCTAssertEqual(sut.detail?.revision, "revision-1")
        XCTAssertNotNil(sut.weather)
        XCTAssertFalse(sut.isUnavailable)
        XCTAssertNil(sut.errorMessage)
    }

    func testFallbackCancellationDoesNotPublishUnavailableOrContext() async {
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in
                throw APIClientError.api(code: "trip_weather_projection_unavailable", message: "不可用", retryable: true)
            },
            loadDetail: { _ in throw CancellationError() }
        )
        await sut.load()
        XCTAssertNil(sut.detail)
        XCTAssertNil(sut.weather)
        XCTAssertFalse(sut.isUnavailable)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testCancellationDoesNotStartFallbackOrDisplayError() async {
        var detailCalls = 0
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in throw APIClientError.transport(.cancelled) },
            loadDetail: { _ in detailCalls += 1; return PersonalTripTestFixtures.detail(track: []) }
        )
        await sut.load()
        XCTAssertEqual(detailCalls, 0)
        XCTAssertFalse(sut.isUnavailable)
        XCTAssertNil(sut.errorMessage)
    }

    func testTripDayPresentationUsesSequenceAsTheOnlyActionAndPointOrder() {
        let day = PersonalTripTestFixtures.populatedDays.days[0]

        let presentation = TripDayPresentation(day: day)

        XCTAssertEqual(presentation.actionSequence, [1, 2])
        XCTAssertEqual(presentation.pointSequence, [3, 8])
        XCTAssertEqual(presentation.primaryStage, day.primaryStage)
        XCTAssertEqual(presentation.dayLabel, "D1")
    }

    func testTripDayPresentationKeepsDailyRouteSummaryWithoutDuplicatingHikeAction() {
        let day = PersonalTripTestFixtures.populatedDays.days[0]

        let presentation = TripDayPresentation(day: day)

        XCTAssertEqual(presentation.presentationItems.map(\.sequence), [1, 2])
        XCTAssertEqual(presentation.presentationItems.compactMap(\.action).map(\.actionType), [
            "long_distance_transport",
            "hike",
        ])
        XCTAssertEqual(
            presentation.presentationItems.filter(\.isDailyRouteSummary).map(\.sequence),
            [2]
        )
        XCTAssertEqual(
            presentation.presentationItems.compactMap(\.action).filter { $0.actionType == "hike" }.count,
            1
        )
        XCTAssertEqual(presentation.pointItems.map(\.sequence), [3, 8])
        XCTAssertEqual(presentation.pointItems.compactMap(\.point).map(\.category), ["campsite", "water_source"])
        XCTAssertTrue(presentation.hasDayContent)
    }

    func testTripDayPresentationDoesNotExposeRemovedSemanticSlots() throws {
        let source = try productionSource(at: "Features/Trips/TripDayWeatherViews.swift")

        XCTAssertFalse(source.contains("departureTransportActions"))
        XCTAssertFalse(source.contains("remainingTransportActions"))
        XCTAssertFalse(source.contains("groupedPoints"))
        XCTAssertFalse(source.contains("dailyRouteActions"))
    }

    func testTripDayWeatherUnavailableCountsAsVisibleDayContent() {
        let unavailable = InformationConfidence(status: "unavailable", category: .dynamicExternalInformation)
        let day = PersonalTripDay(
            identity: "day-1",
            dayNumber: 1,
            date: LocalDate(year: 2026, month: 8, day: 25),
            primaryStage: "徒步日 1",
            hikingDayNumber: 1,
            actions: [],
            weather: PersonalTripDayWeather(
                condition: QualifiedString(value: nil, confidence: unavailable),
                temperatureRange: QualifiedTemperatureRange(value: nil, confidence: unavailable),
                precipitation: QualifiedString(value: nil, confidence: unavailable),
                wind: QualifiedString(value: nil, confidence: unavailable),
                placeContext: QualifiedString(value: nil, confidence: unavailable),
                routeSectionContext: nil,
                source: nil,
                updatedAt: nil
            ),
            points: nil
        )

        XCTAssertTrue(TripDayPresentation(day: day).hasDayContent)
    }

    func testTripDayQualifiedFieldsKeepUnavailableStaleAndPendingVisible() {
        let unavailable = InformationConfidence(status: "unavailable", category: .dynamicExternalInformation)
        let stale = InformationConfidence(status: "stale", category: .dynamicExternalInformation)
        let pending = InformationConfidence(status: "pending_verification", category: .dynamicExternalInformation)
        let action = PersonalTripAction(
            sequence: 1,
            actionType: "long_distance_transport",
            origin: QualifiedPlace(value: PublicRoutePlace(name: "成都"), confidence: nil),
            destination: QualifiedPlace(value: nil, confidence: unavailable),
            mode: QualifiedString(value: nil, confidence: unavailable),
            keyTimes: QualifiedStringList(value: ["06:30"], confidence: pending),
            estimatedDuration: QualifiedDuration(value: RouteDuration(seconds: 7_200), confidence: stale),
            transferNotes: QualifiedStringList(value: nil, confidence: unavailable),
            routeSectionSnapshot: nil,
            start: nil,
            end: nil,
            distance: nil,
            ascent: nil
        )
        let point = PersonalTripPoint(
            sequence: 1,
            category: "water_source",
            type: "溪流",
            name: "补水点",
            distance: QualifiedDistance(value: nil, confidence: unavailable),
            location: nil,
            details: QualifiedString(value: nil, confidence: pending),
            isAlternative: nil
        )

        let actionPresentation = TripActionPresentation(action: action)
        XCTAssertTrue(actionPresentation.details.contains("起点 成都"))
        XCTAssertEqual(
            actionPresentation.statusNotices.map(\.message),
            ["终点：信息不可用", "交通方式：信息不可用", "关键时间：待核验", "预计耗时：信息已过期", "换乘说明：信息不可用"]
        )
        XCTAssertEqual(
            TripPointPresentation(point: point).statusNotices.map(\.message),
            ["距离：信息不可用", "详情：待核验"]
        )

        let weather = PersonalTripDayWeather(
            condition: QualifiedString(value: "多云", confidence: pending),
            temperatureRange: QualifiedTemperatureRange(value: nil, confidence: unavailable),
            precipitation: QualifiedString(value: "午后降雨", confidence: stale),
            wind: QualifiedString(value: nil, confidence: unavailable),
            placeContext: QualifiedString(value: "老榆林", confidence: nil),
            routeSectionContext: nil,
            source: nil,
            updatedAt: nil
        )
        XCTAssertEqual(
            TripDayWeatherPresentation(weather: weather).statusNotices.map(\.message),
            ["天气状况：待核验", "温度：信息不可用", "降水：信息已过期", "风力：信息不可用"]
        )
    }

    func testStructuredTemperatureRangeUsesTypedLowAndHighPresentation() {
        let temperatureRange = QualifiedTemperatureRange(
            value: TemperatureRange(low: 8, high: 16),
            confidence: nil
        )

        let presentation = TripTemperatureRangePresentation(qualified: temperatureRange)

        XCTAssertEqual(presentation.low, 8)
        XCTAssertEqual(presentation.high, 16)
        XCTAssertEqual(presentation.text, "8–16°C")
    }

    func testWeatherUnavailableRemainsVisibleWhenNoValueExists() {
        let unavailable = InformationConfidence(status: "unavailable", category: .dynamicExternalInformation)
        let weather = PersonalTripDayWeather(
            condition: QualifiedString(value: nil, confidence: unavailable),
            temperatureRange: QualifiedTemperatureRange(value: nil, confidence: unavailable),
            precipitation: QualifiedString(value: nil, confidence: unavailable),
            wind: QualifiedString(value: nil, confidence: unavailable),
            placeContext: QualifiedString(value: nil, confidence: unavailable),
            routeSectionContext: nil,
            source: nil,
            updatedAt: nil
        )

        XCTAssertEqual(weatherLine(weather), "暂不可用")
    }

    func testTripWeatherUnavailableKeepsTripContext() async {
        let detail = PersonalTripTestFixtures.detail(track: [])
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in
                throw APIClientError.api(
                    code: "trip_weather_projection_unavailable",
                    message: "行程天气关联尚未形成完整投影",
                    retryable: true
                )
            },
            loadDetail: { _ in detail }
        )

        await sut.load()

        XCTAssertNil(sut.weather)
        XCTAssertTrue(sut.isUnavailable)
        XCTAssertNil(sut.errorMessage)
        XCTAssertEqual(sut.detail, detail)
    }

    func testTripWeatherExposesDetailForMainBranch() async {
        let detail = PersonalTripTestFixtures.detail(track: [])
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection },
            loadDetail: { _ in detail }
        )

        await sut.load()

        XCTAssertEqual(sut.weather, PersonalTripTestFixtures.populatedWeatherProjection)
        XCTAssertEqual(sut.detail, detail)
        XCTAssertFalse(sut.isUnavailable)
        XCTAssertNil(sut.errorMessage)
    }

    func testTripWeatherRejectsEmptyDailyProjection() async {
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in PersonalTripTestFixtures.emptyWeatherProjection },
            loadDetail: { _ in PersonalTripTestFixtures.detail(track: []) }
        )

        await sut.load()

        XCTAssertNil(sut.weather)
        XCTAssertFalse(sut.isUnavailable)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testTripWeatherRejectsInvalidAssociationOrdering() async {
        let weather = PersonalTripWeather(
            tripID: "trip-1",
            revision: "revision-1",
            days: [
                PersonalTripWeatherAssociationDay(
                    tripDayID: "day-1",
                    dayNumber: 1,
                    date: LocalDate(year: 2026, month: 8, day: 25),
                    weatherAssociations: [
                        PersonalTripTestFixtures.association(identity: "weather-2", sequence: 2),
                        PersonalTripTestFixtures.association(identity: "weather-1", sequence: 1),
                    ]
                ),
            ]
        )
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in weather },
            loadDetail: { _ in PersonalTripTestFixtures.detail(track: []) }
        )

        await sut.load()

        XCTAssertNil(sut.weather)
        XCTAssertFalse(sut.isUnavailable)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testTripWeatherRejectsUnavailableAssociationThatContainsForecast() async {
        let invalidAssociation = PersonalTripTestFixtures.association(
            confidence: InformationConfidence(
                status: "unavailable",
                category: .dynamicExternalInformation
            ),
            forecast: PersonalTripTestFixtures.forecast
        )
        let weather = PersonalTripTestFixtures.weatherProjection(
            associations: [invalidAssociation]
        )
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in weather },
            loadDetail: { _ in PersonalTripTestFixtures.detail(track: []) }
        )

        await sut.load()

        XCTAssertNil(sut.weather)
        XCTAssertNotNil(sut.errorMessage)
    }

    func testTripWeatherRejectsDifferentContentsForSameForecastIdentity() async {
        let conflictingForecast = WeatherForecast(
            identity: PersonalTripTestFixtures.forecast.identity,
            location: PersonalTripTestFixtures.forecast.location,
            source: "另一来源",
            publishedAt: PersonalTripTestFixtures.forecast.publishedAt,
            periods: PersonalTripTestFixtures.forecast.periods
        )
        let weather = PersonalTripTestFixtures.weatherProjection(
            associations: [
                PersonalTripTestFixtures.association(identity: "weather-1", sequence: 1),
                PersonalTripTestFixtures.association(
                    identity: "weather-2",
                    sequence: 2,
                    forecast: conflictingForecast
                ),
            ]
        )
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in weather },
            loadDetail: { _ in PersonalTripTestFixtures.detail(track: []) }
        )

        await sut.load()

        XCTAssertNil(sut.weather)
        XCTAssertNotNil(sut.errorMessage)
    }

    /// PAGE-TRIP-WEATHER 逐日卡的唯一数据源是冻结自然日天气（detail.days[].weather），
    /// 不从预报关联聚合派生逐日字段；整趟概况同样不聚合预报时段。
    func testTripWeatherPageBuildsDailyCardsFromFrozenDayWeatherNotForecastPeriods() throws {
        let source = try productionSource(at: "Features/Trips/TripDayWeatherViews.swift")

        XCTAssertFalse(source.contains("forecast"))
        XCTAssertFalse(source.contains("Forecast"))
        XCTAssertFalse(source.contains("weatherAssociations"))
    }

    /// PAGE-TRIP-BROWSE：无自然日结果用 EmptyState 表达，不进入结构错误；
    /// 边界提示按 Page spec 三形态文案。
    func testTripBrowseUsesEmptyStateForNoDaysAndBoundaryCueTexts() throws {
        let source = try productionSource(at: "Features/Trips/TripBrowseView.swift")

        XCTAssertTrue(source.contains("不会根据起止日期或默认模板补造"))
        XCTAssertTrue(source.contains("本次行程只有一天"))
        XCTAssertTrue(source.contains("到达底部后继续上滑查看下一日"))
    }

    func testTripWeatherAcceptsProjectionMatchingCurrentRevision() async {
        let sut = TripWeatherViewModel(
            tripID: "trip-1",
            loadWeather: { _ in PersonalTripTestFixtures.populatedWeatherProjection },
            loadDetail: { _ in PersonalTripTestFixtures.detail(track: []) }
        )

        await sut.load()

        XCTAssertEqual(sut.weather, PersonalTripTestFixtures.populatedWeatherProjection)
        XCTAssertFalse(sut.isUnavailable)
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

@MainActor
final class TripBrowseViewModelTests: XCTestCase {
    func testRetryResolvesRequestedInitialDayAfterFailure() async {
        var calls = 0
        let sut = TripBrowseViewModel(
            loadDetail: { _ in
                calls += 1
                if calls == 1 { throw APIClientError.invalidResponse }
                return PersonalTripTestFixtures.detail(track: [])
            },
            loadDays: { _ in PersonalTripTestFixtures.twoDays }
        )
        let failed = await sut.loadInitialDay(id: "trip-1", dayNumber: 2)
        XCTAssertNil(failed)
        let index = await sut.loadInitialDay(id: "trip-1", dayNumber: 2)
        XCTAssertEqual(index, 1)
        XCTAssertEqual(sut.pages.map(\.dayNumber), [1, 2])
    }

    func testCancelledBrowseDoesNotPublishLateProjection() async {
        let gate = TripRequestGate<PersonalTripDetail>()
        let sut = TripBrowseViewModel(
            loadDetail: { _ in await gate.wait() },
            loadDays: { _ in PersonalTripTestFixtures.days }
        )
        let task = Task { await sut.loadTrip(id: "trip-1") }
        await gate.waitUntilStarted()
        task.cancel()
        gate.resume(PersonalTripTestFixtures.detail(track: []))
        let loaded = await task.value
        XCTAssertFalse(loaded)
        XCTAssertNil(sut.trip)
        XCTAssertTrue(sut.pages.isEmpty)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }

    func testBrowseDuplicateIsIgnoredAndCancelledLateReadCannotReplaceRetry() async {
        let gate = TripRequestGate<PersonalTripDetail>()
        var calls = 0
        let current = PersonalTripTestFixtures.detail(track: [])
        let sut = TripBrowseViewModel(
            loadDetail: { _ in
                calls += 1
                if calls == 1 { return await gate.wait() }
                return current
            },
            loadDays: { _ in PersonalTripTestFixtures.twoDays }
        )
        let first = Task { await sut.loadInitialDay(id: "trip-1", dayNumber: 2) }
        await gate.waitUntilStarted()
        let duplicate = await sut.loadInitialDay(id: "trip-1", dayNumber: 2)
        XCTAssertNil(duplicate)
        XCTAssertEqual(calls, 1)
        first.cancel()
        let retryIndex = await sut.loadInitialDay(id: "trip-1", dayNumber: 2)
        gate.resume(PersonalTripTestFixtures.detail(revision: "old", track: []))
        let cancelledIndex = await first.value
        XCTAssertNil(cancelledIndex)
        XCTAssertEqual(retryIndex, 1)
        XCTAssertEqual(sut.trip, current)
        XCTAssertEqual(sut.pages.map(\.dayNumber), [1, 2])
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isLoading)
    }
}

/// Deterministic suspension; deliberately ignores cancellation to exercise publication guards.
@MainActor
private final class TripRequestGate<Value> {
    private var continuation: CheckedContinuation<Value, Never>?
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func wait() async -> Value {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started = true
            startWaiters.forEach { $0.resume() }
            startWaiters.removeAll()
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func resume(_ value: Value) {
        continuation?.resume(returning: value)
        continuation = nil
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
        importantNotices: [PersonalTripImportantNotice]? = nil,
        versionLabel: String? = "v1"
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
                    versionLabel: versionLabel,
                    cover: nil,
                    direction: "环线",
                    distance: RouteDistance(meters: 42_500),
                    ascent: RouteElevationGain(meters: 2_300),
                    descent: RouteElevationLoss(meters: 2_200),
                    maxElevation: RouteElevation(meters: 4_700)
                ),
                weatherOverview: WeatherOverview(summary: QualifiedString(value: "多云，午后可能有雨", confidence: nil)),
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

    static let weather = LegacyPersonalTripWeather(
        tripID: "trip-1",
        revision: "revision-1",
        routeName: "贡嘎环线",
        startDate: LocalDate(year: 2026, month: 8, day: 25),
        endDate: LocalDate(year: 2026, month: 8, day: 27),
        days: [],
        weatherOverview: WeatherOverview(summary: QualifiedString(value: "多云", confidence: nil))
    )

    static let populatedWeather = LegacyPersonalTripWeather(
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
        weatherOverview: WeatherOverview(summary: QualifiedString(value: "整体多云", confidence: nil))
    )

    static let populatedDayWeather = PersonalTripDayWeather(
        condition: QualifiedString(value: "多云", confidence: nil),
        temperatureRange: QualifiedTemperatureRange(value: TemperatureRange(low: 8, high: 16), confidence: nil),
        precipitation: QualifiedString(value: "午后降雨", confidence: InformationConfidence(status: "pending_verification", category: .dynamicExternalInformation)),
        wind: QualifiedString(value: "微风", confidence: InformationConfidence(status: "verified", category: .dynamicExternalInformation)),
        placeContext: QualifiedString(value: "老榆林", confidence: nil),
        routeSectionContext: WeatherQualifiedValue(
            value: PersonalTripRouteSectionSnapshot(
                start: PublicRoutePlace(name: "老榆林"),
                end: PublicRoutePlace(name: "垭口"),
                name: "日乌且垭口段",
                path: nil
            ),
            confidence: nil
        ),
        source: QualifiedString(value: "气象服务", confidence: InformationConfidence(status: "verified", category: .dynamicExternalInformation)),
        updatedAt: QualifiedInstant(value: Instant(rawValue: "2026-08-24T08:00:00+08:00"), confidence: InformationConfidence(status: "verified", category: .dynamicExternalInformation))
    )

    static let forecast = WeatherForecast(
        identity: "forecast-1",
        location: WeatherLocation(
            position: PublicRouteGeoPosition(
                latitude: 29.6,
                longitude: 101.8,
                referenceSystem: "WGS84"
            ),
            name: "老榆林"
        ),
        source: "气象服务",
        publishedAt: Instant(rawValue: "2026-08-24T08:00:00Z"),
        periods: [
            WeatherForecastPeriod(
                periodStart: Instant(rawValue: "2026-08-24T16:00:00Z"),
                periodEnd: Instant(rawValue: "2026-08-25T04:00:00Z"),
                condition: WeatherQualifiedValue(
                    value: WeatherCondition(description: "多云")
                )
            ),
        ]
    )

    static func association(
        identity: String = "weather-1",
        sequence: Int = 1,
        confidence: InformationConfidence? = nil,
        forecast: WeatherForecast? = forecast
    ) -> TripWeatherAssociation {
        TripWeatherAssociation(
            associationIdentity: identity,
            sequence: sequence,
            scope: .day,
            targetLocation: WeatherLocation(
                position: PublicRouteGeoPosition(
                    latitude: 29.6,
                    longitude: 101.8,
                    referenceSystem: "WGS84"
                ),
                name: "老榆林"
            ),
            targetPeriodStart: Instant(rawValue: "2026-08-24T16:00:00Z"),
            targetPeriodEnd: Instant(rawValue: "2026-08-25T16:00:00Z"),
            forecastConfidence: confidence,
            forecast: forecast
        )
    }

    static func weatherProjection(
        associations: [TripWeatherAssociation]
    ) -> PersonalTripWeather {
        PersonalTripWeather(
            tripID: "trip-1",
            revision: "revision-1",
            days: [
                PersonalTripWeatherAssociationDay(
                    tripDayID: "day-1",
                    dayNumber: 1,
                    date: LocalDate(year: 2026, month: 8, day: 25),
                    weatherAssociations: associations
                ),
            ]
        )
    }

    static let emptyWeatherProjection = PersonalTripWeather(
        tripID: "trip-1",
        revision: "revision-1",
        days: []
    )

    static let populatedWeatherProjection = weatherProjection(
        associations: [association()]
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
                    ascent: QualifiedElevationGain(value: RouteElevationGain(meters: 900), confidence: nil)
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
                estimatedArrivalAt: QualifiedInstant(
                    value: Instant(rawValue: "2026-08-25T08:00:00Z"),
                    confidence: nil
                ),
                estimatedDuration: QualifiedDuration(
                    value: RouteDuration(seconds: 7_200),
                    confidence: nil
                ),
                verificationItems: ["确认班次"]
            ),
            PersonalTripTransportOption(
                transportOptionID: "option-2",
                transferCount: QualifiedInteger(value: 0, confidence: nil),
                estimatedArrivalAt: QualifiedInstant(
                    value: Instant(rawValue: "2026-08-25T09:00:00Z"),
                    confidence: nil
                ),
                estimatedDuration: QualifiedDuration(
                    value: RouteDuration(seconds: 9_000),
                    confidence: nil
                ),
                verificationItems: []
            ),
        ]
    )
}
