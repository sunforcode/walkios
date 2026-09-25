import Foundation
import Alamofire

public final class AlamofireRemoteAPIClient: APIClient {
    private let baseURL: URL
    private let session: Session
    private let storage: (any APIStorage)?
    private let storageContext: APIStorageContext?
    private let storageGeneration: APIStorageGeneration?
    private let responseCachePolicy: APIResponseCachePolicy
    /// App 注入的默认断网策略；端点资格仍决定是否真正允许离线返回。
    private let offlinePolicy: OfflinePolicy
    private let accessToken: () -> String?
    private let invalidateSession: () async -> Void
    /// 缓存来源时间使用注入的时钟，便于确定性验证有效期。
    private let now: () -> Date

     public init(
        baseURL: URL,
        session: Session? = nil,
        storage: (any APIStorage)? = nil,
        storageContext: APIStorageContext? = nil,
        storageGeneration: APIStorageGeneration? = nil,
        responseCachePolicy: APIResponseCachePolicy = .enabled,
        offlinePolicy: OfflinePolicy = .default,
        accessToken: @escaping () -> String?,
        invalidateSession: @escaping () async -> Void = {},
        now: @escaping () -> Date = { Date() }
    ) {
        self.now = now
        self.offlinePolicy = offlinePolicy
        self.baseURL = baseURL
        self.session = session ?? Self.makeDefaultSession(responseCachePolicy: responseCachePolicy)
        self.storage = responseCachePolicy == .enabled ? storage : nil
        self.storageContext = responseCachePolicy == .enabled ? storageContext : nil
        self.storageGeneration = responseCachePolicy == .enabled ? storageGeneration : nil
        self.responseCachePolicy = responseCachePolicy
        self.accessToken = accessToken
        self.invalidateSession = invalidateSession
    }

