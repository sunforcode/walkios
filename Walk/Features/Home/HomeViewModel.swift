import Foundation

struct HomeWeatherSummary: Equatable {
    let text: String?
}

enum HomeState: Equatable {
    case guest
    case loading
    case empty
    case error(String)
    case ready
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var state: HomeState = .loading
    @Published private(set) var focusedTrip: PersonalTripSummary?
    @Published private(set) var weatherSummary: HomeWeatherSummary?
    @Published private(set) var refreshError: String?

    private let isLoggedIn: () -> Bool
    private let loadFocus: () async throws -> PersonalTripFocus
    private let loadWeather: (String) async throws -> PersonalTripWeather
    private let onNoFocus: () -> Void

    init(
        service: any PersonalTripServicing,
        authSession: any AuthSession = AuthManager.shared,
        onNoFocus: @escaping () -> Void = {}
    ) {
        self.isLoggedIn = { authSession.isLoggedIn }
        self.loadFocus = { try await service.focus() }
        self.loadWeather = { try await service.weather(tripID: $0) }
        self.onNoFocus = onNoFocus
    }

    init(
        isLoggedIn: @escaping () -> Bool = { true },
        loadFocus: @escaping () async throws -> PersonalTripFocus,
        loadWeather: @escaping (String) async throws -> PersonalTripWeather = {
            throw APIClientError.mockNotFound("GET /trips/\($0)/weather")
        },
        onNoFocus: @escaping () -> Void = {}
    ) {
        self.isLoggedIn = isLoggedIn
        self.loadFocus = loadFocus
        self.loadWeather = loadWeather
        self.onNoFocus = onNoFocus
    }

    func load() async {
        guard isLoggedIn() else {
            focusedTrip = nil
            weatherSummary = nil
            refreshError = nil
            state = .guest
            return
        }

        let hadFocus = focusedTrip != nil
        if !hadFocus { state = .loading }
        refreshError = nil

        do {
            guard let trip = try await loadFocus().trip else {
                focusedTrip = nil
                weatherSummary = nil
                state = .empty
                onNoFocus()
                return
            }

            focusedTrip = trip
            weatherSummary = await weatherSummary(for: trip)
            state = .ready
        } catch {
            if hadFocus {
                state = .ready
                refreshError = "当前行程刷新失败"
            } else {
                state = .error("当前行程加载失败")
            }
        }
    }

    func retry() async { await load() }

    private func weatherSummary(for trip: PersonalTripSummary) async -> HomeWeatherSummary? {
        guard let weather = try? await loadWeather(trip.tripID),
              weather.tripID == trip.tripID,
              weather.revision == trip.revision else {
            return nil
        }
        return HomeWeatherSummary(text: weather.weatherOverview?.value)
    }
}
