import Foundation
import WalkData
import WalkDesignSystem

struct TripDetailBaselinePresentation: Equatable {
    enum ScrollPosition: Equatable {
        case top
        case middle
        case bottom
    }

    let scrollPosition: ScrollPosition
    let showsVersionDifferences: Bool
    let migrationErrorMessage: String?

    init(
        scrollPosition: ScrollPosition,
        showsVersionDifferences: Bool = false,
        migrationErrorMessage: String? = nil
    ) {
        self.scrollPosition = scrollPosition
        self.showsVersionDifferences = showsVersionDifferences
        self.migrationErrorMessage = migrationErrorMessage
    }
}

struct TripDetailBaselineFixture: Equatable {
    let detail: PersonalTripDetail
    let days: PersonalTripDays
    let weather: LegacyPersonalTripWeather
    let versionStatus: PersonalTripRouteVersionStatus
    let presentation: TripDetailBaselinePresentation
}

enum TripListBaselineState: Equatable {
    case loading
    case loaded(PersonalTripCollection)
    case error(String)
}

struct TripListBaselineFixture: Equatable {
    let scenario: CurrentBaselineScenario
    let state: TripListBaselineState
}

enum BaselineFixtureProviderError: Error, Equatable {
    case unsupportedScenario(BaselineScenario)
}

enum BaselineFixtureProvider {
    static let tripID = "baseline-trip-yunling-2026-09-12"

    static func tripListFixture(
        for scenario: CurrentBaselineScenario
    ) throws -> TripListBaselineFixture {
        let current = [
            tripSummary(id: "baseline-trip-in-progress", status: .inProgress, startDay: 12),
            tripSummary(id: "baseline-trip-planned", status: .planned, startDay: 22),
        ]
        let historical = [
            tripSummary(id: "baseline-trip-completed", status: .completed, startDay: 2),
            tripSummary(id: "baseline-trip-cancelled", status: .cancelled, startDay: 26),
        ]
        let state: TripListBaselineState
        switch scenario {
        case .pageTripsLoaded:
            state = .loaded(PersonalTripCollection(currentTrips: current, historicalTrips: historical))
        case .pageTripsCurrentEmpty:
            state = .loaded(PersonalTripCollection(currentTrips: [], historicalTrips: historical))
        case .pageTripsHistoryEmpty:
            state = .loaded(PersonalTripCollection(currentTrips: current, historicalTrips: []))
        case .pageTripsLoading:
            state = .loading
        case .pageTripsGlobalEmpty:
            state = .loaded(PersonalTripCollection(currentTrips: [], historicalTrips: []))
        case .pageTripsError:
            state = .error("行程加载失败，请重试")
        }
        return TripListBaselineFixture(scenario: scenario, state: state)
    }

