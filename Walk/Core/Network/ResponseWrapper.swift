import Foundation

/// 统一 API 响应包装
/// 与后端 ApiResponse<T> 格式对齐
struct ApiResponse<T: Decodable>: Decodable {
    let success: Bool
    let data: T?
    let message: String?
    let error: APIError?

    /// 提取数据，失败时抛出错误
    func unwrap() throws -> T {
        if success, let data = data {
            return data
        }
        if let apiError = error {
            throw apiError
        }
        throw APIError(code: "UNKNOWN", details: message, field: nil, timestamp: nil)
    }
}

/// 分页响应包装
struct PaginatedResponse<T: Decodable>: Decodable {
    let content: [T]
    let totalElements: Int?
    let totalPages: Int?
    let page: Int?
    let size: Int?
    let first: Bool?
    let last: Bool?

    enum CodingKeys: String, CodingKey {
        case content
        case totalElements
        case totalPages
        case page
        case size
        case first
        case last
    }
}
