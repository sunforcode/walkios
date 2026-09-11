import Foundation

public struct LocalAPIClient: APIClient {
     public let storage: any APIStorage
     public let storageContext: APIStorageContext

     public func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        let key = StorageKey.make(
            for: request,
            schemaVersion: storageContext.schemaVersion,
            environment: storageContext.environment,
            userID: storageContext.currentUserID
        )
        guard let data = try await storage.load(for: key) else {
            throw APIClientError.localDataNotFound
        }
        return try APIJSONDecoder.decode(
            Request.Response.self,
            from: data,
            envelope: request.responseEnvelope
        )
    }

    public init(
        storage: any APIStorage,
        storageContext: APIStorageContext
    ) {
        self.storage = storage
        self.storageContext = storageContext
    }
}
