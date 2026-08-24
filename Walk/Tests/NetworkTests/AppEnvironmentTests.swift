import XCTest
@testable import Walk

final class AppEnvironmentTests: XCTestCase {
    func testConfigurationReadsExplicitModeAndInjectedBaseURL() throws {
        let configuration = try AppConfiguration(
            arguments: ["Walk", "-DataSourceMode", "local", "-APIBaseURL", "https://api.example.test/v1"],
            environment: [:]
        )

        XCTAssertEqual(configuration.dataSourceMode, .local)
        XCTAssertEqual(configuration.baseURL.absoluteString, "https://api.example.test/v1")
    }

    func testConfigurationDefaultsToMockButStillRequiresBaseURL() {
        XCTAssertThrowsError(try AppConfiguration(
            arguments: ["Walk"],
            environment: [:],
            bundleInfo: [:]
        ))

        let configuration = try? AppConfiguration(
            arguments: ["Walk"],
            environment: [:],
            bundleInfo: ["WalkAPIBaseURL": "https://api.example.test/v1"]
        )
        XCTAssertEqual(configuration?.dataSourceMode, .mock)
    }

    func testConfigurationUsesArchiveBundleValuesWithoutSchemeEnvironment() throws {
        let configuration = try AppConfiguration(
            arguments: ["Walk"],
            environment: [:],
            bundleInfo: [
                "WalkAPIBaseURL": "https://api.example.test/walkbg/api/v1",
                "WalkDataSourceMode": "remote",
                "WalkEnvironment": "production",
            ]
        )

        XCTAssertEqual(configuration.baseURL.absoluteString, "https://api.example.test/walkbg/api/v1")
        XCTAssertEqual(configuration.dataSourceMode, .remote)
        XCTAssertEqual(configuration.environmentName, "production")
    }

    func testEnvironmentAssemblesExactlyConfiguredClientAndRepository() throws {
        for mode in DataSourceMode.allCases {
            let configuration = AppConfiguration(
                dataSourceMode: mode,
                baseURL: URL(string: "https://api.example.test/v1")!,
                environmentName: "test",
                userID: "anonymous"
            )
            let environment = try AppEnvironment(configuration: configuration)

            XCTAssertEqual(environment.configuration.dataSourceMode, mode)
            XCTAssertNotNil(environment.tripRepository)
        }
    }

    func testMockEnvironmentLoadsDefaultFixturesForConfiguredUserID() async throws {
        let configuration = AppConfiguration(
            dataSourceMode: .mock,
            baseURL: URL(string: "https://api.example.test/v1")!,
            environmentName: "test",
            userID: "custom-user"
        )
        let environment = try AppEnvironment(
            configuration: configuration,
            resourceBundle: Bundle(for: AppEnvironmentTests.self)
        )

        let page = try await environment.tripRepository.fetchTrips()
        let trip = try await environment.tripRepository.fetchTrip(id: try XCTUnwrap(page.items.first?.id))

        for routeID in ["route-1", "route_001", "route_002", "route_003"] {
            let route = try await environment.routeService.getRouteDetailResponse(id: routeID)
            try await environment.routeService.setFavorite(routeID: routeID, isFavorite: true)
            try await environment.routeService.setFavorite(routeID: routeID, isFavorite: false)
            XCTAssertEqual(route.id, routeID)
        }

        XCTAssertFalse(page.items.isEmpty)
        XCTAssertEqual(trip.id, page.items.first?.id)
    }
}
