import Foundation

protocol RouteDetailServicing: AnyObject {
    func getRouteDetailResponse(id: String) async throws -> RouteDetailResponse
    func setFavorite(routeID: String, isFavorite: Bool) async throws
}

/// 路线服务。路线详情和收藏始终走 AppEnvironment 配置的类型化 APIClient。
final class RouteService: RouteDetailServicing {
    private let legacyClient = LegacyAPIClient.shared
    private let apiClient: any APIClient
    private let userID: String

    init(apiClient: any APIClient, userID: String) {
        self.apiClient = apiClient
        self.userID = userID
    }

    func getRoutes(category: RouteCategory? = nil, page: Int = 0, size: Int = 20) async throws -> [Route] {
        #if DEBUG
        try await Task.sleep(nanoseconds: 500_000_000)
        if let category { return MockData.routes.filter { $0.category == category } }
        return Array(MockData.routes.prefix(size))
        #else
        var parameters: [String: Any] = ["page": page, "size": size]
        if let category { parameters["category"] = category.rawValue }
        return try await legacyClient.request(APIEndpoints.routes, method: .get, parameters: parameters)
        #endif
    }

    func getPopularRoutes() async throws -> [Route] {
        #if DEBUG
        try await Task.sleep(nanoseconds: 300_000_000)
        return Array(MockData.routes.prefix(2))
        #else
        return try await legacyClient.request(APIEndpoints.popularRoutes, method: .get)
        #endif
    }

    func getRecommendedRoutes() async throws -> [Route] {
        #if DEBUG
        try await Task.sleep(nanoseconds: 300_000_000)
        return MockData.routes
        #else
        return try await legacyClient.request(APIEndpoints.recommendedRoutes, method: .get)
        #endif
    }

    func getRouteDetailResponse(id: String) async throws -> RouteDetailResponse {
        try await apiClient.execute(RouteAPI.Detail(id: id, userID: userID))
    }

    /// Lightweight compatibility adapter for non-detail consumers that still render `Route`.
    /// The route-detail screen never uses this path.
    func getRouteDetail(id: String) async throws -> Route {
        let detail = try await getRouteDetailResponse(id: id)
        return Route(
            id: detail.id,
            name: detail.name,
            description: detail.description,
            category: nil,
            difficulty: nil,
            distance: detail.distance,
            duration: detail.duration,
            elevation: detail.elevationGain.map(Int.init),
            routeType: detail.routeType?.displayText,
            coverImageUrl: detail.coverUrl,
            createdAt: Date(timeIntervalSince1970: TimeInterval(detail.createdAt))
        )
    }

    func setFavorite(routeID: String, isFavorite: Bool) async throws {
        _ = try await apiClient.execute(RouteAPI.Favorite(id: routeID, userID: userID, isFavorite: isFavorite))
    }

    func searchRoutes(keyword: String) async throws -> [Route] {
        #if DEBUG
        try await Task.sleep(nanoseconds: 300_000_000)
        return MockData.routes.filter {
            $0.name?.contains(keyword) == true || $0.description?.contains(keyword) == true
        }
        #else
        return try await legacyClient.request(
            APIEndpoints.searchRoutes,
            method: .get,
            parameters: ["keyword": keyword]
        )
        #endif
    }
}
