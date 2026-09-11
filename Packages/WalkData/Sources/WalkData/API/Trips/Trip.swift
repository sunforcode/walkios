import Foundation

/// 行程模型
public struct Trip: Codable, Identifiable, Equatable {
     public let id: String
     public let name: String?
     public let description: String?
     public let status: TripStatus
     public let startDate: Date?
     public let endDate: Date?
     public let userId: String?
     public let routeId: String?
     public let createdAt: Date?
     public let updatedAt: Date?

    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case status
        case startDate = "start_date"
        case endDate = "end_date"
        case userId = "user_id"
        case routeId = "route_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 显示名称（无名称时返回默认值）
     public var displayName: String {
        name ?? "未命名行程"
    }

    /// 日期范围描述
     public var dateRangeDescription: String {
        switch (startDate, endDate) {
        case let (start?, end?):
            return "\(start.shortDateString) - \(end.shortDateString)"
        case let (start?, nil):
            return start.shortDateString
        case let (nil, end?):
            return end.shortDateString
        case (nil, nil):
            return "日期待定"
        }
    }

    /// Inclusive trip duration when both dates are available.
     public var durationDescription: String {
        guard let startDate, let endDate else { return "天数待定" }
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        let days = max(1, (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        return "\(days) 天"
    }

    public init(
        id: String,
        name: String?,
        description: String?,
        status: TripStatus,
        startDate: Date?,
        endDate: Date?,
        userId: String?,
        routeId: String?,
        createdAt: Date?,
        updatedAt: Date?
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.status = status
        self.startDate = startDate
        self.endDate = endDate
        self.userId = userId
        self.routeId = routeId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
