import Foundation
import XCTest
@testable import WalkData

final class YadingMockFixtureTests: XCTestCase {
    func testYadingRouteIsAddedWithoutReplacingExistingDiscovery() throws {
        let fixtures = DefaultMockFixtures.all()
        let browseData = try XCTUnwrap(fixtures[PublicRouteAPI.All().identifier])
        let browse = try APIJSONDecoder.decode(PublicRouteCollectionResult.self, from: browseData, envelope: .data)
        XCTAssertTrue(browse.items.contains { $0.routeId == "quye-141" })
        XCTAssertTrue(browse.items.contains { $0.routeId == "route-yading-5d" })
        let data = try XCTUnwrap(fixtures[PublicRouteAPI.Detail(id: "route-yading-5d").identifier])
        let route = try APIJSONDecoder.decode(PublicRouteDetail.self, from: data, envelope: .data)
        XCTAssertEqual(route.currentVersion.versionId, "route-yading-5d-v1")
        XCTAssertEqual(route.currentVersion.referenceDays?.count, 5)
    }

    func testOriginalTrackAndMarkersArePreservedWithoutPersonalPhotoMetadata() throws {
        let source = try XCTUnwrap(YadingMockFixtures.payload["source"] as? [String: Any])
        let track = try XCTUnwrap(source["trackPath"] as? [[Double]])
        let markers = try XCTUnwrap(source["markers"] as? [[String: Any]])
        XCTAssertEqual(track.count, 36_838)
        XCTAssertEqual(markers.count, 152)
        XCTAssertEqual(track[740], [28.41662, 100.383638, 4131.833446])
        XCTAssertTrue(markers.contains { $0["name"] as? String == "松多垭口（下方一点就有信号）" })
        let encoded = try JSONSerialization.data(withJSONObject: YadingMockFixtures.payload)
        let text = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        XCTAssertFalse(text.contains("<img"))
        XCTAssertFalse(text.contains("source_kml_url"))
        XCTAssertFalse(text.contains("/Users/"))
    }

    func testTrackProfileAndAllFiveDailyPathsUseTheSameSourceIndices() async throws {
        let client = DefaultMockEquipmentScenario()
        let route = try await client.execute(PublicRouteAPI.Detail(id: "route-yading-5d"))
        let detail = try await client.execute(PersonalTripAPI.Detail(tripID: "trip-yading-5d"))
        let routePath = try XCTUnwrap(route.currentVersion.mainTrack?.path)
        let profile = try XCTUnwrap(detail.trip.frozenRouteBasis.elevationProfile)
        XCTAssertEqual(routePath, detail.trip.frozenRouteBasis.mainTrackPath)
        XCTAssertEqual(routePath.count, profile.samples.count)
        XCTAssertEqual(route.currentVersion.elevationProfile?.samples.count, profile.samples.count)
        XCTAssertTrue(zip(profile.samples, profile.samples.dropFirst()).allSatisfy { $0.distance.meters < $1.distance.meters })
        XCTAssertEqual(profile.minElevation.meters, profile.samples.map(\.elevation.meters).min())
        XCTAssertEqual(profile.maxElevation.meters, profile.samples.map(\.elevation.meters).max())

        let source = try XCTUnwrap(YadingMockFixtures.payload["source"] as? [String: Any])
        let original = try XCTUnwrap(source["trackPath"] as? [[Double]])
        let indices = try XCTUnwrap(source["sampledSourceIndices"] as? [Int])
        XCTAssertEqual(indices.count, routePath.count)
        for (sampleIndex, originalIndex) in indices.enumerated() {
            XCTAssertEqual(routePath[sampleIndex].latitude, original[originalIndex][0])
            XCTAssertEqual(routePath[sampleIndex].longitude, original[originalIndex][1])
            XCTAssertEqual(profile.samples[sampleIndex].elevation.meters, original[originalIndex][2])
        }
        let originalRanges = [0...3746, 3747...11018, 11019...19199, 19200...26618, 26619...36837]
        let referenceDays = try XCTUnwrap(route.currentVersion.referenceDays)
        for (dayIndex, day) in detail.days.enumerated() {
            let range = try XCTUnwrap(referenceDays[dayIndex].mainTrackRange)
            let start = range.startPathPosition.precedingPositionIndex
            let end = range.endPathPosition.precedingPositionIndex
            XCTAssertEqual(indices[start], originalRanges[dayIndex].lowerBound)
            XCTAssertEqual(indices[end], originalRanges[dayIndex].upperBound)
            let hike = try XCTUnwrap(day.actions.first { $0.actionType == "hike" })
            let hikeStart = dayIndex == 0 ? try XCTUnwrap(indices.firstIndex(of: 740)) : start
            XCTAssertEqual(hike.routeSectionSnapshot?.path, Array(routePath[hikeStart...end]))
            if dayIndex > 0 {
                let previous = try XCTUnwrap(referenceDays[dayIndex - 1].mainTrackRange)
                XCTAssertGreaterThan(start, previous.endPathPosition.precedingPositionIndex)
            }
        }
    }

