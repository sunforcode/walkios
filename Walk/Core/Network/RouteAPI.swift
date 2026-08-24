import Foundation

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
