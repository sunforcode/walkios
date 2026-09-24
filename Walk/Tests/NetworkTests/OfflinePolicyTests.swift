import XCTest
import Alamofire
import WalkData

/// W1-3：断网策略与端点离线资格。
///
/// 依据 specs/README.md：
/// - R-CACHE-POLICY：优先级是「模式硬约束 → 端点资格/上游合同 → 所选策略 → 缓存有效性」；
///   `fail` 是默认值；`useCache` 只对允许离线读取的只读端点生效；
///   首版仅明确的未连接网络、连接中断触发 `useCache`；
///   超时、401/403、其他 HTTP 错误、业务错误、解码错误和取消保持原语义。
/// - R-CACHE-VALIDITY：现有 `.store` 只证明保存资格；缺少任一登记项时默认不允许离线返回；
///   首版不返回过期缓存。
///
/// 重要：本片只验证策略能力。当前上游 `openspec/specs/` 没有任何离线读取的行为规定，
/// 因此生产端点一律不声明离线资格，验证使用测试专用端点。
final class OfflinePolicyTests: XCTestCase {

    // MARK: - 默认值与资格

    func testDefaultPolicyIsFail() {
        XCTAssertEqual(OfflinePolicy.default, .fail)
    }

    /// 保存资格不等于离线读取资格。
    func testStoragePolicyAloneDoesNotGrantOfflineEligibility() {
        XCTAssertEqual(StoredOnlyRequest().storagePolicy, .store)
        XCTAssertNil(StoredOnlyRequest().offlineEligibility)
    }

    /// 全局选择 useCache 不会让不合格端点自动具备离线返回资格。
    func testGlobalUseCacheDoesNotGrantEligibilityToUnqualifiedEndpoint() async throws {
        let request = StoredOnlyRequest()
        let harness = try await OfflineHarness(
            request: request,
            policy: .useCache,
            cachedAt: Date(timeIntervalSince1970: 1_000),
            now: Date(timeIntervalSince1970: 1_060),
            failure: URLError(.notConnectedToInternet)
        )

        await harness.expectTransportFailure(.notConnected)
        let loads = await harness.storage.loadCount()
        XCTAssertEqual(loads, 0, "不合格端点不得读取缓存")
    }

    /// 所有生产端点在本批次结束时都不得声明离线资格。
    func testNoProductionEndpointDeclaresOfflineEligibilityYet() {
        XCTAssertNil(PublicRouteAPI.Featured().offlineEligibility)
        XCTAssertNil(PublicRouteAPI.Detail(id: "route-1").offlineEligibility)
        XCTAssertNil(PersonalTripAPI.Focus().offlineEligibility)
        XCTAssertNil(PersonalEquipmentAPI.Collection().offlineEligibility)
        XCTAssertNil(AccountAPI.Current().offlineEligibility)
    }

    // MARK: - fail 策略

    func testFailPolicyReturnsConnectionErrorWithoutReadingCache() async throws {
        let harness = try await OfflineHarness(
            request: OfflineReadableRequest(),
            policy: .fail,
            cachedAt: Date(timeIntervalSince1970: 1_000),
            now: Date(timeIntervalSince1970: 1_060),
            failure: URLError(.notConnectedToInternet)
        )

        await harness.expectTransportFailure(.notConnected)
        let loads = await harness.storage.loadCount()
        XCTAssertEqual(loads, 0, "fail 策略不得以缓存替代结果")
    }

    // MARK: - useCache 策略

    func testUseCacheReturnsFreshCacheForEligibleEndpointOnDisconnection() async throws {
        for failure in [URLError(.notConnectedToInternet), URLError(.networkConnectionLost)] {
            let harness = try await OfflineHarness(
                request: OfflineReadableRequest(),
                policy: .useCache,
                cachedAt: Date(timeIntervalSince1970: 1_000),
                now: Date(timeIntervalSince1970: 1_060),
                failure: failure
            )

            let value = try await harness.execute()
            XCTAssertEqual(value.value, "cached")
        }
    }

    /// 首版不返回过期缓存：超出登记有效期后保留原始连接错误。
    func testUseCacheDoesNotReturnExpiredCache() async throws {
        let harness = try await OfflineHarness(
            request: OfflineReadableRequest(),
            policy: .useCache,
            cachedAt: Date(timeIntervalSince1970: 1_000),
            now: Date(timeIntervalSince1970: 1_000 + OfflineReadableRequest.maxAge + 1),
            failure: URLError(.notConnectedToInternet)
        )

        await harness.expectTransportFailure(.notConnected)
    }

    func testUseCacheKeepsConnectionErrorWhenNoCacheExists() async throws {
        let harness = try await OfflineHarness(
            request: OfflineReadableRequest(),
            policy: .useCache,
            cachedAt: nil,
            now: Date(timeIntervalSince1970: 1_060),
            failure: URLError(.notConnectedToInternet)
        )

        await harness.expectTransportFailure(.notConnected)
    }

    /// 身份不匹配的缓存视为不可用，不得跨会话返回个人数据。
    func testUseCacheRejectsCacheSavedUnderAnotherIdentity() async throws {
        let harness = try await OfflineHarness(
            request: OfflineReadableRequest(),
            policy: .useCache,
            cachedAt: Date(timeIntervalSince1970: 1_000),
            now: Date(timeIntervalSince1970: 1_060),
            failure: URLError(.notConnectedToInternet),
            cacheUserID: "another-user"
        )

        await harness.expectTransportFailure(.notConnected)
    }

