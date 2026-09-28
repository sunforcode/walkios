import Foundation

public enum APIHTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public enum APIStoragePolicy: Equatable {
    case none
    case store
}

/// 远端客户端的响应缓存开关；不改变 APIRequest 的端点缓存资格。
public enum APIResponseCachePolicy: Equatable {
    /// 保留远端读取与成功响应落盘行为，不启用失败时的本地回退。
    case enabled
    /// 禁止业务响应缓存读写，并绕过 URLSession 的 HTTP 响应缓存。
    case disabled
}

public enum APIResponseEnvelope: Equatable {
    case legacy
    case data
}

public enum APIAuthenticationPolicy: Equatable {
    case none
    case optional
    case required
}

public protocol APIRequest {
    associatedtype Response: Decodable

    var method: APIHTTPMethod { get }
    var path: String { get }
    /// 路径中的动态身份已按单个 segment 编码，HTTP 层不得再次转义百分号。
    var pathIsPercentEncoded: Bool { get }
    var query: [URLQueryItem] { get }
    var body: Data? { get }
    var headers: [String: String] { get }
    var contentType: String? { get }
    var responseEnvelope: APIResponseEnvelope { get }
    var storagePolicy: APIStoragePolicy { get }
    var authenticationPolicy: APIAuthenticationPolicy { get }
    /// 离线读取资格。未登记时为 `nil`，表示不允许离线返回。
    ///
    /// 依据 R-CACHE-VALIDITY：`storagePolicy == .store` 只证明保存资格，不授予离线返回资格。
    var offlineEligibility: OfflineEligibility? { get }
    /// 对本次远端响应校验端点元数据，不使用全局共享的响应头状态。
    func validateResponse(_ response: Response, statusCode: Int, headers: [String: String]) throws
}

public extension APIRequest {
     var pathIsPercentEncoded: Bool { false }
     var query: [URLQueryItem] { [] }
     var body: Data? { nil }
     var headers: [String: String] { [:] }
     var contentType: String? { body == nil ? nil : "application/json" }
     var responseEnvelope: APIResponseEnvelope { .legacy }
     var storagePolicy: APIStoragePolicy { .none }
     var authenticationPolicy: APIAuthenticationPolicy { .required }
     /// 默认不具备离线资格；授予必须逐端点显式登记。
     var offlineEligibility: OfflineEligibility? { nil }
     func validateResponse(_ response: Response, statusCode: Int, headers: [String: String]) throws {}

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

public enum APIPathSegment {
    /// 身份是不透明字符串，保留其内容，并阻止斜杠、问号等改变路由。
    public static func encode(_ value: String) -> String {
        if value == "." || value == ".." {
            return value.map { _ in "%2E" }.joined()
        }
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: unreserved)!
    }
}

public protocol APIClient {
    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response
}

/// 传输层失败的结构化原因。
///
/// 依据 specs/README.md R-CACHE-POLICY：断网判定必须来自结构化原因，不解析本地化文案。
/// `notConnected` 与 `connectionLost` 是首版允许触发缓存回退的两种明确断网原因；
/// 其余原因保持各自语义，不得被归并为断网。
public enum APITransportFailure: Equatable, Sendable {
    /// 设备明确未连接网络。
    case notConnected
    /// 连接已建立后中断。
    case connectionLost
    /// 请求超时；不属于断网。
    case timedOut
    /// 请求被主动取消；不属于失败回退范围。
    case cancelled
    /// 其余未归类传输问题，保留底层描述用于诊断。
    case other(String)

    /// 是否属于首版允许触发离线回退的明确断网原因。
    public var isDisconnection: Bool {
        switch self {
        case .notConnected, .connectionLost:
            return true
        case .timedOut, .cancelled, .other:
            return false
        }
    }

    /// 展示文案与结构化原因分离：改变文案不影响判定。
    public var displayMessage: String {
        switch self {
        case .notConnected: return "网络连接失败，请检查网络设置"
        case .connectionLost: return "网络连接已中断，请稍后重试"
        case .timedOut: return "请求超时，请稍后重试"
        case .cancelled: return "请求已取消"
        case .other(let description): return description
        }
    }
}

public enum APIClientError: Error, LocalizedError, Equatable {
    case invalidURL
    case transport(APITransportFailure)
    case invalidResponse
    case http(statusCode: Int)
    case business(message: String, code: Int)
    case api(code: String, message: String, retryable: Bool, details: APIErrorDetails? = nil)
    case decoding(String)
    case mockNotFound(String)

     public var errorDescription: String? {
        switch self {
        case .invalidURL: return "无效的服务地址"
        case .transport(let failure): return failure.displayMessage
        case .invalidResponse: return "服务器响应无效"
        case .http(let statusCode): return "HTTP \(statusCode)"
        case .business(let message, _): return message
        case .api(_, let message, _, _): return message
        case .decoding(let message): return "响应解析失败：\(message)"
        case .mockNotFound(let identifier): return "未找到 Mock：\(identifier)"
        }
    }
}
