import Foundation

struct HomeWeatherSummary: Equatable {
    let precipitationProbability: Int?
    let windSpeed: Double?
    let minimumTemperature: Double?
    let maximumTemperature: Double?
}

enum HomeState: Equatable {
    case loading
    case empty
    case error(String)
    case ready(route: Route, weather: HomeWeatherSummary?)
}

protocol CurrentRouteSelectionStore: AnyObject {
    func selectedRouteID() -> String?
    func selectRoute(id: String)
}

final class UserDefaultsCurrentRouteSelectionStore: CurrentRouteSelectionStore {
    private let defaults: UserDefaults
    private let key = "walk.current-route-id"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func selectedRouteID() -> String? {
        defaults.string(forKey: key)
    }

    func selectRoute(id: String) {
        defaults.set(id, forKey: key)
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var state: HomeState = .loading

    private let loadSelectedRouteID: () -> String?
    private let saveSelectedRouteID: (String) -> Void
    private let loadRoute: (String) async throws -> Route
    private let loadWeather: (Route, Date) async -> HomeWeatherSummary?

    init(
        selectionStore: any CurrentRouteSelectionStore,
        routeService: RouteService
    ) {
        self.loadSelectedRouteID = { selectionStore.selectedRouteID() }
        self.saveSelectedRouteID = { selectionStore.selectRoute(id: $0) }
        self.loadRoute = { try await routeService.getRouteDetail(id: $0) }
        // Weather API has not migrated to the unified client yet; keep the HUD honest until injected.
        self.loadWeather = { _, _ in nil }
    }

    init(
        loadSelectedRouteID: @escaping () -> String?,
        saveSelectedRouteID: @escaping (String) -> Void = { _ in },
        loadRoute: @escaping (String) async throws -> Route,
        loadWeather: @escaping (Route, Date) async -> HomeWeatherSummary? = { _, _ in nil }
    ) {
        self.loadSelectedRouteID = loadSelectedRouteID
        self.saveSelectedRouteID = saveSelectedRouteID
        self.loadRoute = loadRoute
        self.loadWeather = loadWeather
    }

    func load() async {
        state = .loading

        guard let routeID = loadSelectedRouteID(), !routeID.isEmpty else {
            state = .empty
            return
        }

        do {
            let route = try await loadRoute(routeID)
            await show(route)
        } catch {
            state = .error("当前路线加载失败")
        }
    }

    func retry() async {
        await load()
    }

    func selectRoute(_ route: Route) async {
        saveSelectedRouteID(route.id)
        await show(route)
    }

    private func show(_ route: Route) async {
        let hikingDate = Self.upcomingHikingDate()
        state = .ready(route: route, weather: await loadWeather(route, hikingDate))
    }

    nonisolated static func upcomingHikingDate(
        from date: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let start = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: start)
        let daysUntilSaturday = (7 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: daysUntilSaturday, to: start) ?? start
    }
}
