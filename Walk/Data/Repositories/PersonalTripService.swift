import Foundation

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
