import Foundation

/// 路线类别
public enum RouteCategory: String, Codable {
    case hiking = "hiking"
    case cycling = "cycling"
    case camping = "camping"
    case climbing = "climbing"
    case urban = "urban"
    case mountain = "mountain"
    case coastal = "coastal"

    /// 中文显示名称
     public var displayName: String {
        switch self {
        case .hiking: return "徒步"
        case .cycling: return "骑行"
        case .camping: return "露营"
        case .climbing: return "攀岩"
        case .urban: return "城市"
        case .mountain: return "山地"
        case .coastal: return "海滨"
        }
    }
}
