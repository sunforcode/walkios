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

    func testTripRequestsMatchControllerContractAndStoragePolicy() throws {
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
        XCTAssertEqual(list.path, "/trips")
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: list.query.map { ($0.name, $0.value ?? "") })["status"], "2")
        XCTAssertEqual(list.storagePolicy, .none)

        XCTAssertEqual(TripAPI.Detail(id: "trip-1").storagePolicy, .store)
        XCTAssertEqual(TripAPI.Detail(id: "trip-1").path, "/trips/trip-1")
        XCTAssertEqual(TripAPI.Delete(id: "trip-1").method, .delete)
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
