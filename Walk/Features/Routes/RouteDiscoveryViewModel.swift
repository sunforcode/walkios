import Foundation

@MainActor
final class RouteDiscoveryViewModel: ObservableObject {
    @Published var routes: [PublicRouteBrowseSummary] = []
    @Published private(set) var searchResults: [PublicRouteSearchSummary] = []
    @Published private(set) var searchState: PublicRouteSearchState = .initial
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: any RouteDiscoveryServicing

    init(service: any RouteDiscoveryServicing) {
        self.service = service
    }

    func loadRoutes() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            routes = try await service.getFeaturedRoutes().items
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func search(query: String?) async {
        guard let query, !query.isEmpty else {
            searchState = .initial
            searchResults = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await service.searchRoutes(query: query)
            searchState = result.state
            searchResults = result.items
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func retry() async {
        await loadRoutes()
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}

@MainActor
final class RouteCollectionViewModel: ObservableObject {
    @Published private(set) var routes: [PublicRouteBrowseSummary] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let service: any RouteDiscoveryServicing

    init(service: any RouteDiscoveryServicing) {
        self.service = service
    }

    func loadRoutes() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            routes = try await service.getRoutes().items
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func retry() async {
        await loadRoutes()
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}
