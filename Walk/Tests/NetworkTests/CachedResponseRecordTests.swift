import XCTest
import WalkData

/// W1-2：缓存记录必须携带策略所需元数据，命名空间必须隔离服务身份。
///
/// 依据 specs/README.md：
/// - R-STORAGE：缓存记录包含业务响应及必要的请求匹配、来源时间和缓存控制元数据；
///   命名空间至少隔离服务身份、模型版本、会话/用户、请求及影响响应的表示差异；
///   旧的纯 JSON 快照缺少策略所需元数据时，不能直接升级为可离线返回的缓存。
/// - R-AUTH：服务地址的身份包括协议、主机、有效端口和 API 基路径，不能仅比较显示名称。
///
/// 本片只建立记录格式与命名空间，不实现任何离线回退。
final class CachedResponseRecordTests: XCTestCase {

    // MARK: - 服务身份

    func testSameEnvironmentNameWithDifferentAddressesAreDistinctServices() {
        let first = APIServiceIdentity(
            environmentName: "development",
            baseURL: URL(string: "https://vialu.cn/walkbg/api/v1")!
        )
        let second = APIServiceIdentity(
            environmentName: "development",
            baseURL: URL(string: "https://staging.vialu.cn/walkbg/api/v1")!
        )

        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first.storageNamespace, second.storageNamespace)
    }

    /// 现有 DebugEnvironment 的 testServer 与 production 正是同地址不同名称。
    func testSameAddressWithDifferentEnvironmentNamesAreDistinctServices() {
        let address = URL(string: "https://vialu.cn/walkbg/api/v1")!
        let development = APIServiceIdentity(environmentName: "development", baseURL: address)
        let production = APIServiceIdentity(environmentName: "production", baseURL: address)

        XCTAssertNotEqual(development, production)
        XCTAssertNotEqual(development.storageNamespace, production.storageNamespace)
    }

    func testSchemeHostPortAndBasePathAllParticipateInIdentity() {
        let base = APIServiceIdentity(
            environmentName: "test",
            baseURL: URL(string: "https://api.example.test:8443/walkbg/api/v1")!
        )
        let otherScheme = APIServiceIdentity(
            environmentName: "test",
            baseURL: URL(string: "http://api.example.test:8443/walkbg/api/v1")!
        )
        let otherPort = APIServiceIdentity(
            environmentName: "test",
            baseURL: URL(string: "https://api.example.test:9443/walkbg/api/v1")!
        )
        let otherPath = APIServiceIdentity(
            environmentName: "test",
            baseURL: URL(string: "https://api.example.test:8443/walkbg/api/v2")!
        )

        XCTAssertNotEqual(base, otherScheme)
        XCTAssertNotEqual(base, otherPort)
        XCTAssertNotEqual(base, otherPath)
    }

    /// 默认端口与显式默认端口指向同一服务，尾斜杠与大小写主机同理。
    func testEquivalentAddressFormsNormalizeToTheSameService() {
        let implicitPort = APIServiceIdentity(
            environmentName: "test",
            baseURL: URL(string: "https://API.Example.test/walkbg/api/v1/")!
        )
        let explicitPort = APIServiceIdentity(
            environmentName: "test",
            baseURL: URL(string: "https://api.example.test:443/walkbg/api/v1")!
        )

        XCTAssertEqual(implicitPort, explicitPort)
        XCTAssertEqual(implicitPort.storageNamespace, explicitPort.storageNamespace)
    }

    func testStorageKeySeparatesServiceUserSchemaAndRequest() {
        let request = CacheProbeRequest()
        let service = APIServiceIdentity(
            environmentName: "test",
            baseURL: URL(string: "https://api.example.test/v1")!
        )
        let otherService = APIServiceIdentity(
            environmentName: "test",
            baseURL: URL(string: "https://other.example.test/v1")!
        )
        let key = StorageKey.make(for: request, schemaVersion: "v1", service: service, userID: "user-1")

        XCTAssertNotEqual(
            key,
            StorageKey.make(for: request, schemaVersion: "v1", service: otherService, userID: "user-1")
        )
        XCTAssertNotEqual(
            key,
            StorageKey.make(for: request, schemaVersion: "v1", service: service, userID: "user-2")
        )
        XCTAssertNotEqual(
            key,
            StorageKey.make(for: request, schemaVersion: "v2", service: service, userID: "user-1")
        )
    }

    // MARK: - 缓存控制指令解析

    func testCacheControlParsesNoStoreNoCacheAndMaxAge() {
        XCTAssertTrue(APICacheControl(headerValue: "no-store").noStore)
        XCTAssertTrue(APICacheControl(headerValue: "no-cache, max-age=60").noCache)
        XCTAssertEqual(APICacheControl(headerValue: "max-age=600").maxAge, 600)
        XCTAssertEqual(APICacheControl(headerValue: "  MAX-AGE = 90 ").maxAge, 90)
        XCTAssertNil(APICacheControl(headerValue: nil).maxAge)
        XCTAssertFalse(APICacheControl(headerValue: nil).noStore)
    }

    // MARK: - 记录格式

    func testRecordRoundTripPreservesPayloadOriginTimeAndMetadata() throws {
        let savedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let record = CachedResponseRecord(
            payload: Data(#"{"data":{"value":"ok"}}"#.utf8),
            savedAt: savedAt,
            requestIdentifier: "GET /probe",
            serviceNamespace: "test|https://api.example.test/v1",
            userID: "user-1",
            cacheControl: APICacheControl(headerValue: "max-age=600"),
            validators: APIResponseValidators(eTag: "\"abc\"", lastModified: "Wed, 21 Oct 2026 07:28:00 GMT")
        )

        let decoded = try CachedResponseRecord.decode(from: try record.encoded())

        XCTAssertEqual(decoded, record)
        XCTAssertEqual(decoded.savedAt, savedAt)
        XCTAssertEqual(decoded.cacheControl.maxAge, 600)
        XCTAssertEqual(decoded.validators.eTag, "\"abc\"")
        XCTAssertEqual(decoded.formatVersion, CachedResponseRecord.currentFormatVersion)
    }

    /// 旧的纯 JSON 快照没有元数据，必须判定为不可用，不能升级为可离线返回的缓存。
    func testLegacyRawSnapshotIsRejectedInsteadOfUpgraded() {
        let legacy = Data(#"{"data":{"value":"cached"}}"#.utf8)

        XCTAssertThrowsError(try CachedResponseRecord.decode(from: legacy)) { error in
            XCTAssertEqual(error as? CachedResponseRecordError, .unreadable)
        }
    }

    func testUnknownFormatVersionIsRejected() throws {
        let record = CachedResponseRecord(
            payload: Data("{}".utf8),
            savedAt: Date(timeIntervalSince1970: 0),
            requestIdentifier: "GET /probe",
            serviceNamespace: "ns",
            userID: "user-1",
            cacheControl: APICacheControl(headerValue: nil),
            validators: APIResponseValidators()
        )
        var object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: try record.encoded()) as? [String: Any]
        )
        object["formatVersion"] = CachedResponseRecord.currentFormatVersion + 1
        let forward = try JSONSerialization.data(withJSONObject: object)

        XCTAssertThrowsError(try CachedResponseRecord.decode(from: forward)) { error in
            XCTAssertEqual(error as? CachedResponseRecordError, .unsupportedFormatVersion)
        }
    }

    /// 记录自带身份，读取时必须与当前身份比对，防止错配缓存被当作命中。
    func testRecordRejectsMismatchedServiceOrUserOrRequest() {
        let record = CachedResponseRecord(
            payload: Data("{}".utf8),
            savedAt: Date(timeIntervalSince1970: 0),
            requestIdentifier: "GET /probe",
            serviceNamespace: "ns-a",
            userID: "user-1",
            cacheControl: APICacheControl(headerValue: nil),
            validators: APIResponseValidators()
        )

        XCTAssertTrue(record.matches(requestIdentifier: "GET /probe", serviceNamespace: "ns-a", userID: "user-1"))
        XCTAssertFalse(record.matches(requestIdentifier: "GET /probe", serviceNamespace: "ns-b", userID: "user-1"))
        XCTAssertFalse(record.matches(requestIdentifier: "GET /probe", serviceNamespace: "ns-a", userID: "user-2"))
        XCTAssertFalse(record.matches(requestIdentifier: "GET /other", serviceNamespace: "ns-a", userID: "user-1"))
    }

    /// `no-store` 响应不得保存，这是 RFC 9111 的硬约束，不受端点资格或策略影响。
    func testNoStoreResponseIsNotEligibleForPersistence() {
        let noStore = CachedResponseRecord.isPersistable(
            cacheControl: APICacheControl(headerValue: "no-store"),
            storagePolicy: .store
        )
        let allowed = CachedResponseRecord.isPersistable(
            cacheControl: APICacheControl(headerValue: "max-age=600"),
            storagePolicy: .store
        )
        let notEligible = CachedResponseRecord.isPersistable(
            cacheControl: APICacheControl(headerValue: "max-age=600"),
            storagePolicy: .none
        )

        XCTAssertFalse(noStore)
        XCTAssertTrue(allowed)
        XCTAssertFalse(notEligible)
    }
}

private struct CacheProbePayload: Decodable {
    let value: String
}

private struct CacheProbeRequest: APIRequest {
    typealias Response = CacheProbePayload
    let method: APIHTTPMethod = .get
    let path = "/probe"
    let storagePolicy: APIStoragePolicy = .store
    let authenticationPolicy: APIAuthenticationPolicy = .none
}
