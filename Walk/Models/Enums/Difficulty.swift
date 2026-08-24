import Foundation

/// 路线难度
enum Difficulty: String, Codable {
    case easy = "easy"
    case medium = "medium"
    case hard = "hard"

    /// 中文显示名称
    var displayName: String {
        switch self {
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "困难"
        }
    }
}
