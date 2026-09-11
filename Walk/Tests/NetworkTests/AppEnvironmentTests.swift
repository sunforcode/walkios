import XCTest
import WalkData
import WalkDesignSystem
@testable import Walk

final class AppEnvironmentTests: XCTestCase {
    func testConfigurationReadsExplicitModeAndInjectedBaseURL() throws {
        let configuration = try AppConfiguration(
            arguments: [
                "Walk",
                "-DataSourceMode", "local",
                "-APIBaseURL", "https://api.example.test/v1",
                "-WalkEnvironment", "test",
            ],
            environment: [:],
            bundleInfo: ["WalkEnvironment": "production"]
        )

        XCTAssertEqual(configuration.dataSourceMode, .local)
        XCTAssertEqual(configuration.baseURL.absoluteString, "https://api.example.test/v1")
        XCTAssertEqual(configuration.environmentName, "test")
    }

    func testConfigurationWithoutBuildSettingsNeverDefaultsToMock() {
        XCTAssertThrowsError(try AppConfiguration(
            arguments: ["Walk"],
            environment: [:],
            bundleInfo: [:]
        )) { error in
            XCTAssertEqual(error as? AppConfigurationError, .missingBaseURL)
        }

        let configuration = try? AppConfiguration(
            arguments: ["Walk"],
            environment: [:],
            bundleInfo: [
                "WalkAPIBaseURL": "https://api.example.test/v1",
                "WalkEnvironment": "development",
            ]
        )
        XCTAssertEqual(configuration?.dataSourceMode, .remote)
    }

    func testProductionConfigurationRejectsMockAndPlaceholderURL() {
        XCTAssertThrowsError(try AppConfiguration(
            arguments: ["Walk"],
            environment: [:],
            bundleInfo: [
                "WalkAPIBaseURL": "https://api.example.test/v1",
                "WalkDataSourceMode": "mock",
                "WalkEnvironment": "production",
            ]
        )) { error in
            XCTAssertEqual(error as? AppConfigurationError, .productionRequiresRemote)
        }

        XCTAssertThrowsError(try AppConfiguration(
            arguments: ["Walk"],
            environment: [:],
            bundleInfo: [
                "WalkAPIBaseURL": "https://api.example.invalid/walkbg/api/v1",
                "WalkDataSourceMode": "remote",
                "WalkEnvironment": "production",
            ]
        )) { error in
            XCTAssertEqual(
                error as? AppConfigurationError,
                .placeholderBaseURL("https://api.example.invalid/walkbg/api/v1")
            )
        }
    }

    func testDevelopmentAndTestConfigurationsAllowExplicitMock() throws {
        for environmentName in ["development", "test"] {
            let configuration = try AppConfiguration(
                arguments: ["Walk"],
                environment: [:],
                bundleInfo: [
                    "WalkAPIBaseURL": "https://api.example.invalid/walkbg/api/v1",
                    "WalkDataSourceMode": "mock",
                    "WalkEnvironment": environmentName,
                ]
            )

            XCTAssertEqual(configuration.dataSourceMode, .mock)
            XCTAssertEqual(configuration.environmentName, environmentName)
        }
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

    func testEnvironmentAssemblesExactlyConfiguredTargetServices() throws {
        for mode in DataSourceMode.allCases {
            let configuration = AppConfiguration(
                dataSourceMode: mode,
                baseURL: URL(string: "https://api.example.test/v1")!,
                environmentName: "test"
            )
            let environment = try AppEnvironment(configuration: configuration)

            XCTAssertEqual(environment.configuration.dataSourceMode, mode)
            XCTAssertNotNil(environment.personalTripService)
            XCTAssertNotNil(environment.tripEquipmentService)
            XCTAssertNotNil(environment.accountService)
        }
    }

    func testEnvironmentRejectsDirectlyInjectedUnsafeProductionConfiguration() {
        let configuration = AppConfiguration(
            dataSourceMode: .mock,
            baseURL: URL(string: "https://api.example.invalid/v1")!,
            environmentName: "production"
        )

        XCTAssertThrowsError(try AppEnvironment(configuration: configuration)) { error in
            XCTAssertEqual(error as? AppConfigurationError, .productionRequiresRemote)
        }
    }

    func testMockEnvironmentLoadsDefaultPublicRouteFixtures() async throws {
        let configuration = AppConfiguration(
            dataSourceMode: .mock,
            baseURL: URL(string: "https://api.example.test/v1")!,
            environmentName: "test"
        )
        let environment = try AppEnvironment(
            configuration: configuration,
            resourceBundle: Bundle(for: AppEnvironmentTests.self)
        )

        let featured = try await environment.routeService.getFeaturedRoutes()
        let all = try await environment.routeService.getRoutes()
        let search = try await environment.routeService.searchRoutes(query: "贡嘎")
        let route = try await environment.routeService.getRouteDetail(id: "route-1")
        let account = try await environment.accountService.currentAccount()
        let focus = try await environment.personalTripService.focus()
        let personalTrips = try await environment.personalTripService.list()
        let tripCalendar = try await environment.personalTripService.calendar()
        let personalTrip = try await environment.personalTripService.detail(tripID: "trip-1")
        let personalTripDays = try await environment.personalTripService.days(tripID: "trip-1")
        let personalTripWeather = try await environment.personalTripService.weather(tripID: "trip-1")
        let tripEquipment = try await environment.tripEquipmentService.getEquipment(tripID: "trip-1")
        let generationContext = try await environment.personalTripService.generationContext(routeID: "route-1")
        let generationResult = try await environment.personalTripService.create(
            PersonalTripCreateRequest(
                routeID: "route-1",
                routeVersionID: "route-1-v1",
                departureCity: "成都",
                startDate: LocalDate(year: 2026, month: 8, day: 25),
                equipmentListID: nil,
                transportSelection: nil
            ),
            idempotencyKey: "mock-create"
        )
        let equipment = try await environment.equipmentService.getPersonalEquipment()
        let equipmentLists = try await environment.equipmentService.getEquipmentLists()

        XCTAssertFalse(featured.items.isEmpty)
        XCTAssertFalse(all.items.isEmpty)
        XCTAssertEqual(search.state, .completed)
        XCTAssertEqual(route.routeId, "route-1")
        XCTAssertEqual(account.account.identity, "account-1")
        XCTAssertEqual(focus.trip?.tripID, "trip-1")
        XCTAssertEqual(personalTrips.currentTrips.map(\.tripID), ["trip-1"])
        XCTAssertEqual(tripCalendar.days.first?.tripCount, 1)
        XCTAssertEqual(personalTrip.trip.identity, "trip-1")
        XCTAssertEqual(personalTripDays.tripID, "trip-1")
        XCTAssertEqual(personalTripWeather.tripID, "trip-1")
        XCTAssertEqual(tripEquipment.trip.identity, "trip-1")
        XCTAssertEqual(tripEquipment.snapshot.identity, "equipment-snapshot-1")
        XCTAssertEqual(generationContext.route.routeID, "route-1")
        guard case .tripCreated(let createdTrip) = generationResult else {
            return XCTFail("Expected mock trip_created result")
        }
        XCTAssertEqual(createdTrip.trip.identity, "trip-1")
        XCTAssertTrue(equipment.items.isEmpty)
        XCTAssertEqual(equipment.summary.knownTotalWeight.grams, 0)
        XCTAssertTrue(equipmentLists.items.isEmpty)
    }
}
