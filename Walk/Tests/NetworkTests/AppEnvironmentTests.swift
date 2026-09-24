import XCTest
import WalkData
import WalkDesignSystem
@testable import Walk

final class AppEnvironmentTests: XCTestCase {
    private let testURL = "https://api.example.test/v1"

    /// W0 红测：启动参数确定性选择模式，优先于环境变量。
    func testDebugMockLaunchModeOverridesRemoteEnvironment() throws {
        let configuration = try AppConfiguration(
            arguments: ["Walk", "-WalkDataMode", "mock"],
            environment: [
                "WALK_DATA_MODE": "real",
                "WALK_ENVIRONMENT": "test",
                "WALK_API_BASE_URL": testURL,
            ],
            bundleInfo: [:],
            isDebugBuild: true
        )
        XCTAssertEqual(configuration.dataMode, .mock)
    }

    /// W0 红测：原断言为 `.remote`，会丢失 remoteOnly 语义，与 R-MODE 冲突；
    /// W2 修正为断言 `.remoteOnly`。
    func testDebugRemoteOnlyLaunchModeOverridesMockEnvironment() throws {
        let configuration = try AppConfiguration(
            arguments: ["Walk", "-WalkDataMode", "remoteOnly"],
            environment: [
                "WALK_DATA_MODE": "mock",
                "WALK_ENVIRONMENT": "test",
                "WALK_API_BASE_URL": testURL,
            ],
            bundleInfo: [:],
            isDebugBuild: true
        )
        XCTAssertEqual(configuration.dataMode, .remoteOnly)
    }

    func testConfigurationReadsExplicitModeAndInjectedBaseURL() throws {
        let configuration = try AppConfiguration(
            arguments: [
                "Walk",
                "-WalkDataMode", "real",
                "-APIBaseURL", testURL,
                "-WalkEnvironment", "test",
            ],
            environment: [:],
            bundleInfo: ["WalkEnvironment": "production"],
            isDebugBuild: true
        )

        XCTAssertEqual(configuration.dataMode, .real)
        XCTAssertEqual(configuration.baseURL.absoluteString, testURL)
        XCTAssertEqual(configuration.environmentName, "test")
    }

    /// 构建配置未设置模式时代码默认值为 real，绝不默认 Mock。
    func testConfigurationWithoutBuildSettingsNeverDefaultsToMock() throws {
        let configuration = try AppConfiguration(
            arguments: ["Walk"],
            environment: [:],
            bundleInfo: ["WalkAPIBaseURL": testURL, "WalkEnvironment": "development"],
            isDebugBuild: true
        )
        XCTAssertEqual(configuration.dataMode, .real)
    }

    func testDevelopmentAndTestConfigurationsAllowExplicitMock() throws {
        for environmentName in ["development", "test"] {
            let configuration = try AppConfiguration(
                arguments: ["Walk"],
                environment: [:],
                bundleInfo: [
                    "WalkAPIBaseURL": "https://api.example.invalid/walkbg/api/v1",
                    "WalkDataMode": "mock",
                    "WalkEnvironment": environmentName,
                ],
                isDebugBuild: true
            )

            XCTAssertEqual(configuration.dataMode, .mock)
            XCTAssertEqual(configuration.environmentName, environmentName)
        }
    }

    func testEnvironmentAssemblesEveryDataMode() throws {
        for mode in WalkDataMode.allCases {
            let configuration = AppConfiguration(
                dataMode: mode,
                baseURL: URL(string: testURL)!,
                environmentName: "test"
            )
            let environment = try AppEnvironment(configuration: configuration)

            XCTAssertEqual(environment.configuration.dataMode, mode)
            XCTAssertNotNil(environment.personalTripService)
            XCTAssertNotNil(environment.tripEquipmentService)
            XCTAssertNotNil(environment.accountService)
        }
    }

    func testEnvironmentRejectsDirectlyInjectedUnsafeProductionConfiguration() {
        let configuration = AppConfiguration(
            dataMode: .mock,
            baseURL: URL(string: "https://api.example.invalid/v1")!,
            environmentName: "production"
        )

        XCTAssertThrowsError(try AppEnvironment(configuration: configuration)) { error in
            XCTAssertEqual(error as? AppConfigurationError, .productionRequiresRealNetwork)
        }
    }

    func testMockEnvironmentLoadsDefaultPublicRouteFixtures() async throws {
        let configuration = AppConfiguration(
            dataMode: .mock,
            baseURL: URL(string: testURL)!,
            environmentName: "test"
        )
        let environment = try AppEnvironment(
            configuration: configuration,
            resourceBundle: Bundle(for: AppEnvironmentTests.self)
        )

        let featured = try await environment.routeService.getFeaturedRoutes()
        let all = try await environment.routeService.getRoutes()
        let search = try await environment.routeService.searchRoutes(query: "长海子")
        let route = try await environment.routeService.getRouteDetail(id: "quye-141")
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
        XCTAssertEqual(route.routeId, "quye-141")
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