    func testUseCacheRejectsCorruptedCacheRecord() async throws {
        let harness = try await OfflineHarness(
            request: OfflineReadableRequest(),
            policy: .useCache,
            cachedAt: Date(timeIntervalSince1970: 1_000),
            now: Date(timeIntervalSince1970: 1_060),
            failure: URLError(.notConnectedToInternet),
            corruptCache: true
        )

        await harness.expectTransportFailure(.notConnected)
    }

    // MARK: - 非断网错误不回退

    func testTimeoutAndCancellationDoNotFallBackToCache() async throws {
        for (failure, expected) in [
            (URLError(.timedOut), APITransportFailure.timedOut),
            (URLError(.cancelled), APITransportFailure.cancelled),
        ] {
            let harness = try await OfflineHarness(
                request: OfflineReadableRequest(),
                policy: .useCache,
                cachedAt: Date(timeIntervalSince1970: 1_000),
                now: Date(timeIntervalSince1970: 1_060),
                failure: failure
            )

            await harness.expectTransportFailure(expected)
            let loads = await harness.storage.loadCount()
            XCTAssertEqual(loads, 0, "非断网原因不得读取缓存")
        }
    }

    func testHTTPErrorDoesNotFallBackToCache() async throws {
        let harness = try await OfflineHarness(
            request: OfflineReadableRequest(),
            policy: .useCache,
            cachedAt: Date(timeIntervalSince1970: 1_000),
            now: Date(timeIntervalSince1970: 1_060),
            statusCode: 503
        )

        do {
            _ = try await harness.execute()
            XCTFail("HTTP 错误必须保持原语义")
        } catch let APIClientError.http(statusCode) {
            XCTAssertEqual(statusCode, 503)
        }
        let loads = await harness.storage.loadCount()
        XCTAssertEqual(loads, 0)
    }
}

// MARK: - Fixtures

private struct OfflinePayload: Decodable, Equatable {
    let value: String
}

/// 只有保存资格、没有离线读取资格的端点。
private struct StoredOnlyRequest: APIRequest {
    typealias Response = OfflinePayload
    let method: APIHTTPMethod = .get
    let path = "/stored-only"
    let responseEnvelope: APIResponseEnvelope = .data
    let storagePolicy: APIStoragePolicy = .store
    let authenticationPolicy: APIAuthenticationPolicy = .none
}

/// 测试专用：完成离线资格登记的只读端点。
private struct OfflineReadableRequest: APIRequest {
    typealias Response = OfflinePayload
    static let maxAge: TimeInterval = 600

    let method: APIHTTPMethod = .get
    let path = "/offline-readable"
    let responseEnvelope: APIResponseEnvelope = .data
    let storagePolicy: APIStoragePolicy = .store
    let authenticationPolicy: APIAuthenticationPolicy = .none
    let offlineEligibility: OfflineEligibility? = OfflineEligibility(
        upstreamBasis: "W1 测试端点，不对应任何生产上游合同",
        maxAge: OfflineReadableRequest.maxAge
    )
}

private actor OfflineStorageSpy: APIStorage {
    private var values: [String: Data]
    private var loads = 0

    init(values: [String: Data] = [:]) { self.values = values }

    func save(_ data: Data, for key: String) async throws { values[key] = data }
    func load(for key: String) async throws -> Data? {
        loads += 1
        return values[key]
    }
    func remove(for key: String) async throws { values.removeValue(forKey: key) }
    func removeAll() async throws { values.removeAll() }
    func loadCount() -> Int { loads }
}

private struct OfflineHarness<Request: APIRequest> where Request.Response == OfflinePayload {
    let storage: OfflineStorageSpy
    let client: AlamofireRemoteAPIClient
    let request: Request

    init(
        request: Request,
        policy: OfflinePolicy,
        cachedAt: Date?,
        now: Date,
        failure: URLError? = nil,
        statusCode: Int? = nil,
        cacheUserID: String = "user-1",
        corruptCache: Bool = false
    ) async throws {
        self.request = request
        let service = APIServiceIdentity.testService(environment: "test")
        let context = APIStorageContext(schemaVersion: "v1", service: service, userID: "user-1")
        var seeded: [String: Data] = [:]
        if let cachedAt {
            let key = StorageKey.make(
                for: request,
                schemaVersion: "v1",
                service: service,
                userID: "user-1"
            )
            if corruptCache {
                seeded[key] = Data("not-a-record".utf8)
            } else {
                let record = CachedResponseRecord(
                    payload: Data(#"{"data":{"value":"cached"}}"#.utf8),
                    savedAt: cachedAt,
                    requestIdentifier: request.identifier,
                    serviceNamespace: service.storageNamespace,
                    userID: cacheUserID,
                    cacheControl: APICacheControl(headerValue: "max-age=600"),
                    validators: APIResponseValidators()
                )
                seeded[key] = try record.encoded()
            }
        }
        storage = OfflineStorageSpy(values: seeded)

        OfflineURLProtocol.handler = { request in
            if let failure { throw failure }
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode ?? 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"data":{"value":"remote"}}"#.utf8))
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineURLProtocol.self]
        client = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://api.example.test/api/v1")!,
            session: Session(configuration: configuration),
            storage: storage,
            storageContext: context,
            offlinePolicy: policy,
            accessToken: { nil },
            now: { now }
        )
    }

    func execute() async throws -> OfflinePayload {
        try await client.execute(request)
    }

    func expectTransportFailure(
        _ expected: APITransportFailure,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await execute()
            XCTFail("Expected a transport failure", file: file, line: line)
        } catch let APIClientError.transport(reason) {
            XCTAssertEqual(reason, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }
}

private final class OfflineURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let (response, data) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
