import XCTest
@testable import Walk

@MainActor
final class TripListViewModelTests: XCTestCase {
    func testListViewModelLoadsRepositoryPage() async {
        let repository = TripRepositoryStub(page: Self.page)
        let sut = TripListViewModel(repository: repository)

        await sut.loadTrips()

        XCTAssertEqual(sut.trips, Self.page.items)
        XCTAssertEqual(repository.fetchTripsCallCount, 1)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testListViewModelMapsRepositoryFailure() async {
        let repository = TripRepositoryStub(error: APIClientError.localDataNotFound)
        let sut = TripListViewModel(repository: repository)

        await sut.loadTrips()

        XCTAssertTrue(sut.trips.isEmpty)
        XCTAssertEqual(sut.errorMessage, APIClientError.localDataNotFound.errorDescription)
    }

    func testDetailViewModelLoadsRepositoryTrip() async {
        let repository = TripRepositoryStub(page: Self.page, trip: Self.trip)
        let sut = TripDetailViewModel(repository: repository, loadRoute: { _ in nil })

        await sut.loadTrip(id: Self.trip.id)

        XCTAssertEqual(sut.trip, Self.trip)
        XCTAssertEqual(repository.fetchTripIDs, [Self.trip.id])
        XCTAssertNil(sut.errorMessage)
    }

    private static let trip = Trip(
        id: "trip-1",
        name: "测试行程",
        description: nil,
        status: .planning,
        startDate: nil,
        endDate: nil,
        userId: "owner",
        routeId: "route-1",
        createdAt: nil,
        updatedAt: nil
    )

    private static let page = Page(
        items: [trip],
        number: 0,
        size: 20,
        totalElements: 1,
        totalPages: 1,
        first: true,
        last: true
    )
}

@MainActor
private final class TripRepositoryStub: TripRepository {
    var fetchTripsCallCount = 0
    var fetchTripIDs: [String] = []
    private let page: Page<Trip>?
    private let trip: Trip?
    private let error: Error?

    init(page: Page<Trip>? = nil, trip: Trip? = nil, error: Error? = nil) {
        self.page = page
        self.trip = trip
        self.error = error
    }

    func fetchTrips(
        keyword: String?,
        status: TripStatus?,
        organizerID: String?,
        participantID: String?,
        page: Int,
        size: Int,
        sort: [String]
    ) async throws -> Page<Trip> {
        fetchTripsCallCount += 1
        if let error { throw error }
        return self.page!
    }

    func fetchTrip(id: String) async throws -> Trip {
        fetchTripIDs.append(id)
        if let error { throw error }
        return trip!
    }

    func createTrip(_ input: TripCreateRequestDTO) async throws -> Trip { fatalError("Unused") }
    func updateTrip(id: String, input: TripUpdateRequestDTO) async throws -> Trip { fatalError("Unused") }
    func deleteTrip(id: String) async throws { fatalError("Unused") }
    func updateTripStatus(id: String, status: TripStatus) async throws -> Trip { fatalError("Unused") }
}
