import Foundation

/// 攻略模型
struct Guide: Codable, Identifiable, Equatable {
    let id: String
    let title: String?
    let summary: String?
    let content: String?
    let coverImageUrl: String?
    let authorName: String?
    let authorAvatarUrl: String?
    let readCount: Int?
    let likeCount: Int?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case content
        case coverImageUrl = "cover_image_url"
        case authorName = "author_name"
        case authorAvatarUrl = "author_avatar_url"
        case readCount = "read_count"
        case likeCount = "like_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 阅读数量描述
    var readCountDescription: String {
        guard let count = readCount else { return "" }
        return count >= 10000 ? "\(count / 10000)万" : "\(count)"
    }

    /// 点赞数量描述
    var likeCountDescription: String {
        guard let count = likeCount else { return "" }
        return count >= 10000 ? "\(count / 10000)万" : "\(count)"
    }
}
