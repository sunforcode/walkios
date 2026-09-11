import Foundation

struct MockAPIClient: APIClient {
    typealias Handler = @Sendable (Data?) async throws -> Data

    private let fixtures: [String: Data]
    private let handlers: [String: Handler]

    init(fixtures: [String: Data] = [:], handlers: [String: Handler] = [:]) {
        self.fixtures = fixtures
        self.handlers = handlers
    }

    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        let data: Data
        if let handler = handlers[request.identifier] {
            data = try await handler(request.body)
        } else if let fixture = fixtures[request.identifier] {
            data = fixture
        } else {
            throw APIClientError.mockNotFound(request.identifier)
        }
        return try APIJSONDecoder.decode(
            Request.Response.self,
            from: data,
            envelope: request.responseEnvelope
        )
    }
}
