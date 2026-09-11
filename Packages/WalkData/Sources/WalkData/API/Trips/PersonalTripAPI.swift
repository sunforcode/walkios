import Foundation

private enum TripRequestEncoder {
     public static func encode<Value: Encodable>(_ value: Value) -> Data? {
        try? JSONEncoder().encode(value)
    }
}

public enum PersonalTripAPI {
    public struct Focus: APIRequest {
        public typealias Response = PersonalTripFocus
        public let method: APIHTTPMethod = .get
        public let path = "/trips/focus"
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store


        public init() {}    }

    public struct Collection: APIRequest {
        public typealias Response = PersonalTripCollection
        public let method: APIHTTPMethod = .get
        public let path = "/trips"
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store


        public init() {}    }

    public struct Calendar: APIRequest {
        public typealias Response = PersonalTripCalendar
        public let method: APIHTTPMethod = .get
        public let path = "/trips/calendar"
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store


        public init() {}    }

    public struct Detail: APIRequest {
        public typealias Response = PersonalTripDetail
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init(tripID: String) { path = "/trips/\(tripID)" }
    }

    public struct Days: APIRequest {
        public typealias Response = PersonalTripDays
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init(tripID: String) { path = "/trips/\(tripID)/days" }
    }

    public struct Weather: APIRequest {
        public typealias Response = PersonalTripWeather
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init(tripID: String) { path = "/trips/\(tripID)/weather" }
    }

    public struct RouteVersionStatus: APIRequest {
        public typealias Response = PersonalTripRouteVersionStatus
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(tripID: String) { path = "/trips/\(tripID)/route-version-status" }
    }

    public struct Cancel: APIRequest {
        public typealias Response = PersonalTripDetail
        public let method: APIHTTPMethod = .post
        public let path: String
        public let body: Data?
        public let headers: [String: String]
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(
            tripID: String,
            input: PersonalTripCancelRequest,
            idempotencyKey: String
        ) throws {
            path = "/trips/\(tripID)/cancellations"
            body = try JSONEncoder().encode(input)
            headers = ["Idempotency-Key": idempotencyKey]
        }
    }

    public struct Migrate: APIRequest {
        public typealias Response = PersonalTripDetail
        public let method: APIHTTPMethod = .post
        public let path: String
        public let body: Data?
        public let headers: [String: String]
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(
            tripID: String,
            input: PersonalTripMigrateRequest,
            idempotencyKey: String
        ) throws {
            path = "/trips/\(tripID)/route-migrations"
            body = try JSONEncoder().encode(input)
            headers = ["Idempotency-Key": idempotencyKey]
        }
    }

    public struct GenerationContext: APIRequest {
        public typealias Response = PersonalTripGenerationContext
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(routeID: String) {
            path = "/public-routes/\(routeID)/trip-generation-context"
        }
    }

    public struct Create: APIRequest {
        public typealias Response = PersonalTripGenerationResult
        public let method: APIHTTPMethod = .post
        public let path = "/trips"
        public let body: Data?
        public let headers: [String: String]
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(input: PersonalTripCreateRequest, idempotencyKey: String) throws {
            body = try JSONEncoder().encode(input)
            headers = ["Idempotency-Key": idempotencyKey]
        }
    }
}
