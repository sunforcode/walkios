import XCTest
@testable import Walk

@MainActor
final class HomeAndRootViewModelTests: XCTestCase {
    func testHomeStateStartsLoading() {
        let sut = makeHomeViewModel(selectedRouteID: nil)
        XCTAssertEqual(sut.state, .loading)
    }

    func testMissingSelectedRouteBecomesEmptyWithoutLoadingRoute() async {
        let recorder = RouteIDRecorder()
        let sut = makeHomeViewModel(selectedRouteID: nil, loadedRouteIDs: recorder)

        await sut.load()

        XCTAssertEqual(sut.state, .empty)
        XCTAssertTrue(recorder.values.isEmpty)
    }

    func testSelectedRouteIDLoadsRouteAndShowsRouteHome() async {
        let recorder = RouteIDRecorder()
        let sut = makeHomeViewModel(selectedRouteID: "route-1", loadedRouteIDs: recorder)

        await sut.load()

        XCTAssertEqual(recorder.values, ["route-1"])
        XCTAssertEqual(sut.state, .ready(route: Self.route, weather: nil))
    }

    func testWeatherSummaryIsLoadedForSelectedRoute() async {
        let weather = HomeWeatherSummary(
            precipitationProbability: 20,
            windSpeed: 12,
            minimumTemperature: 8,
            maximumTemperature: 16
        )
        let sut = HomeViewModel(
            loadSelectedRouteID: { "route-1" },
            loadRoute: { _ in Self.route },
            loadWeather: { route, _ in
                XCTAssertEqual(route.id, Self.route.id)
                return weather
            }
        )

        await sut.load()

        XCTAssertEqual(sut.state, .ready(route: Self.route, weather: weather))
    }

    func testSelectRoutePersistsAndImmediatelyUpdatesHome() async {
        var savedRouteID: String?
        let sut = HomeViewModel(
            loadSelectedRouteID: { nil },
            saveSelectedRouteID: { savedRouteID = $0 },
            loadRoute: { _ in Self.route }
        )
        await sut.load()

        await sut.selectRoute(Self.route)

        XCTAssertEqual(savedRouteID, Self.route.id)
        XCTAssertEqual(sut.state, .ready(route: Self.route, weather: nil))
    }

    func testRouteFailureMapsToErrorInsteadOfInventingRouteContent() async {
        let sut = HomeViewModel(
            loadSelectedRouteID: { "route-1" },
            loadRoute: { _ in throw TestError.unavailable }
        )

        await sut.load()

        guard case let .error(message) = sut.state else {
            return XCTFail("Expected route error state")
        }
        XCTAssertTrue(message.contains("当前路线加载失败"))
    }

    func testHomeLayoutMatchesFlutterReference() {
        XCTAssertEqual(HomeLayout.heroHorizontalPadding, 20)
        XCTAssertEqual(HomeLayout.emptyHorizontalPadding, 28)
        XCTAssertEqual(HomeLayout.emptyBrandSize, 42)
        XCTAssertEqual(HomeLayout.emptyPromptSize, 20)
        XCTAssertEqual(HomeLayout.emptyCTAHorizontalPadding, 48)
        XCTAssertEqual(HomeLayout.weatherHorizontalPadding, 20)
        XCTAssertEqual(HomeLayout.weatherVerticalPadding, 16)
        XCTAssertEqual(HomeLayout.weatherBottomOffset, 100)
        XCTAssertEqual(HomeLayout.changeRouteBottomOffset, 200)
        XCTAssertEqual(HomeLayout.compactHeightThreshold, 600)
    }

    func testUpcomingHikingDateIsNextSaturdayIncludingToday() {
        let calendar = Calendar(identifier: .gregorian)
        let monday = calendar.date(from: DateComponents(year: 2026, month: 8, day: 24))!
        let saturday = HomeViewModel.upcomingHikingDate(from: monday, calendar: calendar)

        XCTAssertEqual(calendar.component(.weekday, from: saturday), 7)
        XCTAssertEqual(calendar.dateComponents([.day], from: monday, to: saturday).day, 5)
    }

    func testLoggedOutDrawerDisplayDoesNotLoadUser() async {
        var didLoadUser = false
        let sut = RootViewModel(
            isLoggedIn: { false },
            loadUser: {
                didLoadUser = true
                return Self.user
            }
        )

        await sut.loadDrawerUser()

        XCTAssertEqual(sut.drawerUserDisplay, .loggedOut)
        XCTAssertEqual(sut.drawerUserDisplay.title, "未登录")
        XCTAssertEqual(sut.drawerUserDisplay.subtitle, "登录后查看个人主页")
        XCTAssertEqual(RootNavigation.profileDestination, .profile)
        XCTAssertFalse(didLoadUser)
    }

    private func makeHomeViewModel(
        selectedRouteID: String?,
        loadedRouteIDs: RouteIDRecorder = RouteIDRecorder()
    ) -> HomeViewModel {
        HomeViewModel(
            loadSelectedRouteID: { selectedRouteID },
            loadRoute: { routeID in
                loadedRouteIDs.values.append(routeID)
                return Self.route
            }
        )
    }

    private final class RouteIDRecorder {
        var values: [String] = []
    }

    private enum TestError: Error { case unavailable }

    private static let route = Route(
        id: "route-1", name: "测试路线", description: nil, category: nil,
        difficulty: nil, distance: 10, duration: 1, elevation: 200,
        routeType: nil, coverImageUrl: nil, createdAt: nil
    )

    private static let user = User(
        id: "user-1", username: "walker", email: nil,
        avatarUrl: nil, createdAt: nil
    )
}
