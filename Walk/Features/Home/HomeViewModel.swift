import Foundation

struct HomeWeatherSummary: Equatable {
    let conclusion: String
    let impact: String
}

enum HomeState: Equatable {
    case guest
    case loading
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
    private let onNoFocus: () -> Void

    init(
        service: any PersonalTripServicing,
        authSession: any AuthSession = AuthManager.shared,
        onNoFocus: @escaping () -> Void = {}
    ) {
        self.isLoggedIn = { authSession.isLoggedIn }
        self.loadFocus = { try await service.focus() }
        self.onNoFocus = onNoFocus
    }

    init(
        isLoggedIn: @escaping () -> Bool = { true },
        loadFocus: @escaping () async throws -> PersonalTripFocus,
        onNoFocus: @escaping () -> Void = {}
    ) {
        self.isLoggedIn = isLoggedIn
        self.loadFocus = loadFocus
        self.onNoFocus = onNoFocus
    }

    init(
        staticState: HomeState,
        focusedTrip: PersonalTripSummary? = nil,
        weatherSummary: HomeWeatherSummary? = nil,
        refreshError: String? = nil
    ) {
        self.state = staticState
        self.focusedTrip = focusedTrip
        self.weatherSummary = weatherSummary
        self.refreshError = refreshError
        self.isLoggedIn = { staticState != .guest }
        self.loadFocus = { PersonalTripFocus(trip: focusedTrip) }
        self.onNoFocus = {}
        self.isStatic = true
    }

    private var isStatic = false

    func load() async {
        guard !isStatic else { return }

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
                state = .loading
                onNoFocus()
                return
            }

            focusedTrip = trip
            weatherSummary = nil
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
}
