import Foundation

/// 网络层错误（底层连接问题）
enum NetworkError: Error, LocalizedError {
    case noConnection
    case timeout
    case serverUnreachable
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "网络连接失败，请检查网络设置"
        case .timeout:
            return "请求超时，请稍后重试"
        case .serverUnreachable:
            return "无法连接到服务器"
        case .underlying(let error):
            return error.localizedDescription
        }
    }
}

/// 业务层错误（后端返回的错误）
struct APIError: Error, Decodable, LocalizedError {
    let code: String
    let details: String?
    let field: String?
    let timestamp: String?

    var errorDescription: String? {
        return details ?? message
    }

    private var message: String {
        switch code {
        case "VALIDATION_ERROR":
            return "输入参数有误"
        case "UNAUTHORIZED":
            return "请先登录"
        case "FORBIDDEN":
            return "无权访问"
        case "NOT_FOUND":
            return "请求的资源不存在"
        case "SERVER_ERROR":
            return "服务器繁忙，请稍后重试"
        default:
            return "发生错误：\(code)"
        }
    }
}

/// HTTP 状态码映射
extension APIError {
    static func from(statusCode: Int, data: Data?) -> APIError {
        // 尝试从响应体解析错误
        if let data = data,
           let decoded = try? JSONDecoder.iso8601.decode(APIError.self, from: data) {
            return decoded
        }
        // 默认错误
        let code: String
        switch statusCode {
        case 400: code = "BAD_REQUEST"
        case 401: code = "UNAUTHORIZED"
        case 403: code = "FORBIDDEN"
        case 404: code = "NOT_FOUND"
        case 429: code = "RATE_LIMITED"
        case 500...599: code = "SERVER_ERROR"
        default: code = "UNKNOWN"
        }
        return APIError(code: code, details: "HTTP \(statusCode)", field: nil, timestamp: nil)
    }

    static var unauthorized: APIError {
        APIError(code: "UNAUTHORIZED", details: "登录已过期，请重新登录", field: nil, timestamp: nil)
    }
}
