import Foundation

public enum PublicRouteAPI {
    public struct Featured: APIRequest {
        public typealias Response = PublicRouteDiscoveryResult

        public let method: APIHTTPMethod = .get
        public let path = "/public-routes/featured"
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store
        public let authenticationPolicy: APIAuthenticationPolicy = .none

        public init() {}
    }

    public struct All: APIRequest {
        public typealias Response = PublicRouteCollectionResult

        public let method: APIHTTPMethod = .get
        public let path = "/public-routes"
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store
        public let authenticationPolicy: APIAuthenticationPolicy = .none

        public init() {}
    }

    public struct Search: APIRequest {
        public typealias Response = PublicRouteSearchResult

        public let method: APIHTTPMethod = .get
        public let path = "/public-routes/search"
        public let query: [URLQueryItem]
        public let responseEnvelope: APIResponseEnvelope = .data
        public let authenticationPolicy: APIAuthenticationPolicy = .none

        public init(query: String?) {
            self.query = query.map { [URLQueryItem(name: "query", value: $0)] } ?? []
        }
    }

    public struct Detail: APIRequest {
        public typealias Response = PublicRouteDetail

        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store
        public let authenticationPolicy: APIAuthenticationPolicy = .none

        public init(id: String) {
            path = "/public-routes/\(id)"
        }
    }
}

public enum RouteAPI {
    public struct Detail: APIRequest {
        public typealias Response = RouteDetailResponse

        public let method: APIHTTPMethod = .get
        public let path: String
        public let query: [URLQueryItem]
        public let storagePolicy: APIStoragePolicy = .store

        public init(id: String, userID: String? = nil) {
            path = "/routes/\(id)"
            query = userID.map { [URLQueryItem(name: "userId", value: $0)] } ?? []
        }
    }

    public struct Favorite: APIRequest {
        public typealias Response = EmptyResponse

        public let method: APIHTTPMethod
        public let path: String
        public let query: [URLQueryItem]

        public init(id: String, userID: String, isFavorite: Bool) {
            method = isFavorite ? .post : .delete
            path = "/routes/\(id)/favorite"
            query = [URLQueryItem(name: "userId", value: userID)]
        }
    }
}
