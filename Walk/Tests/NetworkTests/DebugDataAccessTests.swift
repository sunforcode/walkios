import XCTest
import Alamofire
import WalkData

final class DebugDataAccessTests: XCTestCase {
    func testDisabledCacheUsesNetworkWithoutReadingOrReplacingCachedResponses() async throws {
        let request = DebugCacheRequest()
        let context = APIStorageContext(schemaVersion: "v1", service: .testService(environment: "test"), userID: "user-1")
        let key = StorageKey.make(for: request, schemaVersion: "v1", service: .testService(environment: "test"), userID: "user-1")
        let oldData = Data(#"{"data":{"value":"cached"}}"#.utf8)
        let storage = DebugCacheStorageSpy(values: [key: oldData])
        let transport = DebugCacheTransport(data: Data(#"{"data":{"value":"remote"}}"#.utf8)) { request in
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Cache-Control"), "no-cache, no-store")
        }
        defer { transport.unregister() }
        let cachedRequest = URLRequest(url: transport.baseURL.appendingPathComponent("value"))
        transport.urlCache.storeCachedResponse(
            CachedURLResponse(
                response: HTTPURLResponse(url: cachedRequest.url!, statusCode: 200, httpVersion: nil,
                                          headerFields: ["Cache-Control": "max-age=3600"])!,
                data: oldData
            ),
            for: cachedRequest
        )
        let client = AlamofireRemoteAPIClient(
            baseURL: transport.baseURL,
            session: transport.session,
            storage: storage,
            storageContext: context,
            responseCachePolicy: .disabled,
            accessToken: { nil }
        )

        let value = try await client.execute(request)
        let accesses = await storage.accessCounts()
        let storedData = await storage.storedValue(for: key)

        XCTAssertEqual(value.value, "remote")
        XCTAssertEqual(accesses.loads, 0)
        XCTAssertEqual(accesses.saves, 0)
        XCTAssertEqual(storedData, oldData)
        XCTAssertEqual(transport.urlCache.cachedResponse(for: cachedRequest)?.data, oldData)
    }

    func testDisabledCachePropagatesRemoteFailureDespiteExistingSnapshot() async throws {
        let request = DebugCacheRequest()
        let key = StorageKey.make(for: request, schemaVersion: "v1", service: .testService(environment: "test"), userID: "user-1")
        let storage = DebugCacheStorageSpy(values: [key: Data(#"{"data":{"value":"cached"}}"#.utf8)])
        let transport = DebugCacheTransport(
            statusCode: 503,
            data: Data(#"{"error":{"code":"service_unavailable","message":"暂不可用","retryable":true}}"#.utf8)
        )
        defer { transport.unregister() }
        let client = AlamofireRemoteAPIClient(
            baseURL: transport.baseURL,
            session: transport.session,
            storage: storage,
            storageContext: .init(schemaVersion: "v1", service: .testService(environment: "test"), userID: "user-1"),
            responseCachePolicy: .disabled,
            accessToken: { nil }
        )

        do {
            _ = try await client.execute(request)
            XCTFail("禁缓存模式必须返回后端失败，不能返回已有快照")
        } catch let error as APIClientError {
            XCTAssertEqual(error, .api(code: "service_unavailable", message: "暂不可用", retryable: true))
        }
        let accesses = await storage.accessCounts()
        XCTAssertEqual(accesses.loads, 0)
        XCTAssertEqual(accesses.saves, 0)
    }

    func testDefaultPolicyPreservesSuccessfulResponsePersistence() async throws {
        let request = DebugCacheRequest()
        let context = APIStorageContext(schemaVersion: "v1", service: .testService(environment: "test"), userID: "user-1")
        let storage = DebugCacheStorageSpy()
        let transport = DebugCacheTransport(data: Data(#"{"data":{"value":"remote"}}"#.utf8))
        defer { transport.unregister() }
        let client = AlamofireRemoteAPIClient(
            baseURL: transport.baseURL,
            session: transport.session,
            storage: storage,
            storageContext: context,
            accessToken: { nil }
        )

        let remoteValue = try await client.execute(request)
        let accesses = await storage.accessCounts()
        let key = StorageKey.make(
            for: request,
            schemaVersion: "v1",
            service: context.service,
            userID: "user-1"
        )
        let storedData = await storage.storedValue(for: key)
        let stored = try XCTUnwrap(storedData)
        let record = try CachedResponseRecord.decode(from: stored)

        XCTAssertEqual(remoteValue.value, "remote")
        XCTAssertEqual(accesses.saves, 1)
        // 直接断言落盘记录，而不是借道另一个客户端间接推断。
        XCTAssertEqual(record.payload, Data(#"{"data":{"value":"remote"}}"#.utf8))
        XCTAssertTrue(
            record.matches(
                requestIdentifier: request.identifier,
                serviceNamespace: context.serviceNamespace,
                userID: "user-1"
            )
        )
    }

    func testDisabledDefaultSessionHasNoURLCache() {
        let session = AlamofireRemoteAPIClient.makeDefaultSession(responseCachePolicy: .disabled)

        XCTAssertNil(session.session.configuration.urlCache)
        XCTAssertEqual(session.session.configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
    }
}

private struct DebugCachePayload: Decodable, Equatable {
    let value: String
}

private struct DebugCacheRequest: APIRequest {
    typealias Response = DebugCachePayload
    let method: APIHTTPMethod = .get
    let path = "/value"
    let responseEnvelope: APIResponseEnvelope = .data
    let storagePolicy: APIStoragePolicy = .store
    let authenticationPolicy: APIAuthenticationPolicy = .none
}

private actor DebugCacheStorageSpy: APIStorage {
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
    func accessCounts() -> (loads: Int, saves: Int) { (loads, saves) }
    func storedValue(for key: String) -> Data? { values[key] }
}

private struct DebugCacheTransport {
    let baseURL: URL
    let urlCache: URLCache
    let session: Session

    init(statusCode: Int = 200, data: Data, inspect: @escaping (URLRequest) -> Void = { _ in }) {
        baseURL = URL(string: "https://\(UUID().uuidString.lowercased()).example.test/api/v1")!
        urlCache = URLCache(memoryCapacity: 1_048_576, diskCapacity: 0, diskPath: nil)
        DebugCacheURLProtocol.register(host: baseURL.host!) { request in
            inspect(request)
            return (
                HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil,
                                headerFields: ["Content-Type": "application/json", "Cache-Control": "max-age=3600"])!,
                data
            )
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [DebugCacheURLProtocol.self]
        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        session = Session(configuration: configuration)
    }

    func unregister() { DebugCacheURLProtocol.unregister(host: baseURL.host!) }
}

private final class DebugCacheURLProtocol: URLProtocol {
    typealias Handler = (URLRequest) -> (HTTPURLResponse, Data)
    private static let lock = NSLock()
    private static var handlers: [String: Handler] = [:]

    static func register(host: String, handler: @escaping Handler) {
        lock.withLock { handlers[host] = handler }
    }

    static func unregister(host: String) {
        _ = lock.withLock { handlers.removeValue(forKey: host) }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let host = request.url?.host,
              let handler = Self.lock.withLock({ Self.handlers[host] }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
