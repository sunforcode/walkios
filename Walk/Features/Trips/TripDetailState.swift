import Foundation
import WalkData

struct TripDetailState {
    /// Detail, days and the optional weather association are published as one revision.
    struct Projection {
        let detail: PersonalTripDetail
        let days: PersonalTripDays
        let weather: PersonalTripWeather?
        var routeVersionStatus: PersonalTripRouteVersionStatus
        var scenes: PersonalTripScenes?
        let sceneRequestID = UUID()

        var isWeatherUnavailable: Bool { weather == nil }
    }

    enum Phase {
        case idle
        case loading
        case mutating
    }

    var projection: Projection?
    var phase: Phase = .idle
    var errorMessage: String?
    var migrationErrorMessage: String?

    var isLoading: Bool { phase == .loading }
    var isMutating: Bool { phase == .mutating }
}