    func testFirstDaySeparatesUnverifiedTransportFromHikingAndUsesAlgorithmDuration() async throws {
        let detail = try await DefaultMockEquipmentScenario().execute(PersonalTripAPI.Detail(tripID: "trip-yading-5d"))
        let first = try XCTUnwrap(detail.days.first)
        XCTAssertEqual(first.actions.map(\.actionType), ["route_transfer", "hike"])
        XCTAssertTrue(first.actions[0].mode?.value?.contains("电瓶车") == true)
        XCTAssertNil(first.actions[0].keyTimes?.value)
        XCTAssertNil(first.actions[0].estimatedDuration?.value)
        let hike = first.actions[1]
        XCTAssertEqual(hike.routeSectionSnapshot?.start.name, "圣水门")
        XCTAssertEqual(hike.distance?.value?.meters, 4_000)
        XCTAssertEqual(hike.distance?.confidence?.status, "preliminary")
        XCTAssertNil(hike.estimatedDuration?.value)
        XCTAssertEqual(hike.estimatedDuration?.confidence?.status, "unavailable")
        XCTAssertEqual(detail.trip.frozenRouteBasis.distance?.meters, 69_150)
        XCTAssertEqual(detail.trip.frozenRouteBasis.estimatedDuration.seconds, 1_576 * 60)
        for (day, minutes) in zip(detail.days.dropFirst(), [249, 380, 284, 405]) {
            XCTAssertEqual(day.actions.first?.estimatedDuration?.value?.seconds, Double(minutes * 60))
        }
        XCTAssertTrue(detail.trip.importantNotices?.allSatisfy { $0.content.confidence?.status == "pending_verification" } == true)
    }

    func testTripEndpointsAgreeOnDatesRevisionDaysWeatherAndReadonlyEquipment() async throws {
        let client = DefaultMockEquipmentScenario()
        let detail = try await client.execute(PersonalTripAPI.Detail(tripID: "trip-yading-5d"))
        let days = try await client.execute(PersonalTripAPI.Days(tripID: "trip-yading-5d"))
        let weather = try await client.execute(PersonalTripAPI.Weather(tripID: "trip-yading-5d"))
        let equipment = try await client.execute(TripEquipmentAPI.Current(tripID: "trip-yading-5d"))
        let version = try await client.execute(PersonalTripAPI.RouteVersionStatus(tripID: "trip-yading-5d"))
        XCTAssertEqual(days.days, detail.days)
        XCTAssertEqual(days.revision, detail.revision)
        XCTAssertEqual(weather.revision, detail.revision)
        XCTAssertEqual(equipment.revision, detail.revision)
        XCTAssertEqual(version, detail.routeVersionStatus)
        XCTAssertEqual(equipment.snapshot.summary, detail.equipmentSnapshot.summary)
        XCTAssertEqual(equipment.snapshot.identity, detail.equipmentSnapshot.snapshotID)
        XCTAssertFalse(equipment.editable)
        XCTAssertTrue(PersonalTripWeatherValidator.isValid(weather, tripID: detail.trip.identity, revision: detail.revision))
        XCTAssertEqual(weather.days.map(\.tripDayID), detail.days.map(\.identity))
        XCTAssertEqual(weather.days.map(\.date), detail.days.map(\.date))
        XCTAssertTrue(weather.days.allSatisfy { $0.weatherAssociations.allSatisfy { $0.forecast == nil && $0.forecastConfidence?.status == "unavailable" } })
        XCTAssertEqual(detail.trip.startDate, LocalDate(year: 2026, month: 10, day: 1))
        XCTAssertEqual(detail.trip.endDate, LocalDate(year: 2026, month: 10, day: 5))
    }