    static func tripDetailFixture(
        for scenario: BaselineScenario
    ) throws -> TripDetailBaselineFixture {
        guard BaselineScenario.tripDetailScenarios.contains(scenario) else {
            throw BaselineFixtureProviderError.unsupportedScenario(scenario)
        }

        let status = tripStatus(for: scenario)
        let weatherUnavailable = scenario == .pageTripDetailWeatherUnavailable
        let transportUnavailable = scenario == .pageTripDetailTransportUnavailable
        let revision = "baseline-v1-\(scenario.rawValue)"
        let days = makeDays(
            weatherUnavailable: weatherUnavailable,
            transportUnavailable: transportUnavailable
        )
        let versionStatus = makeVersionStatus(revision: revision, status: status)
        let trip = PersonalTripProjection(
            identity: tripID,
            name: "云岭环线 · 9月12日",
            firstGeneratedAt: Date(timeIntervalSince1970: 1_788_865_200),
            status: status,
            departureCity: "上海",
            startDate: date(12),
            endDate: date(15),
            totalDayCount: 4,
            hikingDayCount: 2,
            frozenRouteBasis: routeBasis,
            weatherOverview: WeatherOverview(
                summary: QualifiedString(
                    value: weatherUnavailable ? nil : "4 天内最高 19°C，徒步首日可能有小雨。",
                    confidence: confidence(weatherUnavailable ? "unavailable" : "available", category: .dynamicExternalInformation)
                )
            ),
            importantNotices: [
                PersonalTripImportantNotice(
                    sequence: 1,
                    type: "verification",
                    content: QualifiedString(
                        value: "返程衔接与沿途补给需要出发前核验；1 件装备为“未确认已有”。",
                        confidence: confidence("pending_verification")
                    )
                )
            ]
        )
        let routeReference = PersonalTripRouteReference(
            routeID: "baseline-route-yunling",
            adoptedRouteVersionID: "baseline-route-yunling-2026.08"
        )
        let detail = PersonalTripDetail(
            revision: revision,
            trip: trip,
            routeReference: routeReference,
            days: days,
            equipmentSnapshot: PersonalTripEquipmentSnapshotReference(
                snapshotID: "baseline-equipment-snapshot",
                summary: equipmentSummary
            ),
            routeVersionStatus: versionStatus
        )
        let dayProjection = PersonalTripDays(
            tripID: tripID,
            revision: revision,
            startDate: date(12),
            endDate: date(15),
            totalDayCount: 4,
            hikingDayCount: 2,
            days: days
        )
        let weatherProjection = LegacyPersonalTripWeather(
            tripID: tripID,
            revision: revision,
            routeName: "云岭环线",
            startDate: date(12),
            endDate: date(15),
            days: days.map {
                PersonalTripWeatherDay(
                    tripDayID: $0.identity,
                    dayNumber: $0.dayNumber,
                    date: $0.date,
                    primaryStage: $0.primaryStage,
                    hikingDayNumber: $0.hikingDayNumber,
                    weather: $0.weather
                )
            },
            weatherOverview: trip.weatherOverview
        )

        return TripDetailBaselineFixture(
            detail: detail,
            days: dayProjection,
            weather: weatherProjection,
            versionStatus: versionStatus,
            presentation: presentation(for: scenario)
        )
    }

    private static func tripStatus(for scenario: BaselineScenario) -> PersonalTripStatus {
        switch scenario {
        case .pageTripDetailActive:
            return .inProgress
        case .pageTripDetailDone:
            return .completed
        case .pageTripDetailCancelled:
            return .cancelled
        default:
            return .planned
        }
    }

    private static func presentation(
        for scenario: BaselineScenario
    ) -> TripDetailBaselinePresentation {
        switch scenario {
        case .pageTripDetailDefaultMiddle:
            return TripDetailBaselinePresentation(scrollPosition: .middle)
        case .pageTripDetailDefaultBottom, .pageTripDetailWeatherUnavailable:
            return TripDetailBaselinePresentation(scrollPosition: .bottom)
        case .pageTripDetailRouteDiff:
            return TripDetailBaselinePresentation(
                scrollPosition: .middle,
                showsVersionDifferences: true
            )
        case .pageTripDetailMigrationFailed:
            return TripDetailBaselinePresentation(
                scrollPosition: .middle,
                migrationErrorMessage: "迁移未完成。原路线版本、逐日安排、装备调整和行程状态均未改变。"
            )
        default:
            return TripDetailBaselinePresentation(scrollPosition: .top)
        }
    }

    private static func tripSummary(
        id: String,
        status: PersonalTripStatus,
        startDay: Int
    ) -> PersonalTripSummary {
        PersonalTripSummary(
            tripID: id,
            revision: "baseline-revision-\(id)",
            name: tripName(for: status),
            status: status,
            routeReference: PersonalTripRouteReference(
                routeID: "baseline-route-\(id)",
                adoptedRouteVersionID: "baseline-route-version-\(id)"
            ),
            routeName: routeName(for: status),
            routeType: "multi_day",
            start: PublicRoutePlace(name: "徒步起点"),
            end: PublicRoutePlace(name: "徒步终点"),
            estimatedDuration: RouteDuration(seconds: 172_800),
            startDate: LocalDate(year: 2026, month: 9, day: startDay),
            endDate: LocalDate(year: 2026, month: 9, day: startDay + 2),
            totalDayCount: 3,
            hikingDayCount: 2,
            versionLabel: "2026.09",
            cover: nil,
            direction: "环线",
            distance: RouteDistance(meters: 32_000),
            ascent: RouteElevationGain(meters: 1_800)
        )
    }

    private static func tripName(for status: PersonalTripStatus) -> String {
        switch status {
        case .planned: "梅里北坡 · 规划中"
        case .inProgress: "云岭环线 · 进行中"
        case .completed: "贡嘎环线 · 已完成"
        case .cancelled: "雨崩环线 · 已取消"
        }
    }

