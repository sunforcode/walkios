import Foundation

enum BaselinePageID: String, CaseIterable {
    case login = "PAGE-LOGIN"
    case home = "PAGE-HOME"
    case routes = "PAGE-ROUTES"
    case routeList = "PAGE-ROUTE-LIST"
    case search = "PAGE-SEARCH"
    case routeDetail = "PAGE-ROUTE-DETAIL"
    case tripCreate = "PAGE-TRIP-CREATE"
    case tripDetail = "PAGE-TRIP-DETAIL"
    case tripDay = "PAGE-TRIP-DAY"
    case tripWeather = "PAGE-TRIP-WEATHER"
    case tripTransport = "PAGE-TRIP-TRANSPORT"
    case tripEquipment = "PAGE-TRIP-EQUIPMENT"
    case trips = "PAGE-TRIPS"
    case me = "PAGE-ME"
    case myEquipment = "PAGE-MY-EQUIPMENT"
    case equipmentEdit = "PAGE-EQUIPMENT-EDIT"
}

/// Frozen reference IDs from walk-ui-baseline-v1. These are not the current execution denominator.
enum BaselineScenario: String, CaseIterable {
    case pageLoginDefault = "page-login--default"
    case pageLoginCodeSent = "page-login--code-sent"
    case pageLoginSendFailure = "page-login--send-failure"
    case pageHomeGuest = "page-home--guest"
    case pageHomeAuthenticated = "page-home--authenticated"
    case pageRoutesDefault = "page-routes--default"
    case pageRoutesLoading = "page-routes--loading"
    case pageRoutesError = "page-routes--error"
    case pageRouteListDefault = "page-route-list--default"
    case pageRouteListEmpty = "page-route-list--empty"
    case pageRouteListLoading = "page-route-list--loading"
    case pageRouteListError = "page-route-list--error"
    case pageSearchDefault = "page-search--default"
    case pageSearchError = "page-search--error"
    case pageRouteDetailDefault = "page-route-detail--default"
    case pageRouteDetailTrackUnavailable = "page-route-detail--track-unavailable"
    case pageTripCreateDefault = "page-trip-create--default"
    case pageTripCreateNoEquipment = "page-trip-create--no-equipment"
    case pageTripCreateGenerating = "page-trip-create--generating"
    case pageTripCreateGenerationFailed = "page-trip-create--generation-failed"
    case pageTripDetailDefaultTop = "page-trip-detail--default-top"
    case pageTripDetailDefaultMiddle = "page-trip-detail--default-middle"
    case pageTripDetailDefaultBottom = "page-trip-detail--default-bottom"
    case pageTripDetailActive = "page-trip-detail--active"
    case pageTripDetailDone = "page-trip-detail--done"
    case pageTripDetailCancelled = "page-trip-detail--cancelled"
    case pageTripDetailRouteDiff = "page-trip-detail--route-diff"
    case pageTripDetailMigrationFailed = "page-trip-detail--migration-failed"
    case pageTripDetailWeatherUnavailable = "page-trip-detail--weather-unavailable"
    case pageTripDetailTransportUnavailable = "page-trip-detail--transport-unavailable"
    case pageTripDayDay1 = "page-trip-day--day-1"
    case pageTripDayDay2 = "page-trip-day--day-2"
    case pageTripDayPartial = "page-trip-day--partial"
    case pageTripDayUnavailable = "page-trip-day--unavailable"
    case pageTripDayWeatherExpired = "page-trip-day--weather-expired"
    case pageTripDayWeatherUnavailable = "page-trip-day--weather-unavailable"
    case pageTripDayTransportUnavailable = "page-trip-day--transport-unavailable"
    case pageTripWeatherDefault = "page-trip-weather--default"
    case pageTripWeatherExpired = "page-trip-weather--expired"
    case pageTripWeatherUnavailable = "page-trip-weather--unavailable"
    case pageTripTransportDefault = "page-trip-transport--default"
    case pageTripTransportUnavailable = "page-trip-transport--unavailable"
    case pageTripEquipmentDefault = "page-trip-equipment--default"
    case pageTripsDefault = "page-trips--default"
    case pageTripsEmpty = "page-trips--empty"
    case pageMeGuest = "page-me--guest"
    case pageMeAuthenticated = "page-me--authenticated"
    case pageMeProfilePanel = "page-me--profile-panel"
    case pageMyEquipmentGear = "page-my-equipment--gear"
    case pageMyEquipmentGearEmpty = "page-my-equipment--gear-empty"
    case pageMyEquipmentLists = "page-my-equipment--lists"
    case pageMyEquipmentListsEmpty = "page-my-equipment--lists-empty"
    case pageEquipmentEditEdit = "page-equipment-edit--edit"
    case pageEquipmentEditCreate = "page-equipment-edit--create"

