import XCTest
import Alamofire
import WalkData
import WalkDesignSystem
@testable import Walk

final class APIClientContractTests: XCTestCase {
    /// 回归：后端 `days[].weather.routeSectionContext` 是 `QualifiedValue<RouteSectionSnapshot>`（对象），
    /// 曾被客户端误建为 `QualifiedString` 导致生成成功响应解码失败。
    func testGenerationTripCreatedResponseDecodesBackendContract() throws {
        let envelope: DataEnvelope<PersonalTripGenerationResult> = try Fixture.decode("trip-generation-trip-created")
        guard case .tripCreated(let detail) = envelope.data else {
            return XCTFail("Expected tripCreated generation result")
        }
        XCTAssertEqual(detail.trip.identity, "pt_1789298043459_vTjPf9Dn")
        XCTAssertEqual(detail.days.count, 1)
        let section = try XCTUnwrap(detail.days.first?.weather.routeSectionContext?.value)
        XCTAssertEqual(section.name, "一渡-三皇山-五渡连穿 D1")
        XCTAssertEqual(section.start.name, "起点")
        XCTAssertEqual(section.end.name, "终点")
        XCTAssertEqual(section.path?.count, 2)
    }

    func testRouteDetailEnvelopeDecodesCompleteBackendContract() throws {
        let envelope: APIEnvelope<RouteDetailResponse> = try Fixture.decode("route-detail-route-1")
        let route = try envelope.unwrap()

        XCTAssertEqual(route.id, "route-1")
        XCTAssertEqual(route.coverUrl, "https://example.test/cover.jpg")
        XCTAssertEqual(route.difficulty, .moderate)
        XCTAssertEqual(route.routeType, .loop)
        XCTAssertNil(route.routeDirection)
        XCTAssertEqual(route.creator?.nickname, "山野行者")
        XCTAssertEqual(route.segmentSchemes.first?.segments.first?.startPoint?.name, "起点")
        XCTAssertEqual(route.poiPoints.first?.subCategory, "pass")
        XCTAssertEqual(route.dailyPlans.first?.segments.first?.sequenceNumber, 1)
        XCTAssertEqual(route.ratings?.ratingCount, 36)
        XCTAssertEqual(route.weatherInfo?.seasonalWeather["秋季"], "晴朗干燥")
        XCTAssertEqual(route.hitchhikeContacts.first?.phone, "13800000000")
        XCTAssertEqual(route.trackPoints.first?.imageUrl, "https://example.test/track.jpg")
    }

    func testRouteDetailDecodesNullAndUnknownEnumsWithoutInventingValues() throws {
        let json = """
        {
          "success": true,
          "message": "success",
          "data": {
            "id": "route-null",
            "name": "空值路线",
            "description": null,
            "region_id": null,
            "region": null,
            "distance": null,
            "duration": null,
            "elevation_gain": null,
            "elevation_loss": null,
            "difficulty": 999,
            "route_type": 999,
            "route_direction": null,
            "cover_url": null,
            "default_map_id": null,
            "kml_url": null,
            "gpx_url": null,
            "popularity": 0,
            "usage_count": 0,
            "is_loop": false,
            "is_favorite": false,
            "status": 1,
            "created_at": 1724544000,
            "updated_at": 1724545000,
            "created_by": null,
            "creator": null,
            "segment_schemes": [],
            "poi_points": [],
            "daily_plans": [],
            "tags": [],
            "image_urls": [],
            "ratings": null,
            "weather_info": null,
            "hitchhike_contacts": [],
            "track_points": []
          },
          "timestamp": 1724544001,
          "code": 200
        }
        """
        let envelope = try APIJSONDecoder.make().decode(
            APIEnvelope<RouteDetailResponse>.self,
            from: Data(json.utf8)
        )
        let route = try envelope.unwrap()

        XCTAssertNil(route.description)
        XCTAssertNil(route.distance)
        XCTAssertEqual(route.difficulty, .unknown(999))
        XCTAssertEqual(route.routeType, .unknown(999))
        XCTAssertEqual(route.difficulty?.displayText, "暂无数据")
        XCTAssertEqual(route.routeType?.displayText, "暂无数据")
        XCTAssertEqual(RouteDetailFormatting.text(route.description), "暂无数据")
        XCTAssertEqual(RouteDetailFormatting.number(route.distance), "—")
    }

