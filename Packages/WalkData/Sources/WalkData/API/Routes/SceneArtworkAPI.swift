import Foundation

public extension PublicRouteAPI {
    struct Scenes: APIRequest {
        public typealias Response = PublicRouteScenes
        public let method: APIHTTPMethod = .get
        public let path: String
        public let pathIsPercentEncoded = true
        public let query: [URLQueryItem]
        public let responseEnvelope: APIResponseEnvelope = .data
        public let authenticationPolicy: APIAuthenticationPolicy = .none

        public init(routeID: String, routeVersionID: String) {
            path = "/public-routes/\(APIPathSegment.encode(routeID))/scenes"
            query = [URLQueryItem(name: "routeVersionId", value: routeVersionID)]
        }
    }
}

public extension PersonalTripAPI {
    struct Scenes: APIRequest {
        public typealias Response = PersonalTripScenes
        public let method: APIHTTPMethod = .get
        public let path: String
        public let pathIsPercentEncoded = true
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(tripID: String) {
            path = "/trips/\(APIPathSegment.encode(tripID))/scenes"
        }
    }
}