    static let tripDetailScenarios: [BaselineScenario] = [
        .pageTripDetailDefaultTop,
        .pageTripDetailDefaultMiddle,
        .pageTripDetailDefaultBottom,
        .pageTripDetailActive,
        .pageTripDetailDone,
        .pageTripDetailCancelled,
        .pageTripDetailRouteDiff,
        .pageTripDetailMigrationFailed,
        .pageTripDetailWeatherUnavailable,
        .pageTripDetailTransportUnavailable,
    ]

    var pageID: BaselinePageID {
        switch self {
        case .pageLoginDefault, .pageLoginCodeSent, .pageLoginSendFailure:
            return .login
        case .pageHomeGuest, .pageHomeAuthenticated:
            return .home
        case .pageRoutesDefault, .pageRoutesLoading, .pageRoutesError:
            return .routes
        case .pageRouteListDefault, .pageRouteListEmpty, .pageRouteListLoading, .pageRouteListError:
            return .routeList
        case .pageSearchDefault, .pageSearchError:
            return .search
        case .pageRouteDetailDefault, .pageRouteDetailTrackUnavailable:
            return .routeDetail
        case .pageTripCreateDefault, .pageTripCreateNoEquipment,
             .pageTripCreateGenerating, .pageTripCreateGenerationFailed:
            return .tripCreate
        case .pageTripDetailDefaultTop, .pageTripDetailDefaultMiddle,
             .pageTripDetailDefaultBottom, .pageTripDetailActive,
             .pageTripDetailDone, .pageTripDetailCancelled,
             .pageTripDetailRouteDiff, .pageTripDetailMigrationFailed,
             .pageTripDetailWeatherUnavailable, .pageTripDetailTransportUnavailable:
            return .tripDetail
        case .pageTripDayDay1, .pageTripDayDay2, .pageTripDayPartial,
             .pageTripDayUnavailable, .pageTripDayWeatherExpired,
             .pageTripDayWeatherUnavailable, .pageTripDayTransportUnavailable:
            return .tripDay
        case .pageTripWeatherDefault, .pageTripWeatherExpired, .pageTripWeatherUnavailable:
            return .tripWeather
        case .pageTripTransportDefault, .pageTripTransportUnavailable:
            return .tripTransport
        case .pageTripEquipmentDefault:
            return .tripEquipment
        case .pageTripsDefault, .pageTripsEmpty:
            return .trips
        case .pageMeGuest, .pageMeAuthenticated, .pageMeProfilePanel:
            return .me
        case .pageMyEquipmentGear, .pageMyEquipmentGearEmpty,
             .pageMyEquipmentLists, .pageMyEquipmentListsEmpty:
            return .myEquipment
        case .pageEquipmentEditEdit, .pageEquipmentEditCreate:
            return .equipmentEdit
        }
    }
}

enum CurrentBaselineScenario: String, CaseIterable {
    case pageTripsLoaded = "page-trips--loaded"
    case pageTripsCurrentEmpty = "page-trips--current-empty"
    case pageTripsHistoryEmpty = "page-trips--history-empty"
    case pageTripsLoading = "page-trips--loading"
    case pageTripsGlobalEmpty = "page-trips--global-empty"
    case pageTripsError = "page-trips--error"

    case componentMetricItemAvailable = "component-metric-item--available"
    case componentMetricItemMissing = "component-metric-item--missing"
    case componentMetricGroupInline = "component-metric-group--inline"
    case componentMetricGroupMissing = "component-metric-group--missing"
    case componentWeatherSummaryDefault = "component-weather-summary--default"
    case componentWeatherSummaryOmitted = "component-weather-summary--omitted"
    case componentWeatherSummaryStale = "component-weather-summary--stale"
    case componentWeatherSummaryLongContent = "component-weather-summary--long-content"
    case componentFocusTripSummaryComplete = "component-focus-trip-summary--complete"
    case componentFocusTripSummaryMissingMetrics = "component-focus-trip-summary--missing-metrics"
    case componentFocusTripSummaryWeatherOmitted = "component-focus-trip-summary--weather-omitted"
    case componentFocusTripSummaryLongContent = "component-focus-trip-summary--long-content"
    case componentPrimaryTabBarHome = "component-primary-tab-bar--home"
    case componentPrimaryTabBarRoutes = "component-primary-tab-bar--routes"
    case componentPrimaryTabBarMe = "component-primary-tab-bar--me"

