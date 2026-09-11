import Foundation

protocol RouteDetailServicing: AnyObject {
    func getRouteDetail(id: String) async throws -> PublicRouteDetail
}

protocol RouteDiscoveryServicing: AnyObject {
    func getFeaturedRoutes() async throws -> PublicRouteDiscoveryResult
    func getRoutes() async throws -> PublicRouteCollectionResult
    func searchRoutes(query: String?) async throws -> PublicRouteSearchResult
}

/// Public-route service backed only by the configured typed API client.
final class RouteService: RouteDetailServicing, RouteDiscoveryServicing {
    private let apiClient: any APIClient

    init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    func getFeaturedRoutes() async throws -> PublicRouteDiscoveryResult {
        try await apiClient.execute(PublicRouteAPI.Featured())
    }

    func getRoutes() async throws -> PublicRouteCollectionResult {
        try await apiClient.execute(PublicRouteAPI.All())
    }

    func searchRoutes(query: String?) async throws -> PublicRouteSearchResult {
        try await apiClient.execute(PublicRouteAPI.Search(query: query))
    }

    func getRouteDetail(id: String) async throws -> PublicRouteDetail {
        try await apiClient.execute(PublicRouteAPI.Detail(id: id))
    }

    /// Lightweight compatibility adapter for existing trip and home summaries.
    /// All facts still come from the public-route detail endpoint.
    func getLegacyRouteSummary(id: String) async throws -> Route {
        let detail = try await getRouteDetail(id: id)
        let summary = detail.currentVersion.summary
        let cover = detail.currentVersion.images?.first(where: { $0.role == .cover })?.mediaReference

        return Route(
            id: detail.routeId,
            name: summary.name,
            description: summary.introduction,
            category: nil,
            difficulty: nil,
            distance: summary.distance.map { $0.meters / 1_000 },
            duration: summary.estimatedDuration.map { Int(ceil($0.seconds / 86_400)) },
            elevation: summary.ascent.map { Int($0.meters) },
            routeType: summary.routeType == .oneDay ? "一日路线" : "多日路线",
            coverImageUrl: cover,
            createdAt: nil
        )
    }
}
