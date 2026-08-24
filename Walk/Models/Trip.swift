import Foundation

/// 行程模型
struct Trip: Codable, Identifiable, Equatable {
    let id: String
    let name: String?
    let description: String?
    let status: TripStatus
    let startDate: Date?
    let endDate: Date?
    let userId: String?
    let routeId: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
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
    var displayName: String {
        name ?? "未命名行程"
    }

    /// 日期范围描述
    var dateRangeDescription: String {
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
    var durationDescription: String {
        guard let startDate, let endDate else { return "天数待定" }
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
        let days = max(1, (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
        return "\(days) 天"
    }
}
