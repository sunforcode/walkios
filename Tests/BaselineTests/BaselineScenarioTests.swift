import XCTest
@testable import Walk

final class BaselineScenarioTests: XCTestCase {
    func testHistoricalScenarioIndexContainsAllFrozenManifestEntries() {
        XCTAssertEqual(BaselineScenario.allCases.count, 54)
        XCTAssertEqual(BaselineScenario.tripDetailScenarios.count, 10)
        XCTAssertEqual(
            BaselineScenario.tripDetailScenarios.map(\.rawValue),
            [
                "page-trip-detail--default-top",
                "page-trip-detail--default-middle",
                "page-trip-detail--default-bottom",
                "page-trip-detail--active",
                "page-trip-detail--done",
                "page-trip-detail--cancelled",
                "page-trip-detail--route-diff",
                "page-trip-detail--migration-failed",
                "page-trip-detail--weather-unavailable",
                "page-trip-detail--transport-unavailable",
            ]
        )
        XCTAssertTrue(BaselineScenario.tripDetailScenarios.allSatisfy {
            $0.pageID == .tripDetail
        })
    }

    func testCurrentTripListScenarioIDsRemainStable() {
        XCTAssertEqual(
            CurrentBaselineScenario.tripListScenarios.map(\.rawValue),
            [
                "page-trips--loaded",
                "page-trips--current-empty",
                "page-trips--history-empty",
                "page-trips--loading",
                "page-trips--global-empty",
                "page-trips--error",
            ]
        )
        XCTAssertEqual(
            CurrentBaselineScenario.tripListScenarios.map(\.pageID),
            Array(repeating: .trips, count: 6)
        )
    }

    func testCurrentScenarioDenominatorMatchesTripListScope() {
        XCTAssertEqual(CurrentBaselineScenario.allCases, CurrentBaselineScenario.tripListScenarios)
        XCTAssertEqual(CurrentBaselineScenario.allCases.count, 6)
        XCTAssertEqual(Set(CurrentBaselineScenario.allCases.map(\.rawValue)).count, 6)
        XCTAssertFalse(CurrentBaselineScenario.allCases.contains { $0.pageID == .tripTransport })
    }

    func testConfigurationParsesExplicitCurrentBaselineScenario() throws {
        let configuration = try AppConfiguration(
            arguments: [
                "Walk",
                "-DataSourceMode", "mock",
                "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
                "-WalkEnvironment", "test",
                "-WalkBaselineScenario", "page-trips--loaded",
            ],
            environment: [:],
            bundleInfo: [:]
        )

        XCTAssertEqual(configuration.baselineScenario, .pageTripsLoaded)
    }

    func testConfigurationRejectsHistoricalTransportScenario() {
        XCTAssertThrowsError(try AppConfiguration(
            arguments: [
                "Walk",
                "-DataSourceMode", "mock",
                "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
                "-WalkEnvironment", "test",
                "-WalkBaselineScenario", "page-trip-transport--default",
            ],
            environment: [:],
            bundleInfo: [:]
        )) { error in
            XCTAssertEqual(
                error as? AppConfigurationError,
                .invalidBaselineScenario("page-trip-transport--default")
            )
        }
    }

    func testConfigurationRejectsUnknownBaselineScenario() {
        XCTAssertThrowsError(try AppConfiguration(
            arguments: [
                "Walk",
                "-DataSourceMode", "mock",
                "-APIBaseURL", "https://api.example.invalid/walkbg/api/v1",
                "-WalkEnvironment", "test",
                "-WalkBaselineScenario", "page-trip-detail--invented",
            ],
            environment: [:],
            bundleInfo: [:]
        )) { error in
            XCTAssertEqual(
                error as? AppConfigurationError,
                .invalidBaselineScenario("page-trip-detail--invented")
            )
        }
    }

    func testConfigurationRestrictsBaselineScenarioToNonProductionMockMode() {
        let remoteConfiguration = AppConfiguration(
            dataSourceMode: .remote,
            baseURL: URL(string: "https://api.example.test/v1")!,
            environmentName: "test",
            baselineScenario: .pageTripsLoaded
        )
        XCTAssertThrowsError(try remoteConfiguration.validate()) { error in
            XCTAssertEqual(error as? AppConfigurationError, .baselineRequiresMock)
        }

        let productionConfiguration = AppConfiguration(
            dataSourceMode: .mock,
            baseURL: URL(string: "https://api.example.test/v1")!,
            environmentName: "production",
            baselineScenario: .pageTripsLoaded
        )
        XCTAssertThrowsError(try productionConfiguration.validate()) { error in
            XCTAssertEqual(error as? AppConfigurationError, .baselineUnavailableInProduction)
        }
    }

    func testReadinessIdentifiersKeepReadyAndUnsupportedSeparate() {
        XCTAssertEqual(
            BaselineReadiness.identifier(for: .pageTripsLoaded, status: .ready),
            "baseline.ready.page-trips--loaded"
        )
        XCTAssertEqual(
            BaselineReadiness.identifier(for: .pageTripsError, status: .unsupported),
            "baseline.unsupported.page-trips--error"
        )
        XCTAssertEqual(
            Set(CurrentBaselineScenario.tripListScenarios.map {
                BaselineReadiness.identifier(for: $0, status: .ready)
            }).count,
            6
        )
    }

