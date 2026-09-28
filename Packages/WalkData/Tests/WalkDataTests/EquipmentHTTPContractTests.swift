import XCTest
import Alamofire
@testable import WalkData

final class EquipmentHTTPContractTests: XCTestCase {
    func testEncodedIdentityAndQueryReachHTTPWithoutDoubleEncoding() async throws {
        let request = EncodedEquipmentProbe()
        let client = makeClient { http in
            XCTAssertEqual(http.url?.absoluteString, "https://equipment.test/walkbg/api/v1/equipment-lists/a%2Fb%3F%23%25%20%E4%B8%AD:copy?keyword=a%2Bb%26%25%20%E4%B8%AD")
            XCTAssertEqual(http.httpMethod, "POST")
            XCTAssertEqual(http.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(http.value(forHTTPHeaderField: "Idempotency-Key"), "original-operation")
            XCTAssertEqual(http.value(forHTTPHeaderField: "If-Match"), "\"revision-1\"")
            return (200, ["ETag": "\"revision-1\""], Data(#"{"data":{"revision":"revision-1"}}"#.utf8))
        }
        let response = try await client.execute(request)
        XCTAssertEqual(response.revision, "revision-1")
    }

    func testResponseValidationRejectsInconsistentVersion() async throws {
        let client = makeClient { _ in
            (200, ["ETag": "\"different\""], Data(#"{"data":{"revision":"revision-1"}}"#.utf8))
        }
        do {
            _ = try await client.execute(EncodedEquipmentProbe())
            XCTFail("Expected inconsistent response metadata to be rejected")
        } catch {
            XCTAssertEqual(error as? APIClientError, .invalidResponse)
        }
    }

    func testOpaqueSegmentsKeepReservedCharactersAndDotIdentities() {
        XCTAssertEqual(APIPathSegment.encode("a/b?#% 中"), "a%2Fb%3F%23%25%20%E4%B8%AD")
        XCTAssertEqual(APIPathSegment.encode(".."), "%2E%2E")
        XCTAssertEqual(APIPathSegment.encode("."), "%2E")
        XCTAssertEqual(APIPathSegment.encode("asset_1-2.3~4"), "asset_1-2.3~4")
    }

    func testBusinessFailuresPreserveStatusSpecificCodesAndRetryability() async throws {
        let failures: [(Int, String, Bool)] = [
            (400, "invalid_request", false),
            (401, "authentication_required", false),
            (404, "resource_not_found", false),
            (409, "concurrent_modification", false),
            (409, "idempotency_conflict", false),
            (409, "equipment_name_conflict", false),
            (409, "trip_equipment_read_only", false),
            (409, "relationship_inconsistent", false),
            (422, "validation_failed", false),
            (503, "equipment_catalog_unavailable", true),
            (503, "trip_equipment_unavailable", true)
        ]
        for (status, code, retryable) in failures {
            var invalidations = 0
            let client = makeClient(invalidateSession: { invalidations += 1 }) { _ in
                let data = try JSONSerialization.data(withJSONObject: [
                    "error": ["code": code, "message": "请求失败", "retryable": retryable]
                ])
                return (status, [:], data)
            }
            do {
                _ = try await client.execute(EncodedEquipmentProbe())
                XCTFail("Expected \(code)")
            } catch {
                XCTAssertEqual(error as? APIClientError, .api(code: code, message: "请求失败", retryable: retryable))
            }
            XCTAssertEqual(invalidations, status == 401 ? 1 : 0)
        }
    }

    func testMissingSessionStopsBeforeHTTP() async throws {
        var invalidated = false
        let client = makeClient(token: nil, invalidateSession: { invalidated = true }) { _ in
            XCTFail("Unauthenticated request must not reach HTTP")
            return (200, [:], Data())
        }
        do {
            _ = try await client.execute(EncodedEquipmentProbe())
            XCTFail("Expected authentication failure")
        } catch let APIClientError.api(code, _, retryable, _) {
            XCTAssertEqual(code, "authentication_required")
            XCTAssertFalse(retryable)
        }
        XCTAssertTrue(invalidated)
    }

    func testRetryKeepsOriginalIdempotencyKeyAndRevision() async throws {
        var attempts = 0
        let client = makeClient { request in
            attempts += 1
            XCTAssertEqual(request.value(forHTTPHeaderField: "Idempotency-Key"), "original-operation")
            XCTAssertEqual(request.value(forHTTPHeaderField: "If-Match"), "\"revision-1\"")
            if attempts == 1 { throw URLError(.networkConnectionLost) }
            return (200, ["ETag": "\"revision-1\""], Data(#"{"data":{"revision":"revision-1"}}"#.utf8))
        }
        let request = EncodedEquipmentProbe()
        do {
            _ = try await client.execute(request)
            XCTFail("Expected first attempt to lose its connection")
        } catch let APIClientError.transport(failure) {
            XCTAssertEqual(failure, .connectionLost)
        }
        _ = try await client.execute(request)
        XCTAssertEqual(attempts, 2)
    }

    func testCatalogSearchSendsLiteralQueryThroughRemoteClient() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/walkbg/api/v1/equipment-catalog/items")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let query = Dictionary(uniqueKeysWithValues: components.queryItems!.map { ($0.name, $0.value!) })
            XCTAssertEqual(query["keyword"], "  C++ 50%_中  ")
            XCTAssertEqual(query["brandId"], "brand/A?#")
            XCTAssertEqual(query["minWeightGrams"], "12.5")
            XCTAssertTrue(components.percentEncodedQuery!.contains("%2B%2B"))
            return (200, [:], Data(#"{"data":{"items":[]}}"#.utf8))
        }
        let response = try await client.execute(EquipmentCatalogAPI.Items(
            keyword: "  C++ 50%_中  ", brandID: "brand/A?#", minWeightGrams: 12.5
        ))
        XCTAssertTrue(response.items.isEmpty)
    }

    func testResetPackingSendsNoJSONBodyAndValidatesReturnedVersion() async throws {
        let client = makeClient { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url!.absoluteString.hasSuffix("/trips/trip%2FA/equipment:reset-packing"))
            XCTAssertNil(request.httpBody)
            XCTAssertNil(request.httpBodyStream)
            XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "If-Match"), "\"revision-1\"")
            return (200, ["ETag": "\"revision-2\""], self.emptySnapshot)
        }
        let response = try await client.execute(TripEquipmentAPI.ResetPacking(tripID: "trip/A", revision: "revision-1"))
        XCTAssertEqual(response.revision, "revision-2")
        XCTAssertTrue(response.snapshot.items.isEmpty)
    }

    func testTripEndpointRejectsMissingWeakAndMismatchedETags() async throws {
        for headers in [[:], ["ETag": "W/\"revision-2\""], ["ETag": "\"old\""]] {
            let client = makeClient { _ in (200, headers, self.emptySnapshot) }
            do {
                _ = try await client.execute(TripEquipmentAPI.Current(tripID: "trip/A"))
                XCTFail("Expected endpoint metadata validation")
            } catch {
                XCTAssertEqual(error as? APIClientError, .invalidResponse)
            }
        }
    }

    private var emptySnapshot: Data {
        Data(#"{"data":{"trip":{"identity":"trip/A","status":"planned","routeName":"山径","startDate":"2026-10-01","endDate":"2026-10-02"},"revision":"revision-2","editable":true,"snapshot":{"identity":"snapshot","items":[],"summary":{"itemCount":0,"knownTotalWeight":{"grams":0},"ownedItemCount":0,"unconfirmedOwnedItemCount":0,"missingWeightItemCount":0}}}}"#.utf8)
    }

    private func makeClient(
        token: String? = "test-token",
        invalidateSession: @escaping () async -> Void = {},
        handler: @escaping (URLRequest) throws -> (Int, [String: String], Data)
    ) -> AlamofireRemoteAPIClient {
        EquipmentHTTPStub.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [EquipmentHTTPStub.self]
        return AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://equipment.test/walkbg/api/v1")!,
            session: Session(configuration: configuration),
            accessToken: { token },
            invalidateSession: invalidateSession
        )
    }
}

private struct EncodedEquipmentProbe: APIRequest {
    struct Response: Decodable { let revision: String }
    let method: APIHTTPMethod = .post
    let path = "/equipment-lists/a%2Fb%3F%23%25%20%E4%B8%AD:copy"
    let pathIsPercentEncoded = true
    let query = [URLQueryItem(name: "keyword", value: "a+b&% 中")]
    let responseEnvelope: APIResponseEnvelope = .data
    let headers = ["Idempotency-Key": "original-operation", "If-Match": "\"revision-1\""]

    func validateResponse(_ response: Response, statusCode: Int, headers: [String: String]) throws {
        guard headers.first(where: { $0.key.lowercased() == "etag" })?.value == "\"\(response.revision)\"" else {
            throw APIClientError.invalidResponse
        }
    }
}

private final class EquipmentHTTPStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, [String: String], Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, headers, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
