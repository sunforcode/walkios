import XCTest
import Alamofire
import WalkData

/// W1-4：数据模式的能力装配与 `local` 下线。
///
/// 依据 specs/README.md：
/// - R-MODE：统一业务访问入口保持类型化，数据能力分为 Mock 与真实两类；
///   `real / remoteOnly` 使用同一类真实实现，通过策略装配区分。
/// - R-MIGRATION：`local` 没有等价新模式，显式报不支持；
///   缓存回放需要在测试中直接注入，不能映射为真实网络或 remoteOnly。
///
/// 本片验证 WalkData 侧的可组合装配。App 的配置解析与依赖装配归 W2。
final class DataModeAssemblyTests: XCTestCase {

    // MARK: - 模式与能力的对应

    func testWalkDataModeHasExactlyThreeCasesWithoutLocal() {
        XCTAssertEqual(Set(WalkDataMode.allCases), [.mock, .real, .remoteOnly])
        XCTAssertNil(WalkDataMode(rawValue: "local"), "local 没有等价新模式")
    }

    func testRealAndRemoteOnlyBothUseRealNetworkCapability() {
        XCTAssertTrue(WalkDataMode.real.usesRealNetwork)
        XCTAssertTrue(WalkDataMode.remoteOnly.usesRealNetwork)
        XCTAssertFalse(WalkDataMode.mock.usesRealNetwork)
    }

    /// remoteOnly 是模式硬约束：任何缓存策略都不能覆盖它。
    func testRemoteOnlyForcesCacheDisabledRegardlessOfSelectedPolicy() {
        for policy in [OfflinePolicy.fail, .useCache] {
            XCTAssertEqual(
                WalkDataMode.remoteOnly.responseCachePolicy,
                .disabled,
                "remoteOnly 必须禁用响应缓存"
            )
            XCTAssertEqual(
                WalkDataMode.remoteOnly.effectiveOfflinePolicy(selected: policy),
                .fail,
                "remoteOnly 下任何策略都不得启用缓存回退"
            )
        }
    }

    func testRealModeHonoursSelectedOfflinePolicy() {
        XCTAssertEqual(WalkDataMode.real.responseCachePolicy, .enabled)
        XCTAssertEqual(WalkDataMode.real.effectiveOfflinePolicy(selected: .useCache), .useCache)
        XCTAssertEqual(WalkDataMode.real.effectiveOfflinePolicy(selected: .fail), .fail)
    }

    // MARK: - remoteOnly 的真实行为

    /// remoteOnly 在已有合格缓存且断网时仍返回网络错误，不读缓存。
    func testRemoteOnlyDoesNotFallBackEvenWithEligibleFreshCache() async throws {
        let request = ReplayableRequest()
        let service = APIServiceIdentity.testService(environment: "test")
        let key = StorageKey.make(for: request, schemaVersion: "v1", service: service, userID: "user-1")
        let record = CachedResponseRecord(
            payload: Data(#"{"data":{"value":"cached"}}"#.utf8),
            savedAt: Date(timeIntervalSince1970: 1_000),
            requestIdentifier: request.identifier,
            serviceNamespace: service.storageNamespace,
            userID: "user-1",
            cacheControl: APICacheControl(headerValue: "max-age=600"),
            validators: APIResponseValidators()
        )
        let storage = CountingStorage(values: [key: try record.encoded()])
        ModeURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ModeURLProtocol.self]
        let mode = WalkDataMode.remoteOnly
        let client = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://api.example.test/api/v1")!,
            session: Session(configuration: configuration),
            storage: storage,
            storageContext: APIStorageContext(schemaVersion: "v1", service: service, userID: "user-1"),
            responseCachePolicy: mode.responseCachePolicy,
            offlinePolicy: mode.effectiveOfflinePolicy(selected: .useCache),
            accessToken: { nil },
            now: { Date(timeIntervalSince1970: 1_060) }
        )

        do {
            _ = try await client.execute(request)
            XCTFail("remoteOnly 必须返回网络错误")
        } catch let APIClientError.transport(reason) {
            XCTAssertEqual(reason, .notConnected)
        }
        let counts = await storage.counts()
        XCTAssertEqual(counts.loads, 0, "remoteOnly 不访问响应缓存")
        XCTAssertEqual(counts.saves, 0)
    }

    /// real 模式下同一端点同一缓存可以回退，证明差异确实来自策略装配而非端点。
    func testRealModeWithUseCacheFallsBackForTheSameEndpointAndCache() async throws {
        let request = ReplayableRequest()
        let service = APIServiceIdentity.testService(environment: "test")
        let key = StorageKey.make(for: request, schemaVersion: "v1", service: service, userID: "user-1")
        let record = CachedResponseRecord(
            payload: Data(#"{"data":{"value":"cached"}}"#.utf8),
            savedAt: Date(timeIntervalSince1970: 1_000),
            requestIdentifier: request.identifier,
            serviceNamespace: service.storageNamespace,
            userID: "user-1",
            cacheControl: APICacheControl(headerValue: "max-age=600"),
            validators: APIResponseValidators()
        )
        let storage = CountingStorage(values: [key: try record.encoded()])
        ModeURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ModeURLProtocol.self]
        let mode = WalkDataMode.real
        let client = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://api.example.test/api/v1")!,
            session: Session(configuration: configuration),
            storage: storage,
            storageContext: APIStorageContext(schemaVersion: "v1", service: service, userID: "user-1"),
            responseCachePolicy: mode.responseCachePolicy,
            offlinePolicy: mode.effectiveOfflinePolicy(selected: .useCache),
            accessToken: { nil },
            now: { Date(timeIntervalSince1970: 1_060) }
        )

        let value = try await client.execute(request)
        XCTAssertEqual(value.value, "cached")
    }

    // MARK: - Mock 不触达真实网络

    func testMockModeIssuesNoRealBusinessHTTP() async throws {
        ModeURLProtocol.handler = { _ in
            XCTFail("mock 模式不得发起真实业务请求")
            throw URLError(.badURL)
        }
        let request = ReplayableRequest()
        let client = MockAPIClient(
            fixtures: [request.identifier: Data(#"{"data":{"value":"mocked"}}"#.utf8)]
        )

        let value = try await client.execute(request)
        XCTAssertEqual(value.value, "mocked")
    }
}

// MARK: - Fixtures

private struct ReplayPayload: Decodable, Equatable {
    let value: String
}

private struct ReplayableRequest: APIRequest {
    typealias Response = ReplayPayload
    let method: APIHTTPMethod = .get
    let path = "/replayable"
    let responseEnvelope: APIResponseEnvelope = .data
    let storagePolicy: APIStoragePolicy = .store
    let authenticationPolicy: APIAuthenticationPolicy = .none
    let offlineEligibility: OfflineEligibility? = OfflineEligibility(
        upstreamBasis: "W1 测试端点，不对应任何生产上游合同",
        maxAge: 600
    )
}

private actor CountingStorage: APIStorage {
    private var values: [String: Data]
    private var loads = 0
    private var saves = 0

    init(values: [String: Data] = [:]) { self.values = values }

    func save(_ data: Data, for key: String) async throws {
        saves += 1
        values[key] = data
    }
    func load(for key: String) async throws -> Data? {
        loads += 1
        return values[key]
    }
    func remove(for key: String) async throws { values.removeValue(forKey: key) }
    func removeAll() async throws { values.removeAll() }
    func counts() -> (loads: Int, saves: Int) { (loads, saves) }
}

private final class ModeURLProtocol: URLProtocol {
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
