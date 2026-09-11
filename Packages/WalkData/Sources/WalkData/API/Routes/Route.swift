import Foundation

/// 路线模型
public struct Route: Codable, Identifiable, Equatable {
     public let id: String
     public let name: String?
     public let description: String?
     public let category: RouteCategory?
     public let difficulty: Difficulty?
     public let distance: Double?
     public let duration: Int?
     public let elevation: Int?
     public let routeType: String?
     public let coverImageUrl: String?
     public let createdAt: Date?

    public enum CodingKeys: String, CodingKey {
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
     public var distanceDescription: String {
        guard let distance = distance else { return "未知" }
        return String(format: "%.1f km", distance)
    }

    /// 时长描述（天）
     public var durationDescription: String {
        guard let duration = duration else { return "未知" }
        return "\(duration) 天"
    }

    public init(
        id: String,
        name: String?,
        description: String?,
        category: RouteCategory?,
        difficulty: Difficulty?,
        distance: Double?,
        duration: Int?,
        elevation: Int?,
        routeType: String?,
        coverImageUrl: String?,
        createdAt: Date?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.category = category
        self.difficulty = difficulty
        self.distance = distance
        self.duration = duration
        self.elevation = elevation
        self.routeType = routeType
        self.coverImageUrl = coverImageUrl
        self.createdAt = createdAt
    }
}