    private static func routeName(for status: PersonalTripStatus) -> String {
        switch status {
        case .planned: "梅里北坡"
        case .inProgress: "云岭环线"
        case .completed: "贡嘎环线"
        case .cancelled: "雨崩环线"
        }
    }

    private static let routeBasis = FrozenRouteBasis(
        routeName: "云岭环线",
        routeType: "multi_day",
        region: "云岭北麓 · 松霞县",
        start: PublicRoutePlace(name: "云栈口"),
        end: PublicRoutePlace(name: "云栈口"),
        estimatedDuration: RouteDuration(seconds: 19_200),
        mainTrackPath: [
            position(30.100, 102.100),
            position(30.112, 102.118),
            position(30.128, 102.141),
            position(30.146, 102.168),
            position(30.161, 102.193),
            position(30.137, 102.174),
            position(30.118, 102.139),
            position(30.100, 102.100),
        ],
        versionLabel: "2026.08",
        cover: nil,
        direction: "云栈口 → 折风垭口 → 星落台营地 → 松雾溪谷 → 云栈口",
        distance: RouteDistance(meters: 12_100),
        ascent: RouteElevationGain(meters: 600),
        descent: RouteElevationLoss(meters: 580),
        maxElevation: RouteElevation(meters: 1_412),
        introduction: "云岭环线绕行北麓山脊，串联垭口、营地与溪谷，全程以徒步为主，适合两天以上的慢节奏穿越。",
        routeOrientation: "自云栈口出发，逆时针经折风垭口、星落台营地与松雾溪谷后回到起点，整体为环线走向。",
        elevationProfile: FrozenRouteElevationProfile(
            minElevation: RouteElevation(meters: 980),
            maxElevation: RouteElevation(meters: 1_412),
            samples: [
                FrozenRouteElevationSample(
                    distance: RouteDistance(meters: 0),
                    elevation: RouteElevation(meters: 980)
                ),
                FrozenRouteElevationSample(
                    distance: RouteDistance(meters: 3_200),
                    elevation: RouteElevation(meters: 1_240)
                ),
                FrozenRouteElevationSample(
                    distance: RouteDistance(meters: 6_400),
                    elevation: RouteElevation(meters: 1_412)
                ),
                FrozenRouteElevationSample(
                    distance: RouteDistance(meters: 9_600),
                    elevation: RouteElevation(meters: 1_150)
                ),
                FrozenRouteElevationSample(
                    distance: RouteDistance(meters: 12_100),
                    elevation: RouteElevation(meters: 980)
                ),
            ]
        )
    )

    private static let equipmentSummary = PersonalTripEquipmentSummary(
        itemCount: 2,
        knownTotalWeight: EquipmentWeight(grams: 900),
        missingWeightItemCount: 0,
        ownedItemCount: 1,
        unconfirmedOwnedItemCount: 1
    )

    private static func makeVersionStatus(
        revision: String,
        status: PersonalTripStatus
    ) -> PersonalTripRouteVersionStatus {
        PersonalTripRouteVersionStatus(
            tripID: tripID,
            tripRevision: revision,
            adoptedVersion: PersonalTripRouteVersionReference(
                routeVersionID: "baseline-route-yunling-2026.08",
                versionLabel: "2026.08"
            ),
            currentPublicVersion: PersonalTripRouteVersionReference(
                routeVersionID: "baseline-route-yunling-2026.09",
                versionLabel: "2026.09"
            ),
            versionRelationship: .newerPublicVersionAvailable,
            migrationEligible: status == .planned,
            difference: PersonalTripRouteVersionDifference(
                minimumComparisonStatus: .complete,
                differences: [
                    difference(
                        category: .scaleDifficultyAndTime,
                        subject: "路线总览",
                        summary: "12.1 km · 爬升 600 m · 约 5 h 20 min → 12.4 km · 爬升 620 m · 约 5 h"
                    ),
                    difference(
                        category: .trackAndSegments,
                        subject: "首日区段",
                        summary: "5.9 km · 爬升 490 m → 6.1 km · 爬升 510 m"
                    ),
                    difference(
                        category: .planningSupportAndSafety,
                        subject: "沿途点位",
                        summary: "新增云脊应急补给柜与营地详情"
                    ),
                ],
                unavailableCategories: [],
                otherRelevantChangeStatus: .none,
                otherRelevantChanges: []
            )
        )
    }