    func testMockClientDecodesRouteDetailThroughTypedRequest() async throws {
        let data = try Fixture.data("route-detail-route-1")
        let request = RouteAPI.Detail(id: "route-1", userID: "user-1")
        let client = MockAPIClient(fixtures: [request.identifier: data])

        let route = try await client.execute(request)

        XCTAssertEqual(request.identifier, "GET /routes/route-1?userId=user-1")
        XCTAssertEqual(request.storagePolicy, .store)
        XCTAssertEqual(route.id, "route-1")
        XCTAssertEqual(route.routeType, .loop)
    }

    func testRouteDetailRetainsCompatibilityWithoutUserID() {
        let request = RouteAPI.Detail(id: "route-1")

        XCTAssertEqual(request.identifier, "GET /routes/route-1")
        XCTAssertEqual(request.storagePolicy, .store)
    }

    func testRemoteRouteDetailCanBeReadByLocalClient() async throws {
        let responseData = try Fixture.data("route-detail-route-1")
        let request = RouteAPI.Detail(id: "route-1", userID: "user-1")
        let storage = MemoryAPIStorage()
        let context = APIStorageContext(
            schemaVersion: "v1",
            environment: "test",
            userID: "user-1"
        )
        let remote = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: makeSession(statusCode: 200, data: responseData),
            storage: storage,
            storageContext: context,
            accessToken: { "test-token" }
        )

        let remoteRoute = try await remote.execute(request)
        let localRoute = try await LocalAPIClient(storage: storage, storageContext: context).execute(request)

