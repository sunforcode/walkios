import Foundation

/// 路线模型
struct Route: Codable, Identifiable, Equatable {
    let id: String
    let name: String?
    let description: String?
    let category: RouteCategory?
    let difficulty: Difficulty?
    let distance: Double?
    let duration: Int?
    let elevation: Int?
    let routeType: String?
    let coverImageUrl: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case category
        case difficulty
        case distance
        case duration
        case elevation
        case routeType = "route_type"
        case coverImageUrl = "cover_image_url"
        case createdAt = "created_at"
    }

    /// 距离描述（km）
    var distanceDescription: String {
        guard let distance = distance else { return "未知" }
        return String(format: "%.1f km", distance)
    }

    /// 时长描述（天）
    var durationDescription: String {
        guard let duration = duration else { return "未知" }
        return "\(duration) 天"
    }
}
