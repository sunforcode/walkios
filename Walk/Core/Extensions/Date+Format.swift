import Foundation

enum BusinessCalendar {
    static let timeZone = TimeZone(identifier: "Asia/Shanghai")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = timeZone
        return calendar
    }

    static func startOfToday(now: Date = .now) -> Date {
        calendar.startOfDay(for: now)
    }
}

extension Calendar {
    static var business: Calendar { BusinessCalendar.calendar }
}

extension DateFormatter {
    /// ISO8601 日期格式化器（带毫秒）
    static let iso8601WithMilliseconds: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// ISO8601 日期格式化器（不带毫秒）
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    /// 短日期格式化器（MM月dd日）
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()

    /// 完整日期格式化器（yyyy年MM月dd日）
    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}

extension JSONDecoder {
    /// ISO8601 解码器
    static let iso8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // 尝试多种格式
            if let date = DateFormatter.iso8601WithMilliseconds.date(from: dateString) {
                return date
            }
            if let date = DateFormatter.iso8601.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "无法解析日期格式: \(dateString)"
                )
            )
        }
        return decoder
    }()
}

extension Date {
    /// 格式化为短日期（MM月dd日）
    var shortDateString: String {
        DateFormatter.shortDate.string(from: self)
    }

    /// 格式化为完整日期（yyyy年MM月dd日）
    var fullDateString: String {
        DateFormatter.fullDate.string(from: self)
    }
}
