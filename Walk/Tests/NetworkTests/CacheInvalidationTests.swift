import XCTest
import Alamofire
import WalkData

/// W1-5：修改后失效与结果来源语义。
///
/// 依据 specs/README.md：
/// - R-INVALIDATION：成功修改或修改结果不确定后，使当前服务与会话的响应缓存失效；
///   失效过程必须阻止旧在途读取重新写回缓存或覆盖新的页面结果；
///   不能将修改响应直接写入形状不同的 GET 缓存。
/// - R-RESULT：启用 `useCache` 的调用链必须携带结果来源与保存时间，
///   必要时携带本次回退原因；不通过共享的「最后一次请求来源」记录并发请求信息。
final class CacheInvalidationTests: XCTestCase {

    // MARK: - 结果来源

    func testRemoteResultCarriesRemoteProvenance() async throws {
        let harness = try ProvenanceHarness(cachedAt: nil, now: Date(timeIntervalSince1970: 2_000))
        let result = try await harness.client.executeWithProvenance(harness.request)

        XCTAssertEqual(result.value.value, "remote")
        XCTAssertEqual(result.provenance, .remote)
        XCTAssertNil(result.provenance.savedAt)
        XCTAssertNil(result.provenance.fallbackReason)
    }

    func testCachedResultCarriesSavedAtAndFallbackReason() async throws {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        let harness = try ProvenanceHarness(
            cachedAt: savedAt,
            now: Date(timeIntervalSince1970: 1_060),
            failure: URLError(.notConnectedToInternet)
        )

        let result = try await harness.client.executeWithProvenance(harness.request)

        XCTAssertEqual(result.value.value, "cached")
        XCTAssertEqual(result.provenance.savedAt, savedAt)
        XCTAssertEqual(result.provenance.fallbackReason, .notConnected)
        XCTAssertTrue(result.provenance.isFromCache)
    }

    /// 并发请求各自携带来源，不共享「最后一次请求来源」。
    func testConcurrentRequestsCarryIndependentProvenance() async throws {
        let savedAt = Date(timeIntervalSince1970: 1_000)
        let offline = try ProvenanceHarness(
            cachedAt: savedAt,
            now: Date(timeIntervalSince1970: 1_060),
            failure: URLError(.notConnectedToInternet)
        )
        let online = try ProvenanceHarness(cachedAt: nil, now: Date(timeIntervalSince1970: 2_000))

        async let first = offline.client.executeWithProvenance(offline.request)
        async let second = online.client.executeWithProvenance(online.request)
        let (cachedResult, remoteResult) = try await (first, second)

        XCTAssertTrue(cachedResult.provenance.isFromCache)
        XCTAssertFalse(remoteResult.provenance.isFromCache)
        XCTAssertEqual(cachedResult.provenance.savedAt, savedAt)
        XCTAssertNil(remoteResult.provenance.savedAt)
    }

    // MARK: - 修改后失效

    func testSuccessfulMutationInvalidatesCurrentServiceAndSessionCache() async throws {
        let generation = APIStorageGeneration()
        let storage = InvalidationStorageSpy()
        let harness = try MutationHarness(
            storage: storage,
            generation: generation,
            statusCode: 200
        )

        _ = try await harness.client.execute(MutationRequest())

        let removedAll = await storage.removeAllCount()
        XCTAssertEqual(removedAll, 1, "成功修改后必须使当前服务与会话的响应缓存失效")
    }

    /// 修改结果不确定同样触发失效，避免后续读取返回旧事实。
    func testUncertainMutationResultAlsoInvalidatesCache() async throws {
        for statusCode in [500, 503] {
            let storage = InvalidationStorageSpy()
            let harness = try MutationHarness(
                storage: storage,
                generation: APIStorageGeneration(),
                statusCode: statusCode
            )

            _ = try? await harness.client.execute(MutationRequest())

            let removedAll = await storage.removeAllCount()
            XCTAssertEqual(removedAll, 1, "结果不确定（HTTP \(statusCode)）也必须失效")
        }
    }

    /// 明确失败且结果确定的修改不触发失效。
    func testDeterministicMutationFailureDoesNotInvalidateCache() async throws {
        let storage = InvalidationStorageSpy()
        let harness = try MutationHarness(
            storage: storage,
            generation: APIStorageGeneration(),
            statusCode: 400
        )

        _ = try? await harness.client.execute(MutationRequest())

        let removedAll = await storage.removeAllCount()
        XCTAssertEqual(removedAll, 0, "确定性失败不改变服务端事实，不应失效缓存")
    }

