import Foundation
import WalkData
import WalkDesignSystem

enum BaselinePageID: String, CaseIterable {
    case login = "PAGE-LOGIN"
    case home = "PAGE-HOME"
    case routes = "PAGE-ROUTES"
    case routeList = "PAGE-ROUTE-LIST"
    case search = "PAGE-SEARCH"
    case routeDetail = "PAGE-ROUTE-DETAIL"
    case tripCreate = "PAGE-TRIP-CREATE"
    case tripDetail = "PAGE-TRIP-DETAIL"
    case tripBrowse = "PAGE-TRIP-BROWSE"
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
            return .tripBrowse
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

    static let tripListScenarios: [CurrentBaselineScenario] = [
        .pageTripsLoaded,
        .pageTripsCurrentEmpty,
        .pageTripsHistoryEmpty,
        .pageTripsLoading,
        .pageTripsGlobalEmpty,
        .pageTripsError,
    ]

    var pageID: BaselinePageID { .trips }
}

enum BaselineReadinessStatus {
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
        case .ready:
            prefix = "ready"
        case .unsupported:
            prefix = "unsupported"
        }
        return "baseline.\(prefix).\(scenario.rawValue)"
    }
}
