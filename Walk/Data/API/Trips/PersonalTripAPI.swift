import Foundation

private enum TripRequestEncoder {
    static func encode<Value: Encodable>(_ value: Value) -> Data? {
        try? JSONEncoder().encode(value)
    }
}

enum PersonalTripAPI {
    struct Focus: APIRequest {
        typealias Response = PersonalTripFocus
        let method: APIHTTPMethod = .get
        let path = "/trips/focus"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
    }

    struct Collection: APIRequest {
        typealias Response = PersonalTripCollection
        let method: APIHTTPMethod = .get
        let path = "/trips"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
    }

    struct Calendar: APIRequest {
        typealias Response = PersonalTripCalendar
        let method: APIHTTPMethod = .get
        let path = "/trips/calendar"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
    }

    struct Detail: APIRequest {
        typealias Response = PersonalTripDetail
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store

        init(tripID: String) { path = "/trips/\(tripID)" }
    }

    struct Days: APIRequest {
        typealias Response = PersonalTripDays
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store

        init(tripID: String) { path = "/trips/\(tripID)/days" }
    }

    struct Weather: APIRequest {
        typealias Response = PersonalTripWeather
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store

        init(tripID: String) { path = "/trips/\(tripID)/weather" }
    }

    struct RouteVersionStatus: APIRequest {
        typealias Response = PersonalTripRouteVersionStatus
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data

        init(tripID: String) { path = "/trips/\(tripID)/route-version-status" }
    }

    struct Cancel: APIRequest {
        typealias Response = PersonalTripDetail
        let method: APIHTTPMethod = .post
        let path: String
        let body: Data?
        let headers: [String: String]
        let responseEnvelope: APIResponseEnvelope = .data

        init(
            tripID: String,
            input: PersonalTripCancelRequest,
            idempotencyKey: String
        ) throws {
            path = "/trips/\(tripID)/cancellations"
            body = try JSONEncoder().encode(input)
            headers = ["Idempotency-Key": idempotencyKey]
        }
    }

    struct Migrate: APIRequest {
        typealias Response = PersonalTripDetail
        let method: APIHTTPMethod = .post
        let path: String
        let body: Data?
        let headers: [String: String]
        let responseEnvelope: APIResponseEnvelope = .data

        init(
            tripID: String,
            input: PersonalTripMigrateRequest,
            idempotencyKey: String
        ) throws {
            path = "/trips/\(tripID)/route-migrations"
            body = try JSONEncoder().encode(input)
            headers = ["Idempotency-Key": idempotencyKey]
        }
    }

    struct GenerationContext: APIRequest {
        typealias Response = PersonalTripGenerationContext
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data

        init(routeID: String) {
            path = "/public-routes/\(routeID)/trip-generation-context"
        }
    }

    struct Create: APIRequest {
        typealias Response = PersonalTripGenerationResult
        let method: APIHTTPMethod = .post
        let path = "/trips"
        let body: Data?
        let headers: [String: String]
        let responseEnvelope: APIResponseEnvelope = .data

        init(input: PersonalTripCreateRequest, idempotencyKey: String) throws {
            body = try JSONEncoder().encode(input)
            headers = ["Idempotency-Key": idempotencyKey]
        }
    }
}