    func testTripsFixturesCoverAllTripListScenarios() throws {
        for scenario in CurrentBaselineScenario.tripListScenarios {
            let fixture = try BaselineFixtureProvider.tripListFixture(for: scenario)
            XCTAssertEqual(fixture.scenario, scenario)
        }
    }

    func testHomeWeatherOmittedFixtureIsUnavailable() {
        XCTAssertEqual(HomePreviewFixtures.weatherOmitted.state, .unavailable)
    }

    func testLoadedTripsFixtureCoversAllFourApprovedStatusesInServerGroups() throws {
        let fixture = try BaselineFixtureProvider.tripListFixture(for: .pageTripsLoaded)
        guard case .loaded(let collection) = fixture.state else {
            return XCTFail("Loaded scenario must provide a loaded collection")
        }

        XCTAssertEqual(collection.currentTrips.map(\.status), [.inProgress, .planned])
        XCTAssertEqual(collection.historicalTrips.map(\.status), [.completed, .cancelled])
    }

    func testTripDetailBaselineFixtureUsesFrozenYunlingInputs() throws {
        let fixture = try BaselineFixtureProvider.tripDetailFixture(
            for: .pageTripDetailDefaultTop
        )

        XCTAssertEqual(fixture.detail.trip.identity, BaselineFixtureProvider.tripID)
        XCTAssertEqual(fixture.detail.trip.name, "云岭环线 · 9月12日")
        XCTAssertEqual(fixture.detail.trip.departureCity, "上海")
        XCTAssertEqual(fixture.detail.trip.startDate, LocalDate(year: 2026, month: 9, day: 12))
        XCTAssertEqual(fixture.detail.trip.endDate, LocalDate(year: 2026, month: 9, day: 15))
        XCTAssertEqual(fixture.detail.trip.totalDayCount, 4)
        XCTAssertEqual(fixture.detail.trip.hikingDayCount, 2)
        XCTAssertEqual(fixture.days.days.map(\.dayNumber), [1, 2, 3, 4])
        XCTAssertEqual(fixture.weather.days.count, 4)
        XCTAssertEqual(fixture.detail.trip.frozenRouteBasis.distance?.meters, 12_100)
        XCTAssertEqual(fixture.detail.trip.frozenRouteBasis.ascent?.meters, 600)
        XCTAssertEqual(fixture.detail.trip.frozenRouteBasis.versionLabel, "2026.08")
        XCTAssertEqual(fixture.versionStatus.currentPublicVersion?.versionLabel, "2026.09")
    }

    func testTripDetailStatusScenariosOnlyChangeStatus() throws {
        let expectations: [(BaselineScenario, PersonalTripStatus)] = [
            (.pageTripDetailActive, .inProgress),
            (.pageTripDetailDone, .completed),
            (.pageTripDetailCancelled, .cancelled),
        ]

        for (scenario, expectedStatus) in expectations {
            let fixture = try BaselineFixtureProvider.tripDetailFixture(for: scenario)
            XCTAssertEqual(fixture.detail.trip.status, expectedStatus)
            XCTAssertEqual(fixture.days.days.count, 4)
            XCTAssertEqual(fixture.detail.trip.frozenRouteBasis.routeName, "云岭环线")
        }
    }

    func testUnavailableScenariosCarryExplicitConfidenceInsteadOfInventedContent() throws {
        let weatherFixture = try BaselineFixtureProvider.tripDetailFixture(
            for: .pageTripDetailWeatherUnavailable
        )
        XCTAssertTrue(weatherFixture.weather.days.allSatisfy { day in
            day.weather.condition.value == nil
                && day.weather.condition.confidence?.status == "unavailable"
        })

        let transportFixture = try BaselineFixtureProvider.tripDetailFixture(
            for: .pageTripDetailTransportUnavailable
        )
        let transportActions = transportFixture.days.days
            .flatMap(\.actions)
            .filter { ["long_distance_transport", "route_transfer"].contains($0.actionType) }
        XCTAssertFalse(transportActions.isEmpty)
        XCTAssertTrue(transportActions.allSatisfy {
            $0.mode?.value == nil && $0.mode?.confidence?.status == "unavailable"
        })
    }

    func testTripDetailPresentationHintsMatchFrozenScenarioState() throws {
        XCTAssertEqual(
            try BaselineFixtureProvider.tripDetailFixture(for: .pageTripDetailDefaultTop).presentation,
            TripDetailBaselinePresentation(scrollPosition: .top)
        )
        XCTAssertEqual(
            try BaselineFixtureProvider.tripDetailFixture(for: .pageTripDetailDefaultMiddle).presentation,
            TripDetailBaselinePresentation(scrollPosition: .middle)
        )
        XCTAssertEqual(
            try BaselineFixtureProvider.tripDetailFixture(for: .pageTripDetailDefaultBottom).presentation,
            TripDetailBaselinePresentation(scrollPosition: .bottom)
        )
        XCTAssertEqual(
            try BaselineFixtureProvider.tripDetailFixture(for: .pageTripDetailRouteDiff).presentation,
            TripDetailBaselinePresentation(scrollPosition: .middle, showsVersionDifferences: true)
        )
        XCTAssertEqual(
            try BaselineFixtureProvider.tripDetailFixture(for: .pageTripDetailMigrationFailed).presentation,
            TripDetailBaselinePresentation(
                scrollPosition: .middle,
                migrationErrorMessage: "迁移未完成。原路线版本、逐日安排、装备调整和行程状态均未改变。"
            )
        )
    }
}