    /// 修改响应形状与 GET 缓存不同，不得写入 GET 缓存。
    func testMutationResponseIsNeverWrittenToCache() async throws {
        let storage = InvalidationStorageSpy()
        let harness = try MutationHarness(
            storage: storage,
            generation: APIStorageGeneration(),
            statusCode: 200
        )

        _ = try await harness.client.execute(MutationRequest())

        let saves = await storage.saveCount()
        XCTAssertEqual(saves, 0, "修改响应不得写入响应缓存")
    }
}

// MARK: - Fixtures

private struct ProvenancePayload: Decodable, Equatable {
    let value: String
}

private struct ProvenanceRequest: APIRequest {
    typealias Response = ProvenancePayload
    let method: APIHTTPMethod = .get
    let path = "/provenance"
    let responseEnvelope: APIResponseEnvelope = .data
    let storagePolicy: APIStoragePolicy = .store
    let authenticationPolicy: APIAuthenticationPolicy = .none
    let offlineEligibility: OfflineEligibility? = OfflineEligibility(
        upstreamBasis: "W1 测试端点，不对应任何生产上游合同",
        maxAge: 600
    )
}

private struct MutationRequest: APIRequest {
    typealias Response = ProvenancePayload
    let method: APIHTTPMethod = .post
    let path = "/mutate"
    let body: Data? = Data("{}".utf8)
    let responseEnvelope: APIResponseEnvelope = .data
    let authenticationPolicy: APIAuthenticationPolicy = .none
}

private struct ProvenanceHarness {
    let client: AlamofireRemoteAPIClient
    let request = ProvenanceRequest()
    let baseURL: URL

    init(cachedAt: Date?, now: Date, failure: URLError? = nil) throws {
        // 每个 harness 使用独立 host，避免并发用例互相覆盖 handler。
        baseURL = URL(string: "https://\(UUID().uuidString.lowercased()).example.test/api/v1")!
        let service = APIServiceIdentity(environmentName: "test", baseURL: baseURL)
        var seeded: [String: Data] = [:]
        if let cachedAt {
            let key = StorageKey.make(
                for: request,
                schemaVersion: "v1",
                service: service,
                userID: "user-1"
            )
            let record = CachedResponseRecord(
                payload: Data(#"{"data":{"value":"cached"}}"#.utf8),
                savedAt: cachedAt,
                requestIdentifier: request.identifier,
                serviceNamespace: service.storageNamespace,
                userID: "user-1",
                cacheControl: APICacheControl(headerValue: "max-age=600"),
                validators: APIResponseValidators()
            )
            seeded[key] = try record.encoded()
        }
        let storage = InvalidationStorageSpy(values: seeded)
        InvalidationURLProtocol.register(host: baseURL.host!) { request in
            if let failure { throw failure }
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"data":{"value":"remote"}}"#.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InvalidationURLProtocol.self]
        client = AlamofireRemoteAPIClient(
            baseURL: baseURL,
            session: Session(configuration: configuration),
            storage: storage,
            storageContext: APIStorageContext(schemaVersion: "v1", service: service, userID: "user-1"),
            offlinePolicy: .useCache,
            accessToken: { nil },
            now: { now }
        )
    }
}

private struct MutationHarness {
    let client: AlamofireRemoteAPIClient

    init(storage: InvalidationStorageSpy, generation: APIStorageGeneration, statusCode: Int) throws {
        let baseURL = URL(string: "https://\(UUID().uuidString.lowercased()).example.test/api/v1")!
        InvalidationURLProtocol.register(host: baseURL.host!) { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: statusCode, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"data":{"value":"mutated"}}"#.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [InvalidationURLProtocol.self]
        client = AlamofireRemoteAPIClient(
            baseURL: baseURL,
            session: Session(configuration: configuration),
            storage: storage,
            storageContext: APIStorageContext(
                schemaVersion: "v1",
                service: .testService(environment: "test"),
                userID: "user-1"
            ),
            storageGeneration: generation,
            accessToken: { nil },
            now: { Date(timeIntervalSince1970: 2_000) }
        )
    }
}

private actor InvalidationStorageSpy: APIStorage {
    private var values: [String: Data]
    private var saves = 0
    private var removeAlls = 0

    init(values: [String: Data] = [:]) { self.values = values }

    func save(_ data: Data, for key: String) async throws {
        saves += 1
        values[key] = data
    }
    func load(for key: String) async throws -> Data? { values[key] }
    func remove(for key: String) async throws { values.removeValue(forKey: key) }
    func removeAll() async throws {
        removeAlls += 1
        values.removeAll()
    }
    func saveCount() -> Int { saves }
    func removeAllCount() -> Int { removeAlls }
}

private final class InvalidationURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: Handler] = [:]

    static func register(host: String, handler: @escaping Handler) {
        lock.withLock { handlers[host] = handler }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let host = request.url?.host,
              let handler = Self.lock.withLock({ Self.handlers[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
