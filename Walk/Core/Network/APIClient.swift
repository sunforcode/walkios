import Foundation

enum DataSourceMode: String, CaseIterable {
    case remote
    case local
    case mock
}

enum APIHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

enum APIStoragePolicy: Equatable {
    case none
    case store
}

enum APIResponseEnvelope: Equatable {
    case legacy
    case data
}

enum APIAuthenticationPolicy: Equatable {
    case none
    case optional
    case required
}

protocol APIRequest {
    associatedtype Response: Decodable

    var method: APIHTTPMethod { get }
    var path: String { get }
    var query: [URLQueryItem] { get }
    var body: Data? { get }
    var headers: [String: String] { get }
    var contentType: String? { get }
    var responseEnvelope: APIResponseEnvelope { get }
    var storagePolicy: APIStoragePolicy { get }
    var authenticationPolicy: APIAuthenticationPolicy { get }
}

extension APIRequest {
    var query: [URLQueryItem] { [] }
    var body: Data? { nil }
    var headers: [String: String] { [:] }
    var contentType: String? { body == nil ? nil : "application/json" }
    var responseEnvelope: APIResponseEnvelope { .legacy }
    var storagePolicy: APIStoragePolicy { .none }
    var authenticationPolicy: APIAuthenticationPolicy { .required }

    var identifier: String {
        let queryString = query
            .sorted {
                if $0.name == $1.name { return ($0.value ?? "") < ($1.value ?? "") }
                return $0.name < $1.name
            }
            .map { "\($0.name)=\($0.value ?? "")" }
            .joined(separator: "&")
        return "\(method.rawValue) \(path)\(queryString.isEmpty ? "" : "?\(queryString)")"
    }
}

protocol APIClient {
    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response
}

enum APIClientError: Error, LocalizedError, Equatable {
    case invalidURL
    case transport(String)
    case invalidResponse
    case http(statusCode: Int)
    case business(message: String, code: Int)
    case api(code: String, message: String, retryable: Bool, details: APIErrorDetails? = nil)
    case decoding(String)
    case localDataNotFound
    case mockNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的服务地址"
        case .transport(let message): return message
        case .invalidResponse: return "服务器响应无效"
        case .http(let statusCode): return "HTTP \(statusCode)"
        case .business(let message, _): return message
        case .api(_, let message, _, _): return message
        case .decoding(let message): return "响应解析失败：\(message)"
        case .localDataNotFound: return "本地没有该请求的数据"
        case .mockNotFound(let identifier): return "未找到 Mock：\(identifier)"
        }
    }
}
