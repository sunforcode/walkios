import XCTest
import Alamofire
import WalkData

/// W1-1：传输失败必须以结构化原因表达，供后续断网策略判定使用。
/// 依据 specs/README.md R-CACHE-POLICY：「断网原因来自结构化传输错误，不解析错误文案」。
/// 本片只建立原因分类，不实现任何缓存回退。
final class TransportFailureTests: XCTestCase {
    func testNotConnectedMapsToStructuredNotConnectedReason() async {
        await assertTransportFailure(
            from: URLError(.notConnectedToInternet),
            equals: .notConnected
        )
    }

    func testConnectionLostMapsToStructuredConnectionLostReason() async {
        await assertTransportFailure(
            from: URLError(.networkConnectionLost),
            equals: .connectionLost
        )
    }

    func testTimeoutKeepsItsOwnReasonAndIsNotConflatedWithDisconnection() async {
        await assertTransportFailure(
            from: URLError(.timedOut),
            equals: .timedOut
        )
    }

    func testCancellationKeepsItsOwnReason() async {
        await assertTransportFailure(
            from: URLError(.cancelled),
            equals: .cancelled
        )
    }

    /// 未归类的传输问题保留底层描述，但不得被当作断网。
    func testUnclassifiedTransportProblemPreservesUnderlyingDescription() async {
        let underlying = URLError(.cannotFindHost)
        let failure = await transportFailure(from: underlying)

        guard case .other(let description)? = failure else {
            return XCTFail("Expected an unclassified transport reason, got \(String(describing: failure))")
        }
        XCTAssertFalse(description.isEmpty)
        XCTAssertNotEqual(failure, .notConnected)
        XCTAssertNotEqual(failure, .connectionLost)
    }

    /// 结构化原因必须独立于本地化文案：改变展示文案不应改变判定依据。
    func testStructuredReasonIsDistinctFromLocalizedMessage() async {
        let notConnected = await transportFailure(from: URLError(.notConnectedToInternet))
        let connectionLost = await transportFailure(from: URLError(.networkConnectionLost))

        XCTAssertEqual(notConnected, .notConnected)
        XCTAssertEqual(connectionLost, .connectionLost)
        XCTAssertNotEqual(notConnected, connectionLost)
        XCTAssertFalse(
            APIClientError.transport(.notConnected).errorDescription?.isEmpty ?? true,
            "结构化原因仍需提供可展示文案"
        )
    }

    /// Alamofire 主动取消不得退化为未分类原因。
    func testExplicitlyCancelledRequestReportsCancellationReason() async {
        TransportFailureURLProtocol.handler = { _ in throw URLError(.cancelled) }
        let failure = await executeAndCaptureTransportFailure()
        XCTAssertEqual(failure, .cancelled)
    }

    // MARK: - Helpers

    private func assertTransportFailure(
        from underlying: URLError,
        equals expected: APITransportFailure,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let failure = await transportFailure(from: underlying)
        XCTAssertEqual(failure, expected, file: file, line: line)
    }

    private func transportFailure(from underlying: URLError) async -> APITransportFailure? {
        TransportFailureURLProtocol.handler = { _ in throw underlying }
        return await executeAndCaptureTransportFailure()
    }

    private func executeAndCaptureTransportFailure() async -> APITransportFailure? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TransportFailureURLProtocol.self]
        let client = AlamofireRemoteAPIClient(
            baseURL: URL(string: "https://example.test/api/v1")!,
            session: Session(configuration: configuration),
            accessToken: { "test-token" }
        )

        do {
            _ = try await client.execute(TransportProbeRequest())
            XCTFail("Expected a transport failure")
            return nil
        } catch let APIClientError.transport(reason) {
            return reason
        } catch {
            XCTFail("Expected APIClientError.transport, got \(error)")
            return nil
        }
    }
}

private struct TransportProbePayload: Decodable {
    let value: String
}

private struct TransportProbeRequest: APIRequest {
    typealias Response = TransportProbePayload
    let method: APIHTTPMethod = .get
    let path = "/probe"
    let authenticationPolicy: APIAuthenticationPolicy = .none
}

private final class TransportFailureURLProtocol: URLProtocol {
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
