import XCTest
import Alamofire
@testable import WalkData

final class SceneArtworkHTTPTests: XCTestCase {
    func testRouteServiceRequestsExplicitVersionWithoutSessionAndDecodesDataEnvelope() async throws {
        let client = client { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.url?.absoluteString, "https://scene.test/walkbg/api/v1/public-routes/r%2F1/scenes?routeVersionId=v%2B1")
            return (200, Data(#"{"data":{"routeId":"r/1","routeVersionId":"v+1","sceneRevision":"s","days":[]}}"#.utf8))
        }
        let response = try await RouteService(apiClient: client).getRouteScenes(id: "r/1", routeVersionID: "v+1")
        XCTAssertEqual(response.routeVersionID, "v+1")
        XCTAssertTrue(response.days.isEmpty)
    }

    func testTripServiceUsesCurrentBearerAndDecodesExplicitDayAssociation() async throws {
        let client = client { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer scene-test")
            XCTAssertEqual(request.url?.absoluteString, "https://scene.test/walkbg/api/v1/trips/t%2F1/scenes")
            return (200, Data(#"{"data":{"tripId":"t/1","tripRevision":"r","routeVersionId":"v","sceneRevision":"s","days":[{"tripDayId":"actual-day","image":{"mediaId":"media","imageUrl":"https://scene.test/media.png","width":1448,"height":1086,"kind":"aigc"}}]}}"#.utf8))
        }
        let response = try await PersonalTripService(apiClient: client).scenes(tripID: "t/1")
        XCTAssertEqual(response.days.first?.tripDayID, "actual-day")
    }

    func testSceneVersionConflictPreservesAPIErrorForLocalDegradation() async throws {
        let client = client { _ in
            (409, Data(#"{"error":{"code":"route_version_conflict","message":"已变更","retryable":false}}"#.utf8))
        }
        do {
            _ = try await RouteService(apiClient: client).getRouteScenes(id: "r", routeVersionID: "old")
            XCTFail("Conflict must not decode as an empty scene collection")
        } catch {
            XCTAssertEqual(error as? APIClientError, .api(code: "route_version_conflict", message: "已变更", retryable: false))
        }
    }

    private func client(_ handler: @escaping (URLRequest) throws -> (Int, Data)) -> AlamofireRemoteAPIClient {
        SceneHTTPStub.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SceneHTTPStub.self]
        return AlamofireRemoteAPIClient(baseURL: URL(string: "https://scene.test/walkbg/api/v1")!,
                                       session: Session(configuration: configuration), accessToken: { "scene-test" })
    }
}

private final class SceneHTTPStub: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
