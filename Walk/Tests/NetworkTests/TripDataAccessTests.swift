import XCTest
@testable import Walk

final class TripDataAccessTests: XCTestCase {
    func testTripListFixtureDecodesBackendContractAndMapsPage() throws {
        let envelope: APIEnvelope<PageDTO<TripResponseDTO>> = try TripFixture.decode("trip-list")
        let dtoPage = try envelope.unwrap()
        let page = dtoPage.map(Trip.init(dto:))

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.number, 0)
        XCTAssertEqual(page.totalElements, 1)
        XCTAssertEqual(page.items[0].routeId, "route-primary")
        XCTAssertEqual(dtoPage.items[0].routeIDs, ["route-primary", "route-secondary"])
        XCTAssertEqual(dtoPage.items[0].primaryRouteID, "route-primary")
        XCTAssertEqual(page.items[0].status, .inProgress)
        XCTAssertEqual(page.items[0].startDate?.timeIntervalSince1970, 1_724_544_000)
    }

    func testTripDetailFixturePreservesUnknownStatus() throws {
        let envelope: APIEnvelope<TripResponseDTO> = try TripFixture.decode("trip-detail-unknown-status")
        let trip = Trip(dto: try envelope.unwrap())

        XCTAssertEqual(trip.status, .unknown(9))
        XCTAssertEqual(trip.status.rawValue, 9)
    }

    func testTripErrorFixtureUsesFlatEnvelope() throws {
        let envelope: APIEnvelope<TripResponseDTO> = try TripFixture.decode("trip-error")

        XCTAssertThrowsError(try envelope.unwrap()) { error in
            XCTAssertEqual(error as? APIClientError, .business(message: "行程不存在", code: 404))
        }
    }

    func testDefaultMockFixturesIncludeHistoricalTripQueries() {
        let fixtures = DefaultMockFixtures.tripFixtures(bundle: Bundle(for: TripDataAccessTests.self))

        XCTAssertNotNil(fixtures[TripAPI.List(status: .completed).identifier])
        XCTAssertNotNil(fixtures[TripAPI.List(status: .cancelled).identifier])
    }

    func testLegacyTripRequestsUseRelocatedControllerPathAndStoragePolicy() throws {
        let list = TripAPI.List(
            keyword: "山",
            status: .completed,
            organizerID: "owner",
            participantID: "member",
            page: 2,
            size: 10,
            sort: ["createdAt,desc"]
        )
        XCTAssertEqual(list.method, .get)
        XCTAssertEqual(list.path, "/legacy/trips")
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: list.query.map { ($0.name, $0.value ?? "") })["status"], "2")
        XCTAssertEqual(list.storagePolicy, .none)

        XCTAssertEqual(TripAPI.Detail(id: "trip-1").storagePolicy, .store)
        XCTAssertEqual(TripAPI.Detail(id: "trip-1").path, "/legacy/trips/trip-1")
        XCTAssertEqual(TripAPI.Create(input: TripCreateRequestDTO(
            name: "新行程",
            description: nil,
            startDate: nil,
            endDate: nil,
            organizerID: nil,
            routeIDs: [],
            primaryRouteID: nil,
            budget: nil,
            notes: nil,
            privacySetting: 0,
            coverURL: nil
        )).path, "/legacy/trips")
        XCTAssertEqual(TripAPI.Delete(id: "trip-1").method, .delete)
        XCTAssertEqual(TripAPI.Delete(id: "trip-1").path, "/legacy/trips/trip-1")
        XCTAssertEqual(TripAPI.UpdateStatus(id: "trip-1", status: .cancelled).path, "/legacy/trips/trip-1/status")
        XCTAssertEqual(TripAPI.UpdateStatus(id: "trip-1", status: .cancelled).query.first?.value, "3")

        let create = TripCreateRequestDTO(
            name: "新行程",
            description: nil,
            startDate: Date(timeIntervalSince1970: 1_724_544_000),
            endDate: nil,
            organizerID: "owner",
            routeIDs: ["route-1"],
            primaryRouteID: "route-1",
            budget: nil,
            notes: nil,
            privacySetting: 0,
            coverURL: nil
        )
        let json = try XCTUnwrap(TripAPI.Create(input: create).body)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        XCTAssertEqual(object["start_date"] as? Int, 1_724_544_000)
        XCTAssertEqual(object["primary_route_id"] as? String, "route-1")
        XCTAssertEqual(object["route_ids"] as? [String], ["route-1"])
    }

    func testRepositoryMapsListDetailAndEmptyDeleteUsingOneClient() async throws {
        let list = try TripFixture.data("trip-list")
        let detail = try TripFixture.data("trip-detail")
        let empty = try TripFixture.data("api-empty")
        let fixtures = [
            TripAPI.List().identifier: list,
            TripAPI.Detail(id: "trip-1").identifier: detail,
            TripAPI.Delete(id: "trip-1").identifier: empty
        ]
        let repository = DefaultTripRepository(client: MockAPIClient(fixtures: fixtures))

        let page = try await repository.fetchTrips()
        let fetchedTrip = try await repository.fetchTrip(id: "trip-1")
        XCTAssertEqual(page.items.first?.id, "trip-1")
        XCTAssertEqual(fetchedTrip.routeId, "route-primary")
        try await repository.deleteTrip(id: "trip-1")
    }

    func testPersonalTripRequestsUseTargetPathsDataEnvelopeAndNoQueries() {
        assertTargetRequest(PersonalTripAPI.Focus(), path: "/trips/focus")
        assertTargetRequest(PersonalTripAPI.Collection(), path: "/trips")
        assertTargetRequest(PersonalTripAPI.Calendar(), path: "/trips/calendar")
        assertTargetRequest(PersonalTripAPI.Detail(tripID: "trip-1"), path: "/trips/trip-1")
        assertTargetRequest(PersonalTripAPI.Days(tripID: "trip-1"), path: "/trips/trip-1/days")
        assertTargetRequest(PersonalTripAPI.Weather(tripID: "trip-1"), path: "/trips/trip-1/weather")
        assertTargetRequest(
            PersonalTripAPI.GenerationContext(routeID: "route-1"),
            path: "/public-routes/route-1/trip-generation-context"
        )
    }

    func testPersonalTripMutationRequestsUseTargetPathsIdempotencyAndCamelCaseBodies() throws {
        let status = PersonalTripAPI.RouteVersionStatus(tripID: "trip-1")
        XCTAssertEqual(status.method, .get)
        XCTAssertEqual(status.path, "/trips/trip-1/route-version-status")
        XCTAssertEqual(status.responseEnvelope, .data)

        let cancel = try PersonalTripAPI.Cancel(
            tripID: "trip-1",
            input: PersonalTripCancelRequest(expectedRevision: "revision-1", confirmed: true),
            idempotencyKey: "cancel-key"
        )
        XCTAssertEqual(cancel.method, .post)
        XCTAssertEqual(cancel.path, "/trips/trip-1/cancellations")
        XCTAssertEqual(cancel.headers["Idempotency-Key"], "cancel-key")
        let cancelBody = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(cancel.body)) as? [String: Any]
        )
        XCTAssertEqual(cancelBody["expectedRevision"] as? String, "revision-1")
        XCTAssertEqual(cancelBody["confirmed"] as? Bool, true)
        XCTAssertNil(cancelBody["ownerId"])
        XCTAssertNil(cancelBody["expected_revision"])

        let migrate = try PersonalTripAPI.Migrate(
            tripID: "trip-1",
            input: PersonalTripMigrateRequest(
                expectedRevision: "revision-1",
                targetRouteVersionID: "route-version-2"
            ),
            idempotencyKey: "migration-key"
        )
        XCTAssertEqual(migrate.method, .post)
        XCTAssertEqual(migrate.path, "/trips/trip-1/route-migrations")
        XCTAssertEqual(migrate.headers["Idempotency-Key"], "migration-key")
        let migrateBody = try XCTUnwrap(
            JSONSerialization.jsonObject(with: try XCTUnwrap(migrate.body)) as? [String: Any]
        )
        XCTAssertEqual(migrateBody["expectedRevision"] as? String, "revision-1")
        XCTAssertEqual(migrateBody["targetRouteVersionId"] as? String, "route-version-2")
        XCTAssertNil(migrateBody["ownerId"])
        XCTAssertNil(migrateBody["target_route_version_id"])
    }

    func testTargetContractsContainNoSnakeCaseWireKeys() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let sourceRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let apiModels = try String(
            contentsOf: sourceRoot.appendingPathComponent("Core/Network/APIModels.swift"),
            encoding: .utf8
        )
        let targetModels = try XCTUnwrap(apiModels.components(separatedBy: "enum AccountAPI").last)
        let tripEquipment = try String(
            contentsOf: sourceRoot.appendingPathComponent("Features/Trips/TripEquipment.swift"),
            encoding: .utf8
        )

        for forbiddenKey in [
            "expected_revision", "route_id", "unit_weight", "trip_revision",
            "start_date", "equipment_list_id", "target_route_version_id"
        ] {
            XCTAssertFalse(targetModels.contains(forbiddenKey), "target APIModels contains \(forbiddenKey)")
            XCTAssertFalse(tripEquipment.contains(forbiddenKey), "TripEquipment contains \(forbiddenKey)")
        }
    }

    func testTargetPersonalTripDataAccessIsIsolatedFromLegacyRepositoryAndUserID() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let sourceURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Features/Trips/TripDataAccess.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains("TripRepository"))
        XCTAssertFalse(source.contains("LegacyAPIClient"))
        XCTAssertFalse(source.contains("MockData"))
        XCTAssertFalse(source.contains("userId"))
    }

    func testRouteVersionStatusDecodesAllDifferenceFields() throws {
        let data = Data(
            """
            {
              "data": {
                "tripId": "trip-1",
                "tripRevision": "revision-1",
                "adoptedVersion": {"routeVersionId": "route-version-1", "versionLabel": "旧版"},
                "currentPublicVersion": {"routeVersionId": "route-version-2", "versionLabel": "新版"},
                "versionRelationship": "newer_public_version_available",
                "migrationEligible": true,
                "difference": {
                  "minimumComparisonStatus": "partial",
                  "differences": [
                    {
                      "category": "identity_and_structure",
                      "changeType": "modified",
                      "subject": "routeName",
                      "summary": "路线名称已更新",
                      "before": {"value": "旧名称"},
                      "after": {"value": "新名称"}
                    },
                    {
                      "category": "seasonal_preparation_and_equipment",
                      "changeType": "added",
                      "subject": "logical-tent",
                      "summary": "新增帐篷建议",
                      "after": {"value": "帐篷"}
                    }
                  ],
                  "unavailableCategories": ["planning_support_and_safety"],
                  "otherRelevantChangeStatus": "changed",
                  "otherRelevantChanges": ["补充了营地说明"]
                }
              }
            }
            """.utf8
        )

        let status = try APIJSONDecoder.decode(
            PersonalTripRouteVersionStatus.self,
            from: data,
            envelope: .data
        )

        XCTAssertEqual(status.versionRelationship, .newerPublicVersionAvailable)
        XCTAssertEqual(status.difference?.minimumComparisonStatus, .partial)
        XCTAssertEqual(status.difference?.differences.map(\.category), [
            .identityAndStructure,
            .seasonalPreparationAndEquipment,
        ])
        XCTAssertEqual(status.difference?.differences.map(\.changeType), [.modified, .added])
        XCTAssertEqual(status.difference?.differences.first?.before?.value, "旧名称")
        XCTAssertEqual(status.difference?.differences.first?.after?.value, "新名称")
        XCTAssertEqual(status.difference?.unavailableCategories, [.planningSupportAndSafety])
        XCTAssertEqual(status.difference?.otherRelevantChangeStatus, .changed)
        XCTAssertEqual(status.difference?.otherRelevantChanges, ["补充了营地说明"])
    }

    func testPersonalTripCreateSendsIdempotencyHeaderAndLocalDateBody() throws {
        let request = try PersonalTripAPI.Create(
            input: PersonalTripCreateRequest(
                routeID: "route-1",
                routeVersionID: "route-version-1",
                departureCity: "成都",
                startDate: LocalDate(year: 2026, month: 8, day: 25),
                equipmentListID: "equipment-list-1",
                transportSelection: PersonalTripTransportSelectionRequest(
                    selectionID: "selection-1",
                    transportOptionID: "option-2"
                )
            ),
            idempotencyKey: "request-1"
        )

        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.path, "/trips")
        XCTAssertEqual(request.headers["Idempotency-Key"], "request-1")
        XCTAssertEqual(request.responseEnvelope, .data)

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.body)) as? [String: Any])
        XCTAssertEqual(object["routeId"] as? String, "route-1")
        XCTAssertEqual(object["routeVersionId"] as? String, "route-version-1")
        XCTAssertEqual(object["departureCity"] as? String, "成都")
        XCTAssertEqual(object["startDate"] as? String, "2026-08-25")
        XCTAssertEqual(object["equipmentListId"] as? String, "equipment-list-1")
        XCTAssertNil(object["userId"])
        XCTAssertNil(object["route_id"])
        let selection = try XCTUnwrap(object["transportSelection"] as? [String: Any])
        XCTAssertEqual(selection["selectionId"] as? String, "selection-1")
        XCTAssertEqual(selection["transportOptionId"] as? String, "option-2")
    }

    func testLocalDateRoundTripsWithoutAcceptingInstantValues() throws {
        let value = LocalDate(year: 2026, month: 8, day: 25)
        let encoded = try JSONEncoder().encode(value)

        XCTAssertEqual(String(decoding: encoded, as: UTF8.self), "\"2026-08-25\"")
        XCTAssertEqual(try JSONDecoder().decode(LocalDate.self, from: encoded), value)
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                LocalDate.self,
                from: Data("\"2026-08-25T00:00:00Z\"".utf8)
            )
        )
    }

    func testGenerateResultDecodesTransportSelectionRequired() throws {
        let data = Data(
            """
            {
              "data": {
                "resultType": "transport_selection_required",
                "selection": {
                  "selectionId": "selection-1",
                  "options": [{
                    "transportOptionId": "option-1",
                    "transferCount": {"value": 1},
                    "estimatedArrivalAt": {"value": "2026-08-25T08:00:00Z"},
                    "estimatedDuration": {"value": {"seconds": 7200}},
                    "verificationItems": ["确认班次"]
                  }]
                }
              }
            }
            """.utf8
        )

        let result = try APIJSONDecoder.decode(
            PersonalTripGenerationResult.self,
            from: data,
            envelope: .data
        )

        guard case .transportSelectionRequired(let selection) = result else {
            return XCTFail("Expected transportSelection_required")
        }
        XCTAssertEqual(selection.selectionID, "selection-1")
        XCTAssertEqual(selection.options.first?.transportOptionID, "option-1")
    }

    func testGenerateResultDecodesTripCreatedWithFrozenTrack() throws {
        let result = try APIJSONDecoder.decode(
            PersonalTripGenerationResult.self,
            from: Self.tripCreatedEnvelope,
            envelope: .data
        )

        guard case .tripCreated(let detail) = result else {
            return XCTFail("Expected trip_created")
        }
        XCTAssertEqual(detail.trip.identity, "trip-1")
        XCTAssertEqual(detail.trip.startDate, LocalDate(year: 2026, month: 8, day: 25))
        XCTAssertEqual(detail.trip.frozenRouteBasis.mainTrackPath.count, 2)
    }

    func testPersonalTripServiceLoadsFocusAndServerGroupedCollection() async throws {
        let focus = Data(
            """
            {"data":{"trip":\(Self.summaryJSON)}}
            """.utf8
        )
        let collection = Data(
            """
            {"data":{"currentTrips":[\(Self.summaryJSON)],"historicalTrips":[]}}
            """.utf8
        )
        let service = PersonalTripService(apiClient: MockAPIClient(fixtures: [
            PersonalTripAPI.Focus().identifier: focus,
            PersonalTripAPI.Collection().identifier: collection
        ]))

        let focused = try await service.focus()
        let grouped = try await service.list()

        XCTAssertEqual(focused.trip?.tripID, "trip-1")
        XCTAssertEqual(grouped.currentTrips.map(\.tripID), ["trip-1"])
        XCTAssertTrue(grouped.historicalTrips.isEmpty)
    }

    func testPersonalTripServiceExecutesStatusCancelAndMigrateRequests() async throws {
        let detail = PersonalTripTestFixtures.detail(track: [])
        let status = PersonalTripTestFixtures.newerStatus
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let detailData = try encoder.encode(TestDataEnvelope(data: detail))
        let statusData = try encoder.encode(TestDataEnvelope(data: status))
        let cancelRequest = try PersonalTripAPI.Cancel(
            tripID: "trip-1",
            input: PersonalTripCancelRequest(expectedRevision: "revision-1", confirmed: true),
            idempotencyKey: "cancel-key"
        )
        let migrateRequest = try PersonalTripAPI.Migrate(
            tripID: "trip-1",
            input: PersonalTripMigrateRequest(
                expectedRevision: "revision-1",
                targetRouteVersionID: "route-version-2"
            ),
            idempotencyKey: "migration-key"
        )
        let service = PersonalTripService(apiClient: MockAPIClient(fixtures: [
            PersonalTripAPI.RouteVersionStatus(tripID: "trip-1").identifier: statusData,
            cancelRequest.identifier: detailData,
            migrateRequest.identifier: detailData,
        ]))

        let loadedStatus = try await service.routeVersionStatus(tripID: "trip-1")
        let cancelled = try await service.cancel(
            tripID: "trip-1",
            expectedRevision: "revision-1",
            confirmed: true,
            idempotencyKey: "cancel-key"
        )
        let migrated = try await service.migrate(
            tripID: "trip-1",
            expectedRevision: "revision-1",
            targetRouteVersionID: "route-version-2",
            idempotencyKey: "migration-key"
        )

        XCTAssertEqual(loadedStatus, status)
        XCTAssertEqual(cancelled, detail)
        XCTAssertEqual(migrated, detail)
    }

    func testLiveBackendStatusMigrationAndCancellationFlow() async throws {
        let arguments = ProcessInfo.processInfo.arguments
        func argument(named name: String) -> String? {
            guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else {
                return nil
            }
            return arguments[index + 1]
        }
        guard arguments.contains("-walkLiveBackendTest") else {
            throw XCTSkip("Pass -walkLiveBackendTest to run the live backend contract test")
        }
        let environment = ProcessInfo.processInfo.environment
        let baseURL = try XCTUnwrap(
            argument(named: "-walkLiveBackendURL")
                .flatMap(URL.init(string:))
                ?? environment["WALK_LIVE_BACKEND_URL"].flatMap(URL.init(string:))
        )
        let accessToken = try XCTUnwrap(
            argument(named: "-walkLiveBackendToken")
                ?? environment["WALK_LIVE_BACKEND_TOKEN"]
        )
        let service = PersonalTripService(
            apiClient: AlamofireRemoteAPIClient(
                baseURL: baseURL,
                accessToken: { accessToken }
            )
        )

        let initialStatus = try await service.routeVersionStatus(tripID: "ios-e2e-trip")
        XCTAssertEqual(initialStatus.adoptedVersion.routeVersionID, "ios-e2e-version-1")
        XCTAssertEqual(initialStatus.currentPublicVersion?.routeVersionID, "ios-e2e-version-2")
        XCTAssertEqual(initialStatus.versionRelationship, .newerPublicVersionAvailable)
        XCTAssertTrue(initialStatus.migrationEligible)

        let migrated = try await service.migrate(
            tripID: "ios-e2e-trip",
            expectedRevision: "ios-e2e-revision-1",
            targetRouteVersionID: "ios-e2e-version-2",
            idempotencyKey: "ios-e2e-migrate-\(UUID().uuidString)"
        )
        XCTAssertEqual(migrated.trip.identity, "ios-e2e-trip")
        XCTAssertEqual(migrated.routeReference.adoptedRouteVersionID, "ios-e2e-version-2")
        XCTAssertEqual(migrated.routeVersionStatus.versionRelationship, .current)
        XCTAssertFalse(migrated.routeVersionStatus.migrationEligible)
        XCTAssertNotEqual(migrated.revision, "ios-e2e-revision-1")

        let cancelled = try await service.cancel(
            tripID: "ios-e2e-trip",
            expectedRevision: migrated.revision,
            confirmed: true,
            idempotencyKey: "ios-e2e-cancel-\(UUID().uuidString)"
        )
        XCTAssertEqual(cancelled.trip.identity, "ios-e2e-trip")
        XCTAssertEqual(cancelled.trip.status, .cancelled)
        XCTAssertEqual(cancelled.routeReference.adoptedRouteVersionID, "ios-e2e-version-2")
        XCTAssertNotEqual(cancelled.revision, migrated.revision)

        let reloaded = try await service.detail(tripID: "ios-e2e-trip")
        XCTAssertEqual(reloaded, cancelled)
    }

    private func assertTargetRequest<Request: APIRequest>(
        _ request: Request,
        path: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(request.method, .get, file: file, line: line)
        XCTAssertEqual(request.path, path, file: file, line: line)
        XCTAssertEqual(request.responseEnvelope, .data, file: file, line: line)
        XCTAssertTrue(request.query.isEmpty, file: file, line: line)
    }

    private static let summaryJSON = """
    {
      "tripId": "trip-1",
      "revision": "revision-1",
      "name": "贡嘎行程",
      "status": "planned",
      "routeReference": {"routeId": "route-1", "adoptedRouteVersionId": "route-version-1"},
      "routeName": "贡嘎环线",
      "routeType": "multi_day",
      "start": {"name": "老榆林"},
      "end": {"name": "草科"},
      "estimatedDuration": {"seconds": 172800},
      "startDate": "2026-08-25",
      "endDate": "2026-08-27",
      "totalDayCount": 3,
      "hikingDayCount": 2,
      "cover": "https://example.test/cover.jpg"
    }
    """

    private static let tripCreatedEnvelope = Data(
        """
        {
          "data": {
            "resultType": "trip_created",
            "trip": {
              "revision": "revision-1",
              "trip": {
                "identity": "trip-1",
                "name": "贡嘎行程",
                "firstGeneratedAt": "2026-08-01T10:00:00Z",
                "status": "planned",
                "departureCity": "成都",
                "startDate": "2026-08-25",
                "endDate": "2026-08-27",
                "totalDayCount": 3,
                "hikingDayCount": 2,
                "frozenRouteBasis": {
                  "routeName": "贡嘎环线",
                  "routeType": "multi_day",
                  "region": "四川甘孜",
                  "start": {"name": "老榆林"},
                  "end": {"name": "草科"},
                  "estimatedDuration": {"seconds": 172800},
                  "mainTrackPath": [
                    {"latitude": 29.6, "longitude": 101.8, "referenceSystem": "WGS84"},
                    {"latitude": 29.7, "longitude": 101.9, "referenceSystem": "WGS84"}
                  ]
                },
                "importantNotices": []
              },
              "routeReference": {"routeId": "route-1", "adoptedRouteVersionId": "route-version-1"},
              "days": [],
              "equipmentSnapshot": {
                "snapshotId": "equipment-snapshot-1",
                "summary": {
                  "itemCount": 0,
                  "knownTotalWeight": {"grams": 0},
                  "missingWeightItemCount": 0,
                  "ownedItemCount": 0,
                  "unconfirmedOwnedItemCount": 0
                }
              },
              "routeVersionStatus": {
                "tripId": "trip-1",
                "tripRevision": "revision-1",
                "adoptedVersion": {"routeVersionId": "route-version-1"},
                "versionRelationship": "current",
                "migrationEligible": false
              }
            }
          }
        }
        """.utf8
    )
}

private struct TestDataEnvelope<Value: Encodable>: Encodable {
    let data: Value
}

private enum TripFixture {
    static func data(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: TripDataAccessTests.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ name: String) throws -> T {
        try APIJSONDecoder.make().decode(T.self, from: data(name))
    }
}
