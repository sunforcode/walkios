import Foundation

/// API 端点集中定义
/// 所有 URL 路径在此统一管理，与 openspec/specs/api-contract/ 保持一致
enum APIEndpoints {
    /// Legacy domains remain configurable until they migrate to typed APIRequest.
    static var baseURL: String {
        ProcessInfo.processInfo.environment["WALK_API_BASE_URL"]
            ?? "https://api.example.invalid/walkbg/api/v1"
    }

    // MARK: - Trips
    static let trips = "/trips"
    static func tripDetail(_ id: String) -> String { "/trips/\(id)" }
    static let createTrip = "/trips"
    static func updateTrip(_ id: String) -> String { "/trips/\(id)" }
    static func deleteTrip(_ id: String) -> String { "/trips/\(id)" }
    static func tripStatus(_ id: String) -> String { "/trips/\(id)/status" }
    static let plannedTrips = "/trips/planned"

    // MARK: - Routes
    static let routes = "/routes"
    static func routeDetail(_ id: String) -> String { "/routes/\(id)" }
    static let popularRoutes = "/routes/popular"
    static let recommendedRoutes = "/routes/recommended"
    static let seasonalRoutes = "/routes/seasonal"
    static let newRoutes = "/routes/new"
    static let weekendRoutes = "/routes/weekend"
    static let searchRoutes = "/routes/search"
    static let favoriteRoutes = "/routes/favorites"
    static func favoriteRoute(_ id: String) -> String { "/routes/\(id)/favorite" }

    // MARK: - Equipment
    static let equipment = "/equipment"
    static func equipmentDetail(_ id: String) -> String { "/equipment/\(id)" }

    // MARK: - Guides
    static let guides = "/guides"
    static func guideDetail(_ id: String) -> String { "/guides/\(id)" }

    // MARK: - Users
    static let users = "/users"
    static func userDetail(_ id: String) -> String { "/users/\(id)" }
    static let currentUser = "/users/me"

    /// 拼接完整 URL
    static func fullURL(_ path: String) -> String {
        return baseURL + path
    }
}
