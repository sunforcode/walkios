import Foundation
import WalkData

enum TripWeatherState {
    enum Content {
        case ready(weather: PersonalTripWeather, detail: PersonalTripDetail)
        case unavailable(detail: PersonalTripDetail?)
        case failed(String)
    }

    case idle
    case loading(previous: Content?)
    case settled(Content)

    var content: Content? {
        switch self {
        case .idle: nil
        case .loading(let previous): previous
        case .settled(let content): content
        }
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var weather: PersonalTripWeather? {
        if case .ready(let weather, _) = content { return weather }
        return nil
    }

    var detail: PersonalTripDetail? {
        switch content {
        case .ready(_, let detail), .unavailable(let detail?): detail
        default: nil
        }
    }

    var isUnavailable: Bool {
        guard !isLoading else { return false }
        if case .unavailable = content { return true }
        return false
    }

    var errorMessage: String? {
        guard !isLoading else { return nil }
        if case .failed(let message) = content { return message }
        return nil
    }
}
