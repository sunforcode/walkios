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

enum PersonalTripWeatherValidator {
    private static let confidenceStatuses = Set([
        "unknown",
        "missing",
        "pending_verification",
        "stale",
        "unavailable",
    ])

    static func isValid(
        _ weather: PersonalTripWeather,
        tripID: String,
        revision: String
    ) -> Bool {
        guard weather.tripID == tripID,
              weather.revision == revision,
              !weather.days.isEmpty else {
            return false
        }

        var dayIDs = Set<String>()
        var forecastsByID: [String: WeatherForecast] = [:]
        for (index, day) in weather.days.enumerated() {
            guard day.dayNumber == index + 1,
                  isNonEmpty(day.tripDayID),
                  dayIDs.insert(day.tripDayID).inserted,
                  !day.weatherAssociations.isEmpty,
                  isValidAssociations(
                      day.weatherAssociations,
                      date: day.date,
                      forecastsByID: &forecastsByID
                  ) else {
                return false
            }
        }
        return true
    }

    private static func isValidAssociations(
        _ associations: [TripWeatherAssociation],
        date: LocalDate,
        forecastsByID: inout [String: WeatherForecast]
    ) -> Bool {
        var identities = Set<String>()
        var previousSequence = 0

        for association in associations {
            guard association.sequence > previousSequence,
                  isNonEmpty(association.associationIdentity),
                  identities.insert(association.associationIdentity).inserted,
                  isValidLocation(association.targetLocation),
                  let targetStart = instantDate(association.targetPeriodStart),
                  let targetEnd = instantDate(association.targetPeriodEnd),
                  targetStart < targetEnd,
                  isInsideBusinessDate(start: targetStart, end: targetEnd, date: date),
                  isValidScope(association),
                  isValidForecastCombination(association),
                  isValidConfidence(association.forecastConfidence, allowsMetadata: false) else {
                return false
            }
            previousSequence = association.sequence

            guard let forecast = association.forecast else { continue }
            guard isValidForecast(
                forecast,
                targetLocation: association.targetLocation,
                targetStart: targetStart,
                targetEnd: targetEnd
            ) else {
                return false
            }
            if let existing = forecastsByID[forecast.identity], existing != forecast {
                return false
            }
            forecastsByID[forecast.identity] = forecast
        }
        return true
    }

    private static func isValidScope(_ association: TripWeatherAssociation) -> Bool {
        switch association.scope {
        case .day:
            return association.hikeActionIdentity == nil
        case .hikeAction:
            return isNonEmpty(association.hikeActionIdentity)
        }
    }

    private static func isValidForecastCombination(_ association: TripWeatherAssociation) -> Bool {
        guard let confidence = association.forecastConfidence else {
            return association.forecast != nil
        }
        switch confidence.status {
        case "pending_verification", "stale":
            return association.forecast != nil
        case "unavailable":
            return association.forecast == nil
        case "unknown", "missing":
            return true
        default:
            return false
        }
    }

    private static func isValidForecast(
        _ forecast: WeatherForecast,
        targetLocation: WeatherLocation,
        targetStart: Date,
        targetEnd: Date
    ) -> Bool {
        guard isNonEmpty(forecast.identity),
              isValidLocation(forecast.location),
              forecast.location.position == targetLocation.position,
              forecast.source.map(isNonEmpty) ?? true,
              forecast.publishedAt.map({ instantDate($0) != nil }) ?? true,
              !forecast.periods.isEmpty else {
            return false
        }

        var previousEnd: Date?
        var overlapsTarget = false
        for period in forecast.periods {
            guard let periodStart = instantDate(period.periodStart),
                  let periodEnd = instantDate(period.periodEnd),
                  periodStart < periodEnd,
                  previousEnd.map({ $0 <= periodStart }) ?? true,
                  isValidPeriod(period) else {
                return false
            }
            overlapsTarget = overlapsTarget || (periodStart < targetEnd && periodEnd > targetStart)
            previousEnd = periodEnd
        }
        return overlapsTarget
    }

