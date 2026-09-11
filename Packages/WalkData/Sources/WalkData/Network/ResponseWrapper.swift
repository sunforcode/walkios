import Foundation

/// 统一 API 响应包装
/// 与后端 ApiResponse<T> 格式对齐
public struct ApiResponse<T: Decodable>: Decodable {
     public let success: Bool
     public let data: T?
     public let message: String?
     public let error: APIError?

    /// 提取数据，失败时抛出错误
     public func unwrap() throws -> T {
        if success, let data = data {
            return data
        }
        if let apiError = error {
            throw apiError
        }
        throw APIError(code: "UNKNOWN", details: message, field: nil, timestamp: nil)
    }

    public init(
        success: Bool,
        data: T?,
        message: String?,
        error: APIError?
    ) {
        self.success = success
        self.data = data
        self.message = message
        self.error = error
    }
}

/// 分页响应包装
public struct PaginatedResponse<T: Decodable>: Decodable {
     public let content: [T]
     public let totalElements: Int?
     public let totalPages: Int?
     public let page: Int?
     public let size: Int?
     public let first: Bool?
     public let last: Bool?

    public enum CodingKeys: String, CodingKey {
        case content
        case totalElements
        case totalPages
        case page
        case size
        case first
        case last
    }

    public init(
        content: [T],
        totalElements: Int?,
        totalPages: Int?,
        page: Int?,
        size: Int?,
        first: Bool?,
        last: Bool?
    ) {
        self.content = content
        self.totalElements = totalElements
        self.totalPages = totalPages
        self.page = page
        self.size = size
        self.first = first
        self.last = last
    }
}