    func testEveryHikeHasQualifiedEndpointsMatchingItsSnapshot() async throws {
        let detail = try await DefaultMockEquipmentScenario().execute(PersonalTripAPI.Detail(tripID: "trip-yading-5d"))
        for day in detail.days {
            let hike = try XCTUnwrap(day.actions.first { $0.actionType == "hike" })
            let start = try XCTUnwrap(hike.start?.value)
            let end = try XCTUnwrap(hike.end?.value)
            XCTAssertEqual(start.name, hike.routeSectionSnapshot?.start.name)
            XCTAssertEqual(end.name, hike.routeSectionSnapshot?.end.name)
            XCTAssertEqual(hike.start?.confidence?.status, "pending_verification")
            XCTAssertEqual(hike.end?.confidence?.status, "pending_verification")
        }
    }

    func testYadingCanBeFoundWithoutReplacingFocusAndCalendar() async throws {
        let client = DefaultMockEquipmentScenario()
        let focus = try await client.execute(PersonalTripAPI.Focus())
        XCTAssertEqual(focus.trip?.tripID, "trip-1")
        let trips = try await client.execute(PersonalTripAPI.Collection())
        XCTAssertEqual(Set(trips.currentTrips.map(\.tripID)), ["trip-1", "trip-yading-5d"])
        let calendar = try await client.execute(PersonalTripAPI.Calendar())
        XCTAssertTrue(calendar.days.contains { $0.date == LocalDate(year: 2026, month: 8, day: 25) })
        XCTAssertTrue(calendar.days.contains { $0.date == LocalDate(year: 2026, month: 10, day: 5) })
        for term in ["亚丁", " 亚丁5日 ", "亚丁５日", "稻城"] {
            let search = try await client.execute(PublicRouteAPI.Search(query: term))
            XCTAssertEqual(search.items.map(\.routeId), ["route-yading-5d"])
        }
        let missing = try await client.execute(PublicRouteAPI.Search(query: "不存在的路线"))
        XCTAssertTrue(missing.items.isEmpty)
        let old = try await client.execute(PublicRouteAPI.Search(query: "长海子"))
        XCTAssertEqual(old.items.map(\.routeId), ["quye-141"])
    }

