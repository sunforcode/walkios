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

protocol PersonalTripServicing {
    func focus() async throws -> PersonalTripFocus
    func list() async throws -> PersonalTripCollection
    func calendar() async throws -> PersonalTripCalendar
    func detail(tripID: String) async throws -> PersonalTripDetail
    func days(tripID: String) async throws -> PersonalTripDays
    func weather(tripID: String) async throws -> PersonalTripWeather
    func routeVersionStatus(tripID: String) async throws -> PersonalTripRouteVersionStatus
    func cancel(
        tripID: String,
        expectedRevision: String,
        confirmed: Bool,
        idempotencyKey: String
    ) async throws -> PersonalTripDetail
    func migrate(
        tripID: String,
        expectedRevision: String,
        targetRouteVersionID: String,
        idempotencyKey: String
    ) async throws -> PersonalTripDetail
    func generationContext(routeID: String) async throws -> PersonalTripGenerationContext
    func create(
        _ input: PersonalTripCreateRequest,
        idempotencyKey: String
    ) async throws -> PersonalTripGenerationResult
}

struct PersonalTripService: PersonalTripServicing {
    let apiClient: any APIClient

    func focus() async throws -> PersonalTripFocus {
        try await apiClient.execute(PersonalTripAPI.Focus())
    }

    func list() async throws -> PersonalTripCollection {
        try await apiClient.execute(PersonalTripAPI.Collection())
    }

    func calendar() async throws -> PersonalTripCalendar {
        try await apiClient.execute(PersonalTripAPI.Calendar())
    }

    func detail(tripID: String) async throws -> PersonalTripDetail {
        try await apiClient.execute(PersonalTripAPI.Detail(tripID: tripID))
    }

    func days(tripID: String) async throws -> PersonalTripDays {
        try await apiClient.execute(PersonalTripAPI.Days(tripID: tripID))
    }

    func weather(tripID: String) async throws -> PersonalTripWeather {
        try await apiClient.execute(PersonalTripAPI.Weather(tripID: tripID))
    }

    func routeVersionStatus(tripID: String) async throws -> PersonalTripRouteVersionStatus {
        try await apiClient.execute(PersonalTripAPI.RouteVersionStatus(tripID: tripID))
    }

    func cancel(
        tripID: String,
        expectedRevision: String,
        confirmed: Bool,
        idempotencyKey: String
    ) async throws -> PersonalTripDetail {
        try await apiClient.execute(
            PersonalTripAPI.Cancel(
                tripID: tripID,
                input: PersonalTripCancelRequest(
                    expectedRevision: expectedRevision,
                    confirmed: confirmed
                ),
                idempotencyKey: idempotencyKey
            )
        )
    }

    func migrate(
        tripID: String,
        expectedRevision: String,
        targetRouteVersionID: String,
        idempotencyKey: String
    ) async throws -> PersonalTripDetail {
        try await apiClient.execute(
            PersonalTripAPI.Migrate(
                tripID: tripID,
                input: PersonalTripMigrateRequest(
                    expectedRevision: expectedRevision,
                    targetRouteVersionID: targetRouteVersionID
                ),
                idempotencyKey: idempotencyKey
            )
        )
    }

    func generationContext(routeID: String) async throws -> PersonalTripGenerationContext {
        try await apiClient.execute(PersonalTripAPI.GenerationContext(routeID: routeID))
    }

    func create(
        _ input: PersonalTripCreateRequest,
        idempotencyKey: String
    ) async throws -> PersonalTripGenerationResult {
        try await apiClient.execute(
            PersonalTripAPI.Create(input: input, idempotencyKey: idempotencyKey)
        )
    }
}