        XCTAssertEqual(localRoute, remoteRoute)
    }

    func testRouteDetailEnumValuesMatchBackendContract() throws {
        func decodeDifficulty(_ value: Int) throws -> RouteDetailDifficulty {
            try JSONDecoder().decode(RouteDetailDifficulty.self, from: Data("\(value)".utf8))
        }
        func decodeType(_ value: Int) throws -> RouteDetailType {
            try JSONDecoder().decode(RouteDetailType.self, from: Data("\(value)".utf8))
        }

        XCTAssertEqual(try decodeDifficulty(1), .easy)
        XCTAssertEqual(try decodeDifficulty(2).displayText, "暂无数据")
        XCTAssertEqual(try decodeDifficulty(3), .moderate)
        XCTAssertEqual(try decodeDifficulty(4).displayText, "暂无数据")
        XCTAssertEqual(try decodeDifficulty(5), .hard)
        XCTAssertEqual(try decodeDifficulty(999).displayText, "暂无数据")

        XCTAssertEqual(try decodeType(0), .outAndBack)
        XCTAssertEqual(try decodeType(1), .loop)
        XCTAssertEqual(try decodeType(2), .oneWay)
        XCTAssertEqual(try decodeType(3), .multiDay)
        XCTAssertEqual(try decodeType(999).displayText, "暂无数据")
    }

    func testEnvelopeDecodesSuccessFailureAndEmptyDataFixtures() throws {
        let success: APIEnvelope<TestPayload> = try Fixture.decode("api-success")
        XCTAssertTrue(success.success)
        XCTAssertEqual(success.data?.value, "ok")
        XCTAssertEqual(success.code, 200)

        let failure: APIEnvelope<TestPayload> = try Fixture.decode("api-failure")
        XCTAssertFalse(failure.success)
        XCTAssertEqual(failure.message, "行程不存在")
        XCTAssertEqual(failure.code, 404)

        let empty: APIEnvelope<WalkData.EmptyResponse> = try Fixture.decode("api-empty")
        XCTAssertTrue(empty.success)
        XCTAssertNil(empty.data)
        XCTAssertNoThrow(try empty.unwrap())
    }

    func testSpringPageAndEpochAndISO8601DatesDecode() throws {
        let envelope: APIEnvelope<PageDTO<DatedPayload>> = try Fixture.decode("page-dates")
        let page = try envelope.unwrap()

        XCTAssertEqual(page.items.count, 1)
        XCTAssertEqual(page.number, 0)
        XCTAssertEqual(page.size, 20)
        XCTAssertEqual(page.totalElements, 1)
        XCTAssertEqual(page.totalPages, 1)
        XCTAssertEqual(page.items[0].date.timeIntervalSince1970, 1_724_544_000, accuracy: 0.001)
        XCTAssertEqual(envelope.timestamp.timeIntervalSince1970, 1_724_544_001, accuracy: 0.001)
    }

    func testTargetRequestsDeclarePublicOptionalAndRequiredAuthenticationPolicies() throws {
        XCTAssertEqual(PublicRouteAPI.Featured().authenticationPolicy, .none)
        XCTAssertEqual(PublicRouteAPI.Detail(id: "route-1").authenticationPolicy, .none)
        XCTAssertEqual(try AccountAPI.SendVerificationCode(phone: "+8613800138000").authenticationPolicy, .none)
        XCTAssertEqual(try AccountAPI.CreateSession(verificationID: "verification-1", code: "123456").authenticationPolicy, .none)
        XCTAssertEqual(AccountAPI.Current().authenticationPolicy, .required)
        XCTAssertEqual(PersonalTripAPI.Focus().authenticationPolicy, .required)
        XCTAssertEqual(PersonalEquipmentAPI.Collection().authenticationPolicy, .required)
        XCTAssertEqual(TestRequest(authenticationPolicy: .optional).authenticationPolicy, .optional)
    }

    func testRemoteAddsBearerOnlyToOptionalAndRequiredRequests() async throws {
        let responseData = try Fixture.data("api-success")
        let client = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: makeSession(statusCode: 200, data: responseData) { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            },
            accessToken: { "access-token" }
        )
        _ = try await client.execute(TestRequest(authenticationPolicy: .required))

        let optionalClient = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: makeSession(statusCode: 200, data: responseData) { request in
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            },
            accessToken: { "access-token" }
        )
        _ = try await optionalClient.execute(TestRequest(authenticationPolicy: .optional))

        let publicClient = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: makeSession(statusCode: 200, data: responseData) { request in
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            },
            accessToken: { "access-token" }
        )
        _ = try await publicClient.execute(TestRequest(authenticationPolicy: .none))
    }

    func testRequiredRequestWithoutTokenFailsBeforeTransportAndRequestsAuthentication() async {
        let invalidation = SessionInvalidationRecorder()
        let remote = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: makeSession(statusCode: 200, data: Data()) { _ in
                XCTFail("Required request without a token must not reach transport")
            },
            accessToken: { nil },
            invalidateSession: { await invalidation.invalidate() }
        )

        do {
            _ = try await remote.execute(TestRequest(authenticationPolicy: .required))
            XCTFail("Expected authentication_required")
        } catch let APIClientError.api(code, message, retryable, _) {
            XCTAssertEqual(code, "authentication_required")
            XCTAssertEqual(message, "请先登录")
            XCTAssertFalse(retryable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let invalidationCount = await invalidation.count
        XCTAssertEqual(invalidationCount, 1)
    }

    func testPublicHTTP401DoesNotInvalidateLocalSession() async {
        let invalidation = SessionInvalidationRecorder()
        let remote = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: makeSession(statusCode: 401, data: Data()),
            accessToken: { "expired-token" },
            invalidateSession: { await invalidation.invalidate() }
        )

        do {
            _ = try await remote.execute(TestRequest(authenticationPolicy: .none))
            XCTFail("Expected HTTP 401")
        } catch let APIClientError.http(statusCode) {
            XCTAssertEqual(statusCode, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let invalidationCount = await invalidation.count
        XCTAssertEqual(invalidationCount, 0)
    }

    func testHTTP401InvalidatesSessionAndCache() async {
        let invalidation = SessionInvalidationRecorder()
        let remote = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: makeSession(statusCode: 401, data: Data()),
            accessToken: { "expired-token" },
            invalidateSession: { await invalidation.invalidate() }
        )

        do {
            _ = try await remote.execute(TestRequest(authenticationPolicy: .required))
            XCTFail("Expected HTTP 401")
        } catch let APIClientError.http(statusCode) {
            XCTAssertEqual(statusCode, 401)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let invalidationCount = await invalidation.count
        XCTAssertEqual(invalidationCount, 1)
    }

    func testAuthenticationRequiredErrorInvalidatesSessionAndPreservesTypedDetails() async {
        let data = Data(
            #"{"error":{"code":"authentication_required","message":"请登录","retryable":false,"details":{"requestedTargetRouteVersionId":"route-version-1","currentPublicRouteVersionId":"route-version-2","retryAvailableAt":"2026-08-01T10:00:00Z"}}}"#.utf8
        )
        let invalidation = SessionInvalidationRecorder()
        let remote = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: makeSession(statusCode: 403, data: data),
            accessToken: { "expired-token" },
            invalidateSession: { await invalidation.invalidate() }
        )

        do {
            _ = try await remote.execute(TestRequest(authenticationPolicy: .required))
            XCTFail("Expected authentication_required")
        } catch let APIClientError.api(code, message, retryable, details) {
            XCTAssertEqual(code, "authentication_required")
            XCTAssertEqual(message, "请登录")
            XCTAssertFalse(retryable)
            XCTAssertEqual(details?.requestedTargetRouteVersionId, "route-version-1")
            XCTAssertEqual(details?.currentPublicRouteVersionId, "route-version-2")
            XCTAssertNotNil(details?.retryAvailableAt)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let invalidationCount = await invalidation.count
        XCTAssertEqual(invalidationCount, 1)
    }

    func testRequestDefaultsToNoStorageAndStorageKeyNormalizesQuery() {
        let first = TestRequest(query: [
            URLQueryItem(name: "size", value: "20"),
            URLQueryItem(name: "page", value: "0")
        ])
        let second = TestRequest(query: [
            URLQueryItem(name: "page", value: "0"),
            URLQueryItem(name: "size", value: "20")
        ])

        XCTAssertEqual(first.storagePolicy, .none)
        XCTAssertEqual(
            StorageKey.make(for: first, schemaVersion: "v1", environment: "test", userID: "user-1"),
            StorageKey.make(for: second, schemaVersion: "v1", environment: "test", userID: "user-1")
        )
        XCTAssertNotEqual(
            StorageKey.make(for: first, schemaVersion: "v1", environment: "test", userID: "user-1"),
            StorageKey.make(for: first, schemaVersion: "v1", environment: "test", userID: "user-2")
        )
        XCTAssertNotEqual(
            StorageKey.make(for: first, schemaVersion: "v1", environment: "test", userID: "user-1"),
            StorageKey.make(for: first, schemaVersion: "v1", environment: "production", userID: "user-1")
        )
    }

    func testStorageContextReadsCurrentIdentityForEveryRequest() {
        let identity = MutableIdentity("user-1")
        let context = APIStorageContext(
            schemaVersion: "v1",
            environment: "test",
            userIDProvider: { identity.value }
        )

        XCTAssertEqual(context.currentUserID, "user-1")
        identity.value = "user-2"
        XCTAssertEqual(context.currentUserID, "user-2")
    }

    func testRemoteCachesWithIdentityCapturedWhenRequestStarts() async throws {
        let responseData = try Fixture.data("api-success")
        let identity = MutableIdentity("user-a")
        let storage = MemoryAPIStorage()
        let request = TestRequest(storagePolicy: .store)
        URLProtocolStub.handler = { request in
            identity.value = "user-b"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, responseData)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: Session(configuration: configuration),
            storage: storage,
            storageContext: APIStorageContext(
                schemaVersion: "v1",
                environment: "test",
                userIDProvider: { identity.value }
            ),
            accessToken: { "test-token" }
        )

        _ = try await client.execute(request)

        let expectedKey = StorageKey.make(
            for: request,
            schemaVersion: "v1",
            environment: "test",
            userID: "user-a"
        )
        let wrongKey = StorageKey.make(
            for: request,
            schemaVersion: "v1",
            environment: "test",
            userID: "user-b"
        )
        let expectedData = try await storage.load(for: expectedKey)
        let wrongData = try await storage.load(for: wrongKey)
        XCTAssertNotNil(expectedData)
        XCTAssertNil(wrongData)
    }

    func testRemoteDoesNotWriteCacheWhenGenerationChangesDuringRequest() async throws {
        let responseData = try Fixture.data("api-success")
        let storage = MemoryAPIStorage()
        let generation = APIStorageGeneration()
        let request = TestRequest(storagePolicy: .store)
        let requestStarted = expectation(description: "request started")
        let releaseResponse = DispatchSemaphore(value: 0)
        URLProtocolStub.handler = { request in
            requestStarted.fulfill()
            releaseResponse.wait()
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, responseData)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        let client = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: Session(configuration: configuration),
            storage: storage,
            storageContext: APIStorageContext(
                schemaVersion: "v1",
                environment: "test",
                userID: "user-a"
            ),
            storageGeneration: generation,
            accessToken: { "test-token" }
        )

        let requestTask = Task { try await client.execute(request) }
        await fulfillment(of: [requestStarted], timeout: 1)
        await generation.invalidate()
        releaseResponse.signal()
        _ = try await requestTask.value

        let key = StorageKey.make(
            for: request,
            schemaVersion: "v1",
            environment: "test",
            userID: "user-a"
        )
        let cachedData = try await storage.load(for: key)
        XCTAssertNil(cachedData)
    }

    func testRemoteRemovesCacheWhenGenerationChangesDuringSave() async throws {
        let responseData = try Fixture.data("api-success")
        let generation = APIStorageGeneration()
        let storage = InvalidatingAPIStorage {
            await generation.invalidate()
        }
        let request = TestRequest(storagePolicy: .store)
        let client = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: makeSession(statusCode: 200, data: responseData),
            storage: storage,
            storageContext: APIStorageContext(
                schemaVersion: "v1",
                environment: "test",
                userID: "user-a"
            ),
            storageGeneration: generation,
            accessToken: { "test-token" }
        )

        _ = try await client.execute(request)

        let key = StorageKey.make(
            for: request,
            schemaVersion: "v1",
            environment: "test",
            userID: "user-a"
        )
        let cachedData = try await storage.load(for: key)
        XCTAssertNil(cachedData)
    }

    func testRemoteLocalAndMockClientsExecuteSameTypedRequest() async throws {
        let responseData = try Fixture.data("api-success")
        let storage = MemoryAPIStorage()
        let storedRequest = TestRequest(storagePolicy: .store)
        let session = makeSession(statusCode: 200, data: responseData)
        let remote = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: session,
            storage: storage,
            storageContext: .init(schemaVersion: "v1", environment: "test", userID: "user-1"),
            accessToken: { "test-token" }
        )

        let remoteValue = try await remote.execute(storedRequest)
        XCTAssertEqual(remoteValue.value, "ok")

        let local = LocalAPIClient(
            storage: storage,
            storageContext: .init(schemaVersion: "v1", environment: "test", userID: "user-1")
        )
        let localValue = try await local.execute(storedRequest)
        XCTAssertEqual(localValue.value, remoteValue.value)

        let mock = MockAPIClient(fixtures: [storedRequest.identifier: responseData])
        let mockValue = try await mock.execute(storedRequest)
        XCTAssertEqual(mockValue.value, remoteValue.value)
    }

    func testLocalCacheMissFailsWithoutRemoteFallback() async {
        let local = LocalAPIClient(
            storage: MemoryAPIStorage(),
            storageContext: .init(schemaVersion: "v1", environment: "test", userID: "user-1")
        )

        do {
            _ = try await local.execute(TestRequest())
            XCTFail("Expected a cache miss")
        } catch APIClientError.localDataNotFound {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHTTPErrorParsesBusinessEnvelope() async {
        let session = makeSession(statusCode: 404, data: try! Fixture.data("api-failure"))
        let remote = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: session,
            accessToken: { "test-token" }
        )

        do {
            _ = try await remote.execute(TestRequest())
            XCTFail("Expected business error")
        } catch let APIClientError.business(message, code) {
            XCTAssertEqual(message, "行程不存在")
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeSession(
        statusCode: Int,
        data: Data,
        inspectRequest: @escaping (URLRequest) -> Void = { _ in }
    ) -> Session {
        URLProtocolStub.handler = { request in
            inspectRequest(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, data)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return Session(configuration: configuration)
    }
}

private struct TestPayload: Codable, Equatable {
    let value: String
}

private struct DatedPayload: Codable {
    let date: Date
}

private struct TestRequest: APIRequest {
    typealias Response = TestPayload

    let method: APIHTTPMethod
    let path: String
    let query: [URLQueryItem]
    let body: Data?
    let storagePolicy: APIStoragePolicy
    let authenticationPolicy: APIAuthenticationPolicy

    init(
        query: [URLQueryItem] = [],
        storagePolicy: APIStoragePolicy = .none,
        authenticationPolicy: APIAuthenticationPolicy = .required
    ) {
        self.method = .get
        self.path = "/test"
        self.query = query
        self.body = nil
        self.storagePolicy = storagePolicy
        self.authenticationPolicy = authenticationPolicy
    }
}

private enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: APIClientContractTests.self).url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ name: String) throws -> T {
        try APIJSONDecoder.make().decode(T.self, from: data(name))
    }
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

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

private final class MutableIdentity: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: String

    init(_ value: String) {
        self.storedValue = value
    }

    var value: String {
        get { lock.withLock { storedValue } }
        set { lock.withLock { storedValue = newValue } }
    }
}

private actor InvalidatingAPIStorage: APIStorage {
    private var values: [String: Data] = [:]
    private let onSave: @Sendable () async -> Void

    init(onSave: @escaping @Sendable () async -> Void) {
        self.onSave = onSave
    }

    func save(_ data: Data, for key: String) async throws {
        values[key] = data
        await onSave()
    }

    func load(for key: String) async throws -> Data? { values[key] }
    func remove(for key: String) async throws { values.removeValue(forKey: key) }
    func removeAll() async throws { values.removeAll() }
}

private actor MemoryAPIStorage: APIStorage {
    private var values: [String: Data] = [:]

    func save(_ data: Data, for key: String) async throws { values[key] = data }
    func load(for key: String) async throws -> Data? { values[key] }
    func remove(for key: String) async throws { values.removeValue(forKey: key) }
    func removeAll() async throws { values.removeAll() }
}

private actor SessionInvalidationRecorder {
    private(set) var count = 0

    func invalidate() {
        count += 1
    }
}
