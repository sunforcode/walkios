import Foundation
import WalkData
import WalkDesignSystem

@MainActor
final class RouteDiscoveryViewModel: ObservableObject {
    @Published var routes: [PublicRouteBrowseSummary] = []
    @Published private(set) var searchResults: [PublicRouteSearchSummary] = []
    @Published private(set) var searchState: PublicRouteSearchState = .initial
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: any RouteDiscoveryServicing
    private var searchGeneration = 0

    init(service: any RouteDiscoveryServicing) {
        self.service = service
    }

    func loadRoutes() async {
        guard !isLoading else { return }
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
        searchGeneration += 1
        let generation = searchGeneration

        guard let query,
              !query.unicodeScalars.allSatisfy({ scalar in
                  switch scalar.value {
                  case 0x20, 0x09, 0x0A, 0x0D, 0x3000: true
                  default: false
                  }
              }) else {
            searchState = .initial
            searchResults = []
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await service.searchRoutes(query: query)
            guard generation == searchGeneration, !Task.isCancelled else { return }
            searchState = result.state
            searchResults = result.items
            isLoading = false
        } catch {
            guard generation == searchGeneration, !Task.isCancelled else { return }
            errorMessage = Self.message(for: error)
            isLoading = false
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
        guard !isLoading else { return }
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
