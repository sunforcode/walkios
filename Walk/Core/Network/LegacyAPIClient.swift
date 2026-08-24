import Foundation
import Alamofire

/// Temporary transport retained for domains not included in the Trip migration.
final class LegacyAPIClient {
    static let shared = LegacyAPIClient()

    private let session: Session
    private let baseURL: String
    private let decoder: JSONDecoder

    private init() {
        let interceptor = Interceptor(adapters: [AuthAdapter()], retriers: [APIRetryPolicy()])
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        session = Session(configuration: configuration, interceptor: interceptor, eventMonitors: [LoggingMonitor()])
        baseURL = APIEndpoints.baseURL
        decoder = JSONDecoder.iso8601
    }

    func request<T: Decodable>(
        _ path: String,
        method: HTTPMethod = .get,
        parameters: [String: Any]? = nil
    ) async throws -> T {
        let response = try await session.request(
            baseURL + path,
            method: method,
            parameters: parameters,
            encoding: method == .get ? URLEncoding.default : JSONEncoding.default
        )
        .validate()
        .serializingDecodable(ApiResponse<T>.self, decoder: decoder)
        .value
        return try response.unwrap()
    }
}
