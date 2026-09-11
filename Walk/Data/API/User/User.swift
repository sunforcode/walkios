import Foundation

/// 用户模型
struct User: Codable, Identifiable, Equatable {
    let id: String
    let username: String?
    let email: String?
    let avatarUrl: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }

    /// 显示名称
    var displayName: String {
        username ?? "用户"
    }
}