    case pageHomeGuest = "page-home--guest"
    case pageHomeFocusComplete = "page-home--focus-complete"
    case pageHomeFocusMissingMetrics = "page-home--focus-missing-metrics"
    case pageHomeFocusWeatherOmitted = "page-home--focus-weather-omitted"
    case pageHomeLoading = "page-home--loading"
    case pageHomeError = "page-home--error"
    case pageHomeLongContent = "page-home--long-content"

    static let tripListScenarios: [CurrentBaselineScenario] = [
        .pageTripsLoaded,
        .pageTripsCurrentEmpty,
        .pageTripsHistoryEmpty,
        .pageTripsLoading,
        .pageTripsGlobalEmpty,
        .pageTripsError,
    ]

    static let homePilotScenarios: [CurrentBaselineScenario] = [
        .componentMetricItemAvailable,
        .componentMetricItemMissing,
        .componentMetricGroupInline,
        .componentMetricGroupMissing,
        .componentWeatherSummaryDefault,
        .componentWeatherSummaryOmitted,
        .componentWeatherSummaryStale,
        .componentWeatherSummaryLongContent,
        .componentFocusTripSummaryComplete,
        .componentFocusTripSummaryMissingMetrics,
        .componentFocusTripSummaryWeatherOmitted,
        .componentFocusTripSummaryLongContent,
        .componentPrimaryTabBarHome,
        .componentPrimaryTabBarRoutes,
        .componentPrimaryTabBarMe,
        .pageHomeGuest,
        .pageHomeFocusComplete,
        .pageHomeFocusMissingMetrics,
        .pageHomeFocusWeatherOmitted,
        .pageHomeLoading,
        .pageHomeError,
        .pageHomeLongContent,
    ]

    static let allExecutableScenarios: [CurrentBaselineScenario] =
        tripListScenarios + homePilotScenarios

    /// 枚举只收录当前可执行的场景；历史冻结场景归 `BaselineScenario`。
    var isSupported: Bool { true }

    var pageID: BaselinePageID? {
        switch self {
        case .pageTripsLoaded, .pageTripsCurrentEmpty, .pageTripsHistoryEmpty,
             .pageTripsLoading, .pageTripsGlobalEmpty, .pageTripsError:
            return .trips
        case .pageHomeGuest, .pageHomeFocusComplete, .pageHomeFocusMissingMetrics,
             .pageHomeFocusWeatherOmitted, .pageHomeLoading, .pageHomeError,
             .pageHomeLongContent:
            return .home
        default:
            return nil
        }
    }

    var surfaceID: String {
        if let pageID {
            return pageID.rawValue
        }
        switch self {
        case .componentMetricItemAvailable:
            return "MetricItem.default"
        case .componentMetricItemMissing:
            return "MetricItem.missingMetrics"
        case .componentMetricGroupInline:
            return "MetricGroup.inline"
        case .componentMetricGroupMissing:
            return "MetricGroup.missingMetrics"
        case .componentWeatherSummaryDefault:
            return "WeatherSummary.default"
        case .componentWeatherSummaryOmitted:
            return "WeatherSummary.omitted"
        case .componentWeatherSummaryStale:
            return "WeatherSummary.stale"
        case .componentWeatherSummaryLongContent:
            return "WeatherSummary.longContent"
        case .componentFocusTripSummaryComplete:
            return "FocusTripSummary.complete"
        case .componentFocusTripSummaryMissingMetrics:
            return "FocusTripSummary.missingMetrics"
        case .componentFocusTripSummaryWeatherOmitted:
            return "FocusTripSummary.weatherOmitted"
        case .componentFocusTripSummaryLongContent:
            return "FocusTripSummary.longContent"
        case .componentPrimaryTabBarHome:
            return "PrimaryTabBar.home"
        case .componentPrimaryTabBarRoutes:
            return "PrimaryTabBar.routes"
        case .componentPrimaryTabBarMe:
            return "PrimaryTabBar.me"
        default:
            return rawValue
        }
    }
}

enum BaselineReadinessStatus {
    case pending
    case ready
    case unsupported
}

enum BaselineReadiness {
    static func identifier(
        for scenario: CurrentBaselineScenario,
        status: BaselineReadinessStatus
    ) -> String {
        let prefix: String
        switch status {
        case .pending:
            prefix = "pending"
        case .ready:
            prefix = "ready"
        case .unsupported:
            prefix = "unsupported"
        }
        return "baseline.\(prefix).\(scenario.rawValue)"
    }
}
