import Foundation

/// 行程状态。后端当前定义 0...3；未知整数会被保留，避免新状态导致解码失败。
enum TripStatus: Codable, Equatable {
    case planning
    case inProgress
    case completed
    case cancelled
    case unknown(Int)

    init(rawValue: Int) {
        switch rawValue {
        case 0: self = .planning
        case 1: self = .inProgress
        case 2: self = .completed
        case 3: self = .cancelled
        default: self = .unknown(rawValue)
        }
    }

    var rawValue: Int {
        switch self {
        case .planning: return 0
        case .inProgress: return 1
        case .completed: return 2
        case .cancelled: return 3
        case .unknown(let value): return value
        }
    }

    init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(Int.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var displayName: String {
        switch self {
        case .planning: return "规划中"
        case .inProgress: return "进行中"
        case .completed: return "已完成"
        case .cancelled: return "已取消"
        case .unknown: return "未知状态"
        }
    }

}
