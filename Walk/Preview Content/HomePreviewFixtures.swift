#if DEBUG
import Foundation
import WalkDesignSystem
import WalkData

enum HomePreviewFixtures {

    static let weatherAvailable = WeatherSummaryModel(
        conclusion: "16°·多云",
        impact: "山脊4级风",
        state: .available
    )

    static let weatherOmitted = WeatherSummaryModel(
        conclusion: "本次未提供天气摘要",
        impact: "行程其他内容仍可查看",
        state: .unavailable
    )

    static let weatherStale = WeatherSummaryModel(
        conclusion: "天气信息可能已过期",
        impact: "请在出发前核对最新天气",
        state: .stale
    )

    static let weatherLongContent = WeatherSummaryModel(
        conclusion: "午后可能出现持续降雨并伴随明显降温",
        impact: "山脊风力增强，需预留更长通过时间并持续核对天气变化",
        state: .available
    )

    static let homeWeatherAvailable = HomeWeatherSummary(
        conclusion: weatherAvailable.conclusion,
        impact: weatherAvailable.impact
    )

    static let homeWeatherLongContent = HomeWeatherSummary(
        conclusion: weatherLongContent.conclusion,
        impact: weatherLongContent.impact
    )

    static let focusComplete = FocusTripSummaryModel(
        routeName: "云岭环线",
        start: "云栈口",
        end: "云栈口",
        distance: "12.1",
        distanceUnit: "km",
        ascent: "600",
        ascentUnit: "m",
        estimatedDuration: "约 5 h 20 min",
        weather: weatherAvailable
    )

    static let focusMissingMetrics = FocusTripSummaryModel(
        routeName: "云岭环线",
        start: "云栈口",
        end: "云栈口",
        distance: nil,
        distanceUnit: "km",
        ascent: nil,
        ascentUnit: "m",
        estimatedDuration: "约 5 h 20 min",
        weather: weatherAvailable
    )

    static let focusWeatherOmitted = FocusTripSummaryModel(
        routeName: "云岭环线",
        start: "云栈口",
        end: "云栈口",
        distance: "12.1",
        distanceUnit: "km",
        ascent: "600",
        ascentUnit: "m",
        estimatedDuration: "约 5 h 20 min",
        weather: nil
    )

    static let focusLongContent = FocusTripSummaryModel(
        routeName: "云岭北坡高山草甸与连续山脊全景环线",
        start: "云栈口游客中心北侧长距离接驳点",
        end: "云栈口游客中心南侧返程集合点",
        distance: "12.1",
        distanceUnit: "km",
        ascent: "600",
        ascentUnit: "m",
        estimatedDuration: "约 5 h 20 min",
        weather: weatherLongContent
    )

    static let completeTrip = trip(
        routeName: "云岭环线",
        start: "云栈口",
        end: "云栈口",
        distanceMeters: 12_100,
        ascentMeters: 600
    )

    static let missingMetricsTrip = trip(
        routeName: "云岭环线",
        start: "云栈口",
        end: "云栈口",
        distanceMeters: nil,
        ascentMeters: nil
    )

    static let longContentTrip = trip(
        routeName: "云岭北坡高山草甸与连续山脊全景环线",
        start: "云栈口游客中心北侧长距离接驳点",
        end: "云栈口游客中心南侧返程集合点",
        distanceMeters: 12_100,
        ascentMeters: 600
    )

    @MainActor
    static func homeViewModel(
        state: HomeState,
        trip: PersonalTripSummary? = nil,
        weather: HomeWeatherSummary? = nil,
        refreshError: String? = nil
    ) -> HomeViewModel {
        HomeViewModel(
            staticState: state,
            focusedTrip: trip,
            weatherSummary: weather,
            refreshError: refreshError
        )
    }

    private static func trip(
        routeName: String,
        start: String,
        end: String,
        distanceMeters: Double?,
        ascentMeters: Double?
    ) -> PersonalTripSummary {
        PersonalTripSummary(
            tripID: "home-preview-trip",
            revision: "home-preview-revision",
            name: routeName,
            status: .inProgress,
            routeReference: PersonalTripRouteReference(
                routeID: "home-preview-route",
                adoptedRouteVersionID: "home-preview-route-version"
            ),
            routeName: routeName,
            routeType: "loop",
            start: PublicRoutePlace(name: start),
            end: PublicRoutePlace(name: end),
            estimatedDuration: RouteDuration(seconds: 19_200),
            startDate: LocalDate(year: 2026, month: 9, day: 20),
            endDate: LocalDate(year: 2026, month: 9, day: 20),
            totalDayCount: 1,
            hikingDayCount: 1,
            versionLabel: "preview-v1",
            cover: nil,
            direction: "环线",
            distance: distanceMeters.map(RouteDistance.init(meters:)),
            ascent: ascentMeters.map(RouteElevationGain.init(meters:))
        )
    }
}
#endif