    private static func difference(
        category: PersonalTripRouteDifferenceCategory,
        subject: String,
        summary: String
    ) -> PersonalTripRouteVersionDifferenceItem {
        PersonalTripRouteVersionDifferenceItem(
            category: category,
            changeType: .modified,
            subject: subject,
            summary: summary,
            before: nil,
            after: nil
        )
    }

    private static func makeDays(
        weatherUnavailable: Bool,
        transportUnavailable: Bool
    ) -> [PersonalTripDay] {
        [
            PersonalTripDay(
                identity: "baseline-yunling-d1",
                dayNumber: 1,
                date: date(12),
                primaryStage: "抵达路线",
                hikingDayNumber: nil,
                actions: [transportAction(outbound: true, unavailable: transportUnavailable)],
                weather: weather(0, unavailable: weatherUnavailable),
                points: []
            ),
            PersonalTripDay(
                identity: "baseline-yunling-d2",
                dayNumber: 2,
                date: date(13),
                primaryStage: "徒步第 1 天",
                hikingDayNumber: 1,
                actions: [
                    hikeAction(
                        sequence: 1,
                        name: "云栈口 → 星落台营地",
                        start: "云栈口",
                        end: "星落台营地",
                        distance: 5_900,
                        ascent: 490,
                        duration: 10_800
                    )
                ],
                weather: weather(1, unavailable: weatherUnavailable),
                points: [
                    point(1, "水源", "白石涌泉", 2_200),
                    point(2, "水源", "折风垭口前备用水点", 4_100),
                    point(3, "补给", "云栈口出发补给点", 300),
                    point(4, "补给", "云脊应急补给柜", 5_200),
                    point(5, "营地", "星落台营地", 6_100),
                    point(6, "营地", "杉影避风营地", 6_800),
                ]
            ),
            PersonalTripDay(
                identity: "baseline-yunling-d3",
                dayNumber: 3,
                date: date(14),
                primaryStage: "徒步第 2 天",
                hikingDayNumber: 2,
                actions: [
                    hikeAction(
                        sequence: 1,
                        name: "星落台营地 → 云栈口",
                        start: "星落台营地",
                        end: "云栈口",
                        distance: 6_300,
                        ascent: 110,
                        duration: 7_200
                    )
                ],
                weather: weather(2, unavailable: weatherUnavailable),
                points: [
                    point(1, "水源", "冷杉沟取水点", 4_600),
                    point(2, "水源", "松雾溪谷备用水点", 2_700),
                    point(3, "补给", "云岭南门补给屋", 5_600),
                    point(4, "补给", "云栈口返程补给点", 6_300),
                ]
            ),
            PersonalTripDay(
                identity: "baseline-yunling-d4",
                dayNumber: 4,
                date: date(15),
                primaryStage: "返回出发城市",
                hikingDayNumber: nil,
                actions: [transportAction(outbound: false, unavailable: transportUnavailable)],
                weather: weather(3, unavailable: weatherUnavailable),
                points: []
            ),
        ]
    }

    private static func transportAction(
        outbound: Bool,
        unavailable: Bool
    ) -> PersonalTripAction {
        let unavailableConfidence = confidence("unavailable", category: .dynamicExternalInformation)
        let availableConfidence = confidence("pending_verification", category: .dynamicExternalInformation)
        let fieldConfidence = unavailable ? unavailableConfidence : availableConfidence
        let origin = outbound ? "上海" : "云栈口"
        let destination = outbound ? "云栈口" : "上海"
        return PersonalTripAction(
            sequence: 1,
            actionType: "long_distance_transport",
            origin: QualifiedPlace(
                value: unavailable ? nil : PublicRoutePlace(name: origin),
                confidence: fieldConfidence
            ),
            destination: QualifiedPlace(
                value: unavailable ? nil : PublicRoutePlace(name: destination),
                confidence: fieldConfidence
            ),
            mode: QualifiedString(
                value: unavailable ? nil : (outbound
                    ? "公共交通 + 铁路 + 当地接驳"
                    : "当地接驳 + 铁路 + 市内交通"),
                confidence: fieldConfidence
            ),
            keyTimes: QualifiedStringList(
                value: unavailable ? nil : [outbound ? "07:20—10:10" : "09:10—12:55"],
                confidence: fieldConfidence
            ),
            estimatedDuration: QualifiedDuration(
                value: unavailable ? nil : RouteDuration(seconds: outbound ? 10_200 : 13_500),
                confidence: fieldConfidence
            ),
            transferNotes: QualifiedStringList(
                value: unavailable ? nil : [outbound
                    ? "上海 → 城际交通站 → 路线接驳点 → 云栈口"
                    : "云栈口 → 路线接驳点 → 上海"],
                confidence: fieldConfidence
            ),
            routeSectionSnapshot: nil,
            start: nil,
            end: nil,
            distance: nil,
            ascent: nil
        )
    }

