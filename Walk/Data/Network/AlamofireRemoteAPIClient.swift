import Foundation
import Alamofire

final class AlamofireRemoteAPIClient: APIClient {
    private let baseURL: URL
    private let session: Session
    private let storage: (any APIStorage)?
    private let storageContext: APIStorageContext?
    private let storageGeneration: APIStorageGeneration?
    private let accessToken: () -> String?
    private let invalidateSession: () async -> Void

    init(
        baseURL: URL,
        session: Session = AlamofireRemoteAPIClient.makeDefaultSession(),
        storage: (any APIStorage)? = nil,
        storageContext: APIStorageContext? = nil,
        storageGeneration: APIStorageGeneration? = nil,
        accessToken: @escaping () -> String? = { AuthManager.shared.currentToken },
        invalidateSession: @escaping () async -> Void = { AuthManager.shared.logout() }
    ) {
        self.baseURL = baseURL
        self.session = session
        self.storage = storage
        self.storageContext = storageContext
        self.storageGeneration = storageGeneration
        self.accessToken = accessToken
        self.invalidateSession = invalidateSession
    }

    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        if request.authenticationPolicy == .required,
           accessToken()?.isEmpty != false {
            await invalidateSession()
            throw APIClientError.api(
                code: "authentication_required",
                message: "请先登录",
                retryable: false
            )
        }

        // 请求发起时固定缓存身份和世代，避免账号切换或退出后写回旧数据。
        let storageIdentity = storageContext?.currentUserID
        let generationSnapshot = await storageGeneration?.snapshot()
        let urlRequest = try makeURLRequest(request)
        let response = await session.request(urlRequest)
            .serializingData()
            .response

        if let statusCode = response.response?.statusCode,
           !(200..<300).contains(statusCode) {
            if let businessError = response.data.flatMap(APIJSONDecoder.businessError(from:)) {
                if request.authenticationPolicy != .none,
                   businessError.requiresAuthentication {
                    await invalidateSession()
                }
                throw businessError
            }
            if request.authenticationPolicy != .none, statusCode == 401 {
                await invalidateSession()
            }
            throw APIClientError.http(statusCode: statusCode)
        }
        if let error = response.error {
            throw mapTransportError(error)
        }
        guard let data = response.data else {
            throw APIClientError.invalidResponse
        }

        let value = try APIJSONDecoder.decode(
            Request.Response.self,
            from: data,
            envelope: request.responseEnvelope
        )
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
        if let contentType = request.contentType {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        switch request.authenticationPolicy {
        case .none:
            break
        case .optional:
            if let token = accessToken() {
                urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        case .required:
            guard let token = accessToken(), !token.isEmpty else {
                throw APIClientError.api(
                    code: "authentication_required",
                    message: "请先登录",
                    retryable: false
                )
            }
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.headers.forEach { name, value in
            urlRequest.setValue(value, forHTTPHeaderField: name)
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
        let interceptor = Interceptor(retriers: [APIRetryPolicy()])
        return Session(configuration: configuration, interceptor: interceptor, eventMonitors: [LoggingMonitor()])
    }
}

private extension APIClientError {
    var requiresAuthentication: Bool {
        if case .api(let code, _, _, _) = self {
            return code == "authentication_required"
        }
        return false
    }
}
