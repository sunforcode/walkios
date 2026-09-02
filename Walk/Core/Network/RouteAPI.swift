import Foundation

enum PublicRouteAPI {
    struct Featured: APIRequest {
        typealias Response = PublicRouteDiscoveryResult

        let method: APIHTTPMethod = .get
        let path = "/public-routes/featured"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
        let authenticationPolicy: APIAuthenticationPolicy = .none
    }

    struct All: APIRequest {
        typealias Response = PublicRouteCollectionResult

        let method: APIHTTPMethod = .get
        let path = "/public-routes"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
        let authenticationPolicy: APIAuthenticationPolicy = .none
    }

    struct Search: APIRequest {
        typealias Response = PublicRouteSearchResult

        let method: APIHTTPMethod = .get
        let path = "/public-routes/search"
        let query: [URLQueryItem]
        let responseEnvelope: APIResponseEnvelope = .data
        let authenticationPolicy: APIAuthenticationPolicy = .none

        init(query: String?) {
            self.query = query.map { [URLQueryItem(name: "query", value: $0)] } ?? []
        }
    }

    struct Detail: APIRequest {
        typealias Response = PublicRouteDetail

        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
        let authenticationPolicy: APIAuthenticationPolicy = .none

        init(id: String) {
            path = "/public-routes/\(id)"
        }
    }
}

enum RouteAPI {
    struct Detail: APIRequest {
        typealias Response = RouteDetailResponse

        let method: APIHTTPMethod = .get
        let path: String
        let query: [URLQueryItem]
        let storagePolicy: APIStoragePolicy = .store

        init(id: String, userID: String? = nil) {
            path = "/routes/\(id)"
            query = userID.map { [URLQueryItem(name: "userId", value: $0)] } ?? []
        }
    }

    struct Favorite: APIRequest {
        typealias Response = EmptyResponse

        let method: APIHTTPMethod
        let path: String
        let query: [URLQueryItem]

        init(id: String, userID: String, isFavorite: Bool) {
            method = isFavorite ? .post : .delete
            path = "/routes/\(id)/favorite"
            query = [URLQueryItem(name: "userId", value: userID)]
        }
    }
}
