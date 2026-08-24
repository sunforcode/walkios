import Foundation

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
    static func decode<Response: Decodable>(_ response: Response.Type, from data: Data) throws -> Response {
        do {
            let envelope = try make().decode(APIEnvelope<Response>.self, from: data)
            return try envelope.unwrap()
        } catch let error as APIClientError {
            throw error
        } catch {
            throw APIClientError.decoding(error.localizedDescription)
        }
    }

    static func businessError(from data: Data) -> APIClientError? {
        guard let envelope = try? make().decode(APIEnvelope<EmptyResponse>.self, from: data), !envelope.success else {
            return nil
        }
        return .business(message: envelope.message, code: envelope.code)
    }
}
