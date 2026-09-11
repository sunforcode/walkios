import Foundation

/// 用户模型
public struct User: Codable, Identifiable, Equatable {
     public let id: String
     public let username: String?
     public let email: String?
     public let avatarUrl: String?
     public let createdAt: Date?

    public enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }

    /// 显示名称
     public var displayName: String {
        username ?? "用户"
    }

    public init(
        id: String,
        username: String?,
        email: String?,
        avatarUrl: String?,
        createdAt: Date?
    ) {
        self.id = id
        self.username = username
        self.email = email
        self.avatarUrl = avatarUrl
        self.createdAt = createdAt
    }
}
