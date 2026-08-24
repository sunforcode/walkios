import Foundation
import Alamofire

final class AlamofireRemoteAPIClient: APIClient {
    private let baseURL: URL
    private let session: Session
    private let storage: (any APIStorage)?
    private let storageContext: APIStorageContext?
    private let storageGeneration: APIStorageGeneration?

    init(
        baseURL: URL,
        session: Session = AlamofireRemoteAPIClient.makeDefaultSession(),
        storage: (any APIStorage)? = nil,
        storageContext: APIStorageContext? = nil,
        storageGeneration: APIStorageGeneration? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.storage = storage
        self.storageContext = storageContext
        self.storageGeneration = storageGeneration
    }

    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        // 请求发起时固定缓存身份和世代，避免账号切换或退出后写回旧数据。
        let storageIdentity = storageContext?.currentUserID
        let generationSnapshot = await storageGeneration?.snapshot()
        let urlRequest = try makeURLRequest(request)
        let response = await session.request(urlRequest).serializingData().response

        if let error = response.error {
            throw mapTransportError(error)
        }
        guard let statusCode = response.response?.statusCode, let data = response.data else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(statusCode) else {
            if let businessError = APIJSONDecoder.businessError(from: data) {
                throw businessError
            }
            throw APIClientError.http(statusCode: statusCode)
        }

        let value = try APIJSONDecoder.decode(Request.Response.self, from: data)
        if request.storagePolicy == .store,
           let storage,
           let storageContext,
           let storageIdentity,
           await canWriteCache(generationSnapshot) {
            let key = StorageKey.make(
                for: request,
                schemaVersion: storageContext.schemaVersion,
                environment: storageContext.environment,
                userID: storageIdentity
            )
            do {
                try await storage.save(data, for: key)
                if !(await canWriteCache(generationSnapshot)) {
                    try await storage.remove(for: key)
                }
            } catch {
                #if DEBUG
                print("APIStorage save failed: \(error.localizedDescription)")
                #endif
            }
        }
        return value
    }

    private func canWriteCache(_ snapshot: Int?) async -> Bool {
        guard let storageGeneration else { return true }
        guard let snapshot else { return false }
        return await storageGeneration.isCurrent(snapshot)
    }

    private func makeURLRequest<Request: APIRequest>(_ request: Request) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(request.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), resolvingAgainstBaseURL: false) else {
            throw APIClientError.invalidURL
        }
        components.queryItems = request.query.isEmpty ? nil : request.query
        guard let url = components.url else { throw APIClientError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return urlRequest
    }

    private func mapTransportError(_ error: AFError) -> APIClientError {
        if let urlError = error.underlyingError as? URLError {
            switch urlError.code {
            case .notConnectedToInternet: return .transport("网络连接失败，请检查网络设置")
            case .timedOut: return .transport("请求超时，请稍后重试")
            default: return .transport(urlError.localizedDescription)
            }
        }
        return .transport(error.localizedDescription)
    }

    static func makeDefaultSession() -> Session {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        let interceptor = Interceptor(adapters: [AuthAdapter()], retriers: [APIRetryPolicy()])
        return Session(configuration: configuration, interceptor: interceptor, eventMonitors: [LoggingMonitor()])
    }
}
