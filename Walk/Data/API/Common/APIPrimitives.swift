import Foundation

struct DataEnvelope<Value: Decodable>: Decodable {
    let data: Value
}

struct LocalDate: Codable, Hashable, Comparable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    var dateAtStartOfDay: Date? {
        Calendar.business.date(from: DateComponents(year: year, month: month, day: day))
    }

    static func < (left: LocalDate, right: LocalDate) -> Bool {
        (left.year, left.month, left.day) < (right.year, right.month, right.day)
    }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .business) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0
        )
    }

    init(from decoder: Decoder) throws {
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

struct Instant: Codable, Hashable, CustomStringConvertible {
    let rawValue: String

    var description: String { rawValue }

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        self.rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ErrorEnvelope: Decodable {
    let error: APIErrorPayload
}

struct APIErrorPayload: Decodable {
    let code: String
    let message: String
    let retryable: Bool
    let details: APIErrorDetails?
}

struct APIErrorDetails: Codable, Equatable {
    let requestedTargetRouteVersionId: String?
    let currentPublicRouteVersionId: String?
    let retryAvailableAt: Date?

    init(
        requestedTargetRouteVersionId: String? = nil,
        currentPublicRouteVersionId: String? = nil,
        retryAvailableAt: Date? = nil
    ) {
        self.requestedTargetRouteVersionId = requestedTargetRouteVersionId
        self.currentPublicRouteVersionId = currentPublicRouteVersionId
        self.retryAvailableAt = retryAvailableAt
    }
}

struct APIEnvelope<Value: Decodable>: Decodable {
    let success: Bool
    let message: String
    let data: Value?
    let timestamp: Date
    let code: Int

    func unwrap() throws -> Value {
        guard success else {
            throw APIClientError.business(message: message, code: code)
        }
        if let data { return data }
        if Value.self == EmptyResponse.self, let empty = EmptyResponse() as? Value {
            return empty
        }
        throw APIClientError.decoding("成功响应缺少 data")
    }
}

struct PageDTO<Item: Decodable>: Decodable {
    let items: [Item]
    let number: Int
    let size: Int
    let totalElements: Int
    let totalPages: Int
    let first: Bool
    let last: Bool

    enum CodingKeys: String, CodingKey {
        case items = "content"
        case number
        case size
        case totalElements
        case totalPages
        case first
        case last
    }
}

struct EmptyResponse: Codable, Equatable {
    init() {}
}

enum APIJSONDecoder {
    static func make() -> JSONDecoder {
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

extension ISO8601DateFormatter {
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

extension APIJSONDecoder {
    static func decode<Response: Decodable>(
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

    static func apiError(from data: Data) -> APIClientError? {
        guard let envelope = try? make().decode(ErrorEnvelope.self, from: data) else { return nil }
        return .api(
            code: envelope.error.code,
            message: envelope.error.message,
            retryable: envelope.error.retryable,
            details: envelope.error.details
        )
    }

    static func businessError(from data: Data) -> APIClientError? {
        if let error = apiError(from: data) { return error }
        guard let envelope = try? make().decode(APIEnvelope<EmptyResponse>.self, from: data), !envelope.success else {
            return nil
        }
        return .business(message: envelope.message, code: envelope.code)
    }
}
