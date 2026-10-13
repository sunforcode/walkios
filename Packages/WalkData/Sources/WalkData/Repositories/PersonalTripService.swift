import Foundation

public protocol PersonalTripServicing {
    func focus() async throws -> PersonalTripFocus
    func list() async throws -> PersonalTripCollection
    func calendar() async throws -> PersonalTripCalendar
    func detail(tripID: String) async throws -> PersonalTripDetail
    func days(tripID: String) async throws -> PersonalTripDays
    func weather(tripID: String) async throws -> PersonalTripWeather
    func scenes(tripID: String) async throws -> PersonalTripScenes
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

public extension PersonalTripServicing {
    func scenes(tripID: String) async throws -> PersonalTripScenes {
        throw APIClientError.http(statusCode: 404)
    }
}

public struct PersonalTripService: PersonalTripServicing {
     public let apiClient: any APIClient

     public func focus() async throws -> PersonalTripFocus {
        try await apiClient.execute(PersonalTripAPI.Focus())
    }

     public func list() async throws -> PersonalTripCollection {
        try await apiClient.execute(PersonalTripAPI.Collection())
    }

     public func calendar() async throws -> PersonalTripCalendar {
        try await apiClient.execute(PersonalTripAPI.Calendar())
    }

     public func detail(tripID: String) async throws -> PersonalTripDetail {
        try await apiClient.execute(PersonalTripAPI.Detail(tripID: tripID))
    }

     public func days(tripID: String) async throws -> PersonalTripDays {
        try await apiClient.execute(PersonalTripAPI.Days(tripID: tripID))
    }

     public func weather(tripID: String) async throws -> PersonalTripWeather {
        try await apiClient.execute(PersonalTripAPI.Weather(tripID: tripID))
    }

    public func scenes(tripID: String) async throws -> PersonalTripScenes {
        try await apiClient.execute(PersonalTripAPI.Scenes(tripID: tripID))
    }

     public func routeVersionStatus(tripID: String) async throws -> PersonalTripRouteVersionStatus {
        try await apiClient.execute(PersonalTripAPI.RouteVersionStatus(tripID: tripID))
    }

     public func cancel(
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

     public func migrate(
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

     public func generationContext(routeID: String) async throws -> PersonalTripGenerationContext {
        try await apiClient.execute(PersonalTripAPI.GenerationContext(routeID: routeID))
    }

     public func create(
        _ input: PersonalTripCreateRequest,
        idempotencyKey: String
    ) async throws -> PersonalTripGenerationResult {
        try await apiClient.execute(
            PersonalTripAPI.Create(input: input, idempotencyKey: idempotencyKey)
        )
    }

    public init(
        apiClient: any APIClient
    ) {
        self.apiClient = apiClient
    }
}