    func testCreateDispatchesByBodyAndReadonlyEquipmentDoesNotChangeGongga() async throws {
        let client = DefaultMockEquipmentScenario()
        let context = try await client.execute(PersonalTripAPI.GenerationContext(routeID: "route-yading-5d"))
        XCTAssertEqual(context.route.currentPublicRouteVersionID, "route-yading-5d-v1")
        for (routeID, versionID, expectedTripID) in [("route-yading-5d", "route-yading-5d-v1", "trip-yading-5d"), ("route-1", "route-1-v1", "trip-1")] {
            let request = try PersonalTripAPI.Create(input: .init(routeID: routeID, routeVersionID: versionID, departureCity: "香格里拉镇", startDate: .init(year: 2026, month: 10, day: 1), equipmentListID: nil, transportSelection: nil), idempotencyKey: routeID)
            guard case .tripCreated(let created) = try await client.execute(request) else { return XCTFail("Expected a created mock trip") }
            XCTAssertEqual(created.trip.identity, expectedTripID)
        }
        let before = try await client.execute(TripEquipmentAPI.Current(tripID: "trip-1"))
        let request = try TripEquipmentAPI.CreateItem(tripID: "trip-yading-5d", input: .init(name: "测试帽", quantity: 1), revision: "revision-yading-1")
        do {
            _ = try await client.execute(request)
            XCTFail("Readonly Yading equipment must reject writes")
        } catch APIClientError.api(let code, _, _, _) {
            XCTAssertEqual(code, "trip_equipment_read_only")
        }
        let after = try await client.execute(TripEquipmentAPI.Current(tripID: "trip-1"))
        XCTAssertEqual(before, after)
    }

    func testSearchWirePayloadUsesOnlySearchFields() throws {
        let fixtures = DefaultMockFixtures.all()
        let allowed = Set(["routeId", "currentVersionId", "cover", "name", "region", "difficulty", "distance", "estimatedDuration"])
        for data in [try XCTUnwrap(fixtures[PublicRouteAPI.Search(query: "亚丁").identifier]), try XCTUnwrap(fixtures[PublicRouteAPI.Search(query: "长海子").identifier]), YadingMockFixtures.searchResponse(query: "长海子", fixtures: fixtures)] {
            let items = try XCTUnwrap(YadingMockFixtures.object(data)["items"] as? [[String: Any]])
            XCTAssertFalse(items.isEmpty)
            XCTAssertTrue(items.allSatisfy { Set($0.keys).isSubset(of: allowed) })
        }
    }

    func testCreateRebasesEveryTripProjectionAndDoesNotMutateSeedOrGongga() async throws {
        let client = DefaultMockEquipmentScenario()
        let input = PersonalTripCreateRequest(routeID: "route-yading-5d", routeVersionID: "route-yading-5d-v1", departureCity: "成都", startDate: .init(year: 2026, month: 8, day: 25), equipmentListID: nil, transportSelection: nil)
        let request = try PersonalTripAPI.Create(input: input, idempotencyKey: "different-start")
        guard case .tripCreated(let created) = try await client.execute(request) else { return XCTFail("Expected created trip") }
        XCTAssertEqual(created.trip.startDate, input.startDate)
        XCTAssertEqual(created.trip.endDate, .init(year: 2026, month: 8, day: 29))
        XCTAssertEqual(created.trip.departureCity, "成都")
        let detail = try await client.execute(PersonalTripAPI.Detail(tripID: "trip-yading-5d"))
        let days = try await client.execute(PersonalTripAPI.Days(tripID: "trip-yading-5d"))
        let weather = try await client.execute(PersonalTripAPI.Weather(tripID: "trip-yading-5d"))
        let equipment = try await client.execute(TripEquipmentAPI.Current(tripID: "trip-yading-5d"))
        XCTAssertEqual(detail, created)
        XCTAssertEqual(days.startDate, input.startDate)
        XCTAssertEqual(days.days, created.days)
        XCTAssertEqual(weather.days.map(\.date), created.days.map(\.date))
        XCTAssertEqual(equipment.trip.startDate, input.startDate)
        XCTAssertTrue(PersonalTripWeatherValidator.isValid(weather, tripID: "trip-yading-5d", revision: detail.revision))
        let collection = try await client.execute(PersonalTripAPI.Collection())
        XCTAssertEqual(collection.currentTrips.first { $0.tripID == "trip-yading-5d" }?.startDate, input.startDate)
        XCTAssertEqual(collection.currentTrips.first { $0.tripID == "trip-1" }?.name, "贡嘎环线三日计划")
        let seed = try await DefaultMockEquipmentScenario().execute(PersonalTripAPI.Detail(tripID: "trip-yading-5d"))
        XCTAssertEqual(seed.trip.startDate, .init(year: 2026, month: 10, day: 1))
        XCTAssertEqual(seed.trip.departureCity, "香格里拉镇")
    }

