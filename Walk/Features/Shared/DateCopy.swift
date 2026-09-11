import Foundation

/// shortDate 日期口径（6.2 确立，PAGE-TRIP-EQUIPMENT / PAGE-TRIPS 共用）：
/// 单日「M月D日」，区间用「—」连接。
enum DateCopy {
    static func shortDate(_ value: String) -> String {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return value }
        return "\(month)月\(day)日"
    }

    static func dateRange(start: String, end: String) -> String {
        let startText = shortDate(start)
        return start == end ? startText : "\(startText)—\(shortDate(end))"
    }
}