    private static func isValidPeriod(_ period: WeatherForecastPeriod) -> Bool {
        let values: [Bool?] = [
            period.condition.map {
                isValidQualified($0) { isNonEmpty($0.description) }
            },
            period.temperatureRange.map {
                isValidQualified($0) { range in
                    guard range.low != nil || range.high != nil,
                          range.low.map(\.isFinite) ?? true,
                          range.high.map(\.isFinite) ?? true else {
                        return false
                    }
                    return (range.low.flatMap { low in range.high.map { low <= $0 } }) ?? true
                }
            },
            period.precipitation.map {
                isValidQualified($0) { precipitation in
                    let hasValue = precipitation.description != nil
                        || precipitation.probability != nil
                        || precipitation.amount != nil
                    return hasValue
                        && (precipitation.description.map(isNonEmpty) ?? true)
                        && (precipitation.probability.map { $0.isFinite && (0...1).contains($0) } ?? true)
                        && (precipitation.amount.map { $0.millimeters.isFinite && $0.millimeters >= 0 } ?? true)
                }
            },
            period.wind.map {
                isValidQualified($0) { wind in
                    let hasValue = wind.description != nil
                        || wind.averageSpeed != nil
                        || wind.gustSpeed != nil
                        || wind.direction != nil
                    guard hasValue,
                          wind.description.map(isNonEmpty) ?? true,
                          wind.direction.map(isNonEmpty) ?? true,
                          wind.averageSpeed.map({ $0.metersPerSecond.isFinite && $0.metersPerSecond >= 0 }) ?? true,
                          wind.gustSpeed.map({ $0.metersPerSecond.isFinite && $0.metersPerSecond >= 0 }) ?? true else {
                        return false
                    }
                    return (wind.averageSpeed.flatMap { average in
                        wind.gustSpeed.map { $0.metersPerSecond >= average.metersPerSecond }
                    }) ?? true
                }
            },
        ]
        return values.contains(true) && !values.contains(false)
    }

    private static func isValidQualified<Value>(
        _ qualified: WeatherQualifiedValue<Value>,
        valueIsValid: (Value) -> Bool
    ) -> Bool where Value: Codable & Equatable {
        guard qualified.value != nil || qualified.confidence != nil,
              isValidConfidence(qualified.confidence, allowsMetadata: false) else {
            return false
        }
        if let value = qualified.value, !valueIsValid(value) { return false }
        switch qualified.confidence?.status {
        case "pending_verification", "stale":
            return qualified.value != nil
        case "unavailable":
            return qualified.value == nil
        default:
            return true
        }
    }

    private static func isValidConfidence(
        _ confidence: InformationConfidence?,
        allowsMetadata: Bool
    ) -> Bool {
        guard let confidence else { return true }
        return confidenceStatuses.contains(confidence.status)
            && confidence.category == .dynamicExternalInformation
            && (allowsMetadata || (confidence.source == nil && confidence.updatedAt == nil))
    }

    private static func isValidLocation(_ location: WeatherLocation) -> Bool {
        location.position.latitude.isFinite
            && (-90...90).contains(location.position.latitude)
            && location.position.longitude.isFinite
            && (-180...180).contains(location.position.longitude)
            && isNonEmpty(location.position.referenceSystem)
            && (location.name.map(isNonEmpty) ?? true)
    }

    private static func isInsideBusinessDate(start: Date, end: Date, date: LocalDate) -> Bool {
        guard let dayStart = date.dateAtStartOfDay,
              let dayEnd = Calendar.business.date(byAdding: .day, value: 1, to: dayStart) else {
            return false
        }
        return start >= dayStart && end <= dayEnd
    }

    private static func isNonEmpty(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func instantDate(_ instant: Instant) -> Date? {
        ISO8601DateFormatter().date(from: instant.rawValue)
    }
}