    private static func hikeAction(
        sequence: Int,
        name: String,
        start: String,
        end: String,
        distance: Double,
        ascent: Double,
        duration: Double
    ) -> PersonalTripAction {
        let verified = confidence("verified")
        return PersonalTripAction(
            sequence: sequence,
            actionType: "hike",
            origin: nil,
            destination: nil,
            mode: nil,
            keyTimes: nil,
            estimatedDuration: QualifiedDuration(
                value: RouteDuration(seconds: duration),
                confidence: verified
            ),
            transferNotes: nil,
            routeSectionSnapshot: PersonalTripRouteSectionSnapshot(
                start: PublicRoutePlace(name: start),
                end: PublicRoutePlace(name: end),
                name: name,
                path: nil
            ),
            start: QualifiedPlace(value: PublicRoutePlace(name: start), confidence: verified),
            end: QualifiedPlace(value: PublicRoutePlace(name: end), confidence: verified),
            distance: QualifiedDistance(value: RouteDistance(meters: distance), confidence: verified),
            ascent: QualifiedElevationGain(value: RouteElevationGain(meters: ascent), confidence: verified)
        )
    }

    private static func point(
        _ sequence: Int,
        _ type: String,
        _ name: String,
        _ distance: Double
    ) -> PersonalTripPoint {
        PersonalTripPoint(
            sequence: sequence,
            category: type,
            type: type,
            name: name,
            distance: QualifiedDistance(
                value: RouteDistance(meters: distance),
                confidence: confidence("pending_verification")
            ),
            location: nil,
            details: nil,
            isAlternative: false
        )
    }

    private static func weather(
        _ index: Int,
        unavailable: Bool
    ) -> PersonalTripDayWeather {
        let samples: [(String, Double, Double, String, String)] = [
            ("多云", 10, 18, "降水 30%", "4 级风"),
            ("小雨", 9, 15, "降水 60%", "3 级风"),
            ("阴", 8, 16, "降水 25%", "2 级风"),
            ("多云转晴", 11, 19, "降水 15%", "2 级风"),
        ]
        let sample = samples[index]
        let status = unavailable ? "unavailable" : "available"
        let fieldConfidence = confidence(status, category: .dynamicExternalInformation)
        return PersonalTripDayWeather(
            condition: QualifiedString(
                value: unavailable ? nil : sample.0,
                confidence: fieldConfidence
            ),
            temperatureRange: QualifiedTemperatureRange(
                value: unavailable ? nil : TemperatureRange(low: sample.1, high: sample.2),
                confidence: fieldConfidence
            ),
            precipitation: QualifiedString(
                value: unavailable ? nil : sample.3,
                confidence: fieldConfidence
            ),
            wind: QualifiedString(
                value: unavailable ? nil : sample.4,
                confidence: fieldConfidence
            ),
            placeContext: QualifiedString(
                value: unavailable ? nil : "云岭环线",
                confidence: fieldConfidence
            ),
            routeSectionContext: nil,
            source: QualifiedString(
                value: unavailable ? nil : "示例天气服务",
                confidence: fieldConfidence
            ),
            updatedAt: QualifiedInstant(
                value: unavailable ? nil : Instant(rawValue: "2026-08-29 09:20"),
                confidence: fieldConfidence
            )
        )
    }

    private static func confidence(
        _ status: String,
        category: InformationCategory? = nil
    ) -> InformationConfidence {
        InformationConfidence(status: status, category: category)
    }

    private static func date(_ day: Int) -> LocalDate {
        LocalDate(year: 2026, month: 9, day: day)
    }

    private static func position(
        _ latitude: Double,
        _ longitude: Double
    ) -> PublicRouteGeoPosition {
        PublicRouteGeoPosition(
            latitude: latitude,
            longitude: longitude,
            referenceSystem: "WGS84"
        )
    }
}