     public func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        try await executeWithProvenance(request).value
    }

    /// 带结果来源的执行入口。
    ///
    /// 依据 R-RESULT：每次调用各自携带来源上下文，不使用共享的「最后一次请求来源」。
     public func executeWithProvenance<Request: APIRequest>(
        _ request: Request
    ) async throws -> APIResult<Request.Response> {
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
        // R-STORAGE：HTTP 客户端不得另外绕过所选策略返回缓存；响应复用只由应用响应缓存决定。
        // 注入的 Session 同样不得把响应写入它自己的 URLCache。
        let dataRequest = session.request(urlRequest).cacheResponse(using: .doNotCache)
        let response = await dataRequest
            .serializingData()
            .response

        if let statusCode = response.response?.statusCode,
           !(200..<300).contains(statusCode) {
            // 修改结果不确定时也要失效，避免后续读取返回旧事实。
            if Self.isMutation(request), statusCode >= 500 {
                await invalidateResponseCache()
            }
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
            let failure = Self.transportFailure(from: error)
            // 修改在传输层失败，远端是否已生效不确定。
            if Self.isMutation(request) {
                await invalidateResponseCache()
            }
            // 优先级：模式硬约束 → 端点资格 → 所选策略 → 缓存有效性。
            // 只有明确断网才可能回退；超时、取消与其他原因保持原语义。
            if failure.isDisconnection,
               let cached = try? await offlineFallback(
                   for: request,
                   identity: storageIdentity
               ) {
                return APIResult(
                    value: cached.value,
                    provenance: .cache(savedAt: cached.savedAt, fallbackReason: failure)
                )
            }
            throw APIClientError.transport(failure)
        }
        guard let data = response.data else {
            throw APIClientError.invalidResponse
        }

        let value = try APIJSONDecoder.decode(
            Request.Response.self,
            from: data,
            envelope: request.responseEnvelope
        )
        // R-INVALIDATION：成功修改后使当前服务与会话的响应缓存失效。
        // 修改响应形状与 GET 缓存不同，不得写入 GET 缓存，因此这里直接返回。
        if Self.isMutation(request) {
            await invalidateResponseCache()
            return APIResult(value: value, provenance: .remote)
        }
        // `no-store` 是 RFC 9111 硬约束，端点保存资格不能覆盖它。
        let cacheControl = APICacheControl(
            headerValue: response.response?.value(forHTTPHeaderField: "Cache-Control")
        )
        if CachedResponseRecord.isPersistable(
            cacheControl: cacheControl,
            storagePolicy: request.storagePolicy
        ),
           let storage,
           let storageContext,
           let storageIdentity,
           await canWriteCache(generationSnapshot) {
            let key = StorageKey.make(
                for: request,
                schemaVersion: storageContext.schemaVersion,
                service: storageContext.service,
                userID: storageIdentity
            )
            let record = CachedResponseRecord(
                payload: data,
                savedAt: now(),
                requestIdentifier: request.identifier,
                serviceNamespace: storageContext.serviceNamespace,
                userID: storageIdentity,
                cacheControl: cacheControl,
                validators: APIResponseValidators(
                    headers: response.response?.allHeaderFields ?? [:]
                )
            )
            do {
                try await storage.save(try record.encoded(), for: key)
                if !(await canWriteCache(generationSnapshot)) {
                    try await storage.remove(for: key)
                }
            } catch {
                // 网络成功后的缓存写入失败不得抹掉已取得的有效远端结果。
                #if DEBUG
                print("APIStorage save failed: \(error.localizedDescription)")
                #endif
            }
        }
        return APIResult(value: value, provenance: .remote)
    }

    /// 是否为修改命令。只有只读 GET 参与响应缓存。
    private static func isMutation<Request: APIRequest>(_ request: Request) -> Bool {
        request.method != .get
    }

    /// 保守失效范围：使当前服务与会话的响应缓存失效。
    ///
    /// 推进世代可阻止旧在途读取重新写回缓存或覆盖新的页面结果。
    private func invalidateResponseCache() async {
        await storageGeneration?.invalidate()
        try? await storage?.removeAll()
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
        // 任何模式都网络优先读取，不使用 HTTP 客户端缓存（R-CACHE-POLICY / R-STORAGE）。
        urlRequest.cachePolicy = .reloadIgnoringLocalCacheData
        if responseCachePolicy == .disabled {
            // remoteOnly 额外要求中间层不复用或保存本次响应。
            urlRequest.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        }
        return urlRequest
    }

    /// 断网后的缓存回退。
    ///
    /// 任一条件不成立即返回 nil，由调用方保留原始连接错误：
    /// 所选策略为 `useCache`、端点已登记离线资格、缓存存在且未损坏、
    /// 身份匹配且仍在有效期内。`remoteOnly` 模式下 storage 为 nil，天然不可达。
    private func offlineFallback<Request: APIRequest>(
        for request: Request,
        identity: String?
    ) async throws -> (value: Request.Response, savedAt: Date)? {
        guard offlinePolicy == .useCache,
              let eligibility = request.offlineEligibility,
              let storage,
              let storageContext,
              let identity else {
            return nil
        }
        let key = StorageKey.make(
            for: request,
            schemaVersion: storageContext.schemaVersion,
            service: storageContext.service,
            userID: identity
        )
        guard let data = try await storage.load(for: key),
              let record = try? CachedResponseRecord.decode(from: data),
              record.matches(
                  requestIdentifier: request.identifier,
                  serviceNamespace: storageContext.serviceNamespace,
                  userID: identity
              ),
              eligibility.isFresh(savedAt: record.savedAt, now: now()) else {
            return nil
        }
        let value = try APIJSONDecoder.decode(
            Request.Response.self,
            from: record.payload,
            envelope: request.responseEnvelope
        )
        return (value, record.savedAt)
    }

    /// 将传输错误映射为结构化原因。
    ///
    /// 判定只依据错误类型与 `URLError.Code`，不解析本地化文案；
    /// 未归类问题保留底层描述，但不被视为断网。
    static func transportFailure(from error: AFError) -> APITransportFailure {
        // Alamofire 主动取消不一定携带 underlyingError，需要单独识别。
        if error.isExplicitlyCancelledError {
            return .cancelled
        }
        if let urlError = error.underlyingError as? URLError {
            return transportFailure(from: urlError)
        }
        return .other(error.localizedDescription)
    }

    static func transportFailure(from urlError: URLError) -> APITransportFailure {
        switch urlError.code {
        case .notConnectedToInternet:
            return .notConnected
        case .networkConnectionLost:
            return .connectionLost
        case .timedOut:
            return .timedOut
        case .cancelled:
            return .cancelled
        default:
            return .other(urlError.localizedDescription)
        }
    }

     public static func makeDefaultSession(responseCachePolicy: APIResponseCachePolicy = .enabled) -> Session {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 15
        // HTTP 客户端在任何模式下都不持有响应缓存；应用响应缓存是唯一的复用来源。
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let interceptor = Interceptor(retriers: [APIRetryPolicy()])
        return Session(
            configuration: configuration,
            interceptor: interceptor,
            cachedResponseHandler: ResponseCacher.doNotCache,
            eventMonitors: [LoggingMonitor()]
        )
    }
}

private extension APIClientError {
     public var requiresAuthentication: Bool {
        if case .api(let code, _, _, _) = self {
            return code == "authentication_required"
        }
        return false
    }
}