    func testCalendarUsesFixed365DayWindowAndReaggregatesOnlyIntersectingDates() async throws {
        let client = DefaultMockEquipmentScenario()
        let seed = try await client.execute(PersonalTripAPI.Calendar())
        XCTAssertEqual(seed.windowStartDate, .init(year: 2025, month: 10, day: 6))
        XCTAssertEqual(seed.windowEndDate, .init(year: 2026, month: 10, day: 5))
        XCTAssertEqual(Calendar.business.dateComponents([.day], from: seed.windowStartDate.dateAtStartOfDay!, to: seed.windowEndDate.dateAtStartOfDay!).day, 364)
        let overlapping = try PersonalTripAPI.Create(input: .init(routeID: "route-yading-5d", routeVersionID: "route-yading-5d-v1", departureCity: "成都", startDate: .init(year: 2026, month: 8, day: 25), equipmentListID: nil, transportSelection: nil), idempotencyKey: "overlap")
        _ = try await client.execute(overlapping)
        let calendar = try await client.execute(PersonalTripAPI.Calendar())
        XCTAssertEqual(calendar.windowStartDate, seed.windowStartDate)
        XCTAssertEqual(calendar.windowEndDate, seed.windowEndDate)
        XCTAssertEqual(calendar.days.map(\.tripCount), [2, 2, 2, 1, 1])
        XCTAssertFalse(calendar.days.contains { $0.date.month == 10 })
        let future = try PersonalTripAPI.Create(input: .init(routeID: "route-yading-5d", routeVersionID: "route-yading-5d-v1", departureCity: "成都", startDate: .init(year: 2027, month: 1, day: 1), equipmentListID: nil, transportSelection: nil), idempotencyKey: "future")
        _ = try await client.execute(future)
        let outOfWindow = try await client.execute(PersonalTripAPI.Calendar())
        XCTAssertEqual(outOfWindow.windowEndDate, seed.windowEndDate)
        XCTAssertEqual(outOfWindow.days.count, 3)
        XCTAssertTrue(outOfWindow.days.allSatisfy { $0.tripCount == 1 })
    }

    func testCreateRetriesAndLogoutKeepScenarioStateIsolated() async throws {
        let client = DefaultMockEquipmentScenario()
        let request = try PersonalTripAPI.Create(input: .init(routeID: "route-yading-5d", routeVersionID: "route-yading-5d-v1", departureCity: "成都", startDate: .init(year: 2026, month: 12, day: 30), equipmentListID: nil, transportSelection: nil), idempotencyKey: "retry")
        let first = try await client.execute(request)
        let replay = try await client.execute(request)
        XCTAssertEqual(first, replay)
        let detail = try await client.execute(PersonalTripAPI.Detail(tripID: "trip-yading-5d"))
        XCTAssertEqual(detail.trip.endDate, .init(year: 2027, month: 1, day: 3))
        XCTAssertEqual(detail.days.last?.date, .init(year: 2027, month: 1, day: 3))
        let weather = try await client.execute(PersonalTripAPI.Weather(tripID: "trip-yading-5d"))
        XCTAssertTrue(PersonalTripWeatherValidator.isValid(weather, tripID: detail.trip.identity, revision: detail.revision))
        _ = try await client.execute(AccountAPI.Logout())
        let reset = try await client.execute(PersonalTripAPI.Detail(tripID: "trip-yading-5d"))
        XCTAssertEqual(reset.trip.startDate, .init(year: 2026, month: 10, day: 1))
        XCTAssertEqual(reset.revision, "revision-yading-1")
    }
}
