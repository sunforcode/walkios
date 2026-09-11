import Foundation

public struct DataEnvelope<Value: Decodable>: Decodable {
     public let data: Value

    public init(
        data: Value
    ) {
        self.data = data
    }
}

public struct LocalDate: Codable, Hashable, Comparable, CustomStringConvertible {
     public let year: Int
     public let month: Int
     public let day: Int

     public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

     public var dateAtStartOfDay: Date? {
        Calendar.business.date(from: DateComponents(year: year, month: month, day: day))
    }

     public static func < (left: LocalDate, right: LocalDate) -> Bool {
        (left.year, left.month, left.day) < (right.year, right.month, right.day)
    }

     public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

     public init(date: Date, calendar: Calendar = .business) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0
        )
    }

     public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              let date = Calendar.business.date(
                from: DateComponents(year: year, month: month, day: day)
              ) else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Expected local date in YYYY-MM-DD format"
            )
        }
        let components = Calendar.business.dateComponents([.year, .month, .day], from: date)
        guard components.year == year, components.month == month, components.day == day else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid local date"
            )
        }
        self.init(year: year, month: month, day: day)
    }

     public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

public struct Instant: Codable, Hashable, CustomStringConvertible {
     public let rawValue: String

     public var description: String { rawValue }

     public init(rawValue: String) {
        self.rawValue = rawValue
    }

     public init(from decoder: Decoder) throws {
        self.rawValue = try decoder.singleValueContainer().decode(String.self)
    }

     public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct ErrorEnvelope: Decodable {
     public let error: APIErrorPayload

    public init(
        error: APIErrorPayload
    ) {
        self.error = error
    }
}

public struct APIErrorPayload: Decodable {
     public let code: String
     public let message: String
     public let retryable: Bool
     public let details: APIErrorDetails?

    public init(
        code: String,
        message: String,
        retryable: Bool,
        details: APIErrorDetails?
    ) {
        self.code = code
        self.message = message
        self.retryable = retryable
        self.details = details
    }
}

public struct APIErrorDetails: Codable, Equatable {
     public let requestedTargetRouteVersionId: String?
     public let currentPublicRouteVersionId: String?
     public let retryAvailableAt: Date?

     public init(
        requestedTargetRouteVersionId: String? = nil,
        currentPublicRouteVersionId: String? = nil,
        retryAvailableAt: Date? = nil
    ) {
        self.requestedTargetRouteVersionId = requestedTargetRouteVersionId
        self.currentPublicRouteVersionId = currentPublicRouteVersionId
        self.retryAvailableAt = retryAvailableAt
    }
}

public struct APIEnvelope<Value: Decodable>: Decodable {
     public let success: Bool
     public let message: String
     public let data: Value?
     public let timestamp: Date
     public let code: Int

     public func unwrap() throws -> Value {
        guard success else {
            throw APIClientError.business(message: message, code: code)
        }
        if let data { return data }
        if Value.self == EmptyResponse.self, let empty = EmptyResponse() as? Value {
            return empty
        }
        throw APIClientError.decoding("成功响应缺少 data")
    }

    public init(
        success: Bool,
        message: String,
        data: Value?,
        timestamp: Date,
        code: Int
    ) {
        self.success = success
        self.message = message
        self.data = data
        self.timestamp = timestamp
        self.code = code
    }
}

public struct PageDTO<Item: Decodable>: Decodable {
     public let items: [Item]
     public let number: Int
     public let size: Int
     public let totalElements: Int
     public let totalPages: Int
     public let first: Bool
     public let last: Bool

    public enum CodingKeys: String, CodingKey {
        case items = "content"
        case number
        case size
        case totalElements
        case totalPages
        case first
        case last
    }

    public init(
        items: [Item],
        number: Int,
        size: Int,
        totalElements: Int,
        totalPages: Int,
        first: Bool,
        last: Bool
    ) {
        self.items = items
        self.number = number
        self.size = size
        self.totalElements = totalElements
        self.totalPages = totalPages
        self.first = first
        self.last = last
    }
}

public struct EmptyResponse: Codable, Equatable {
     public init() {}
}

public enum APIJSONDecoder {
     public static func make() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.apiWithFractionalSeconds.date(from: value)
                ?? ISO8601DateFormatter.api.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected epoch seconds or ISO-8601 date")
        }
        return decoder
    }
}

public extension ISO8601DateFormatter {
    fileprivate static let api: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    fileprivate static let apiWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

public extension APIJSONDecoder {
     public static func decode<Response: Decodable>(
        _ response: Response.Type,
        from data: Data,
        envelope: APIResponseEnvelope = .legacy
    ) throws -> Response {
        do {
            switch envelope {
            case .legacy:
                return try make().decode(APIEnvelope<Response>.self, from: data).unwrap()
            case .data:
                return try make().decode(DataEnvelope<Response>.self, from: data).data
            }
        } catch let error as APIClientError {
            throw error
        } catch {
            throw APIClientError.decoding(error.localizedDescription)
        }
    }

     public static func apiError(from data: Data) -> APIClientError? {
        guard let envelope = try? make().decode(ErrorEnvelope.self, from: data) else { return nil }
        return .api(
            code: envelope.error.code,
            message: envelope.error.message,
            retryable: envelope.error.retryable,
            details: envelope.error.details
        )
    }

     public static func businessError(from data: Data) -> APIClientError? {
        if let error = apiError(from: data) { return error }
        guard let envelope = try? make().decode(APIEnvelope<EmptyResponse>.self, from: data), !envelope.success else {
            return nil
        }
        return .business(message: envelope.message, code: envelope.code)
    }
}
