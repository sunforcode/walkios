import XCTest
@testable import Walk

@MainActor
final class ProfileViewModelTests: XCTestCase {
    private var repository: ProfileTripRepositoryStub!
    private var authSession: AuthSessionStub!
    private var didClearCache = false
    private var authWasLoggedOutBeforeCacheClear = false
    private var sut: ProfileViewModel!

    override func setUp() {
        super.setUp()
        repository = ProfileTripRepositoryStub(totalElements: 3)
        authSession = AuthSessionStub(isLoggedIn: false)
        didClearCache = false
        authWasLoggedOutBeforeCacheClear = false
        sut = ProfileViewModel(
            tripRepository: repository,
            authSession: authSession,
            loadUser: { MockData.user },
            clearCachedResponses: { [weak self] in
                guard let self else { return }
                self.authWasLoggedOutBeforeCacheClear = !self.authSession.isLoggedIn
                self.didClearCache = true
            }
        )
    }

    override func tearDown() {
        sut = nil
        authSession = nil
        repository = nil
        super.tearDown()
    }

    func testInitialState_UserShouldBeNil() {
        XCTAssertNil(sut.user)
    }

    func testInitialState_IsLoggedInShouldBeFalse() {
        XCTAssertFalse(sut.isLoggedIn)
    }

    func testLoadProfileUsesInjectedTripRepository() async {
        await sut.loadProfile()

        XCTAssertEqual(sut.tripCount, 3)
        XCTAssertEqual(repository.fetchTripsCallCount, 1)
        XCTAssertNil(sut.user)
    }

    func testLogout_ShouldClearUserDataAndSession() async {
        sut.user = MockData.user
        sut.isLoggedIn = true
        sut.tripCount = 5

        await sut.logout()

        XCTAssertTrue(didClearCache)
        XCTAssertTrue(authWasLoggedOutBeforeCacheClear)
        XCTAssertTrue(authSession.didLogout)
        XCTAssertNil(sut.user)
        XCTAssertFalse(sut.isLoggedIn)
        XCTAssertEqual(sut.tripCount, 0)
    }
}

private final class AuthSessionStub: AuthSession {
    var isLoggedIn: Bool
    var cacheIdentity = "test-user"
    var didLogout = false

    init(isLoggedIn: Bool) {
        self.isLoggedIn = isLoggedIn
    }

    func logout() {
        didLogout = true
        isLoggedIn = false
    }
}

private final class ProfileTripRepositoryStub: TripRepository {
    private let totalElements: Int
    private(set) var fetchTripsCallCount = 0

    init(totalElements: Int) {
        self.totalElements = totalElements
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
        return Page(
            items: [],
            number: page,
            size: size,
            totalElements: totalElements,
            totalPages: totalElements == 0 ? 0 : 1,
            first: true,
            last: true
        )
    }

    func fetchTrip(id: String) async throws -> Trip { throw APIClientError.localDataNotFound }
    func createTrip(_ input: TripCreateRequestDTO) async throws -> Trip { throw APIClientError.localDataNotFound }
    func updateTrip(id: String, input: TripUpdateRequestDTO) async throws -> Trip { throw APIClientError.localDataNotFound }
    func updateTripStatus(id: String, status: TripStatus) async throws -> Trip { throw APIClientError.localDataNotFound }
    func deleteTrip(id: String) async throws {}
}
