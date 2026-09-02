import SwiftUI
import CoreLocation

enum TripDetailBlock: Equatable {
    case identity
    case days
    case route
    case weather
    case equipment
    case routeVersion
    case notices
}

struct TripDetailPresentation: Equatable {
    let detail: PersonalTripDetail
    let days: PersonalTripDays
    let weather: PersonalTripWeather
    let routeVersionStatus: PersonalTripRouteVersionStatus

    var notices: [PersonalTripImportantNotice] {
        (detail.trip.importantNotices ?? [])
            .filter { $0.content.value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .sorted { $0.sequence < $1.sequence }
    }

    var blocks: [TripDetailBlock] {
        var result: [TripDetailBlock] = [.identity, .days, .route, .weather, .equipment, .routeVersion]
        if !notices.isEmpty { result.append(.notices) }
        return result
    }

    var showsPageLevelCancel: Bool { detail.trip.status == .planned }
}

struct TripDetailActionPolicy: Equatable {
    let canCancel: Bool
    let canMigrate: Bool
    let isReadOnly: Bool

    init(status: PersonalTripStatus, migrationEligible: Bool) {
        canCancel = status == .planned
        canMigrate = status == .planned && migrationEligible
        isReadOnly = status != .planned
    }

    init(canCancel: Bool, canMigrate: Bool, isReadOnly: Bool) {
        self.canCancel = canCancel
        self.canMigrate = canMigrate
        self.isReadOnly = isReadOnly
    }
}

@MainActor
final class TripDetailViewModel: ObservableObject {
    @Published private(set) var trip: PersonalTripDetail?
    @Published private(set) var days: PersonalTripDays?
    @Published private(set) var weather: PersonalTripWeather?
    @Published private(set) var routeVersionStatus: PersonalTripRouteVersionStatus?
    @Published var isLoading = false
    @Published private(set) var isMutating = false
    @Published var errorMessage: String?
    @Published private(set) var mapCoordinates: [CLLocationCoordinate2D] = []

    private let loadDetail: (String) async throws -> PersonalTripDetail
    private let loadDays: (String) async throws -> PersonalTripDays
    private let loadWeather: (String) async throws -> PersonalTripWeather
    private let loadRouteVersionStatus: (String) async throws -> PersonalTripRouteVersionStatus
    private let cancel: (String, String, Bool, String) async throws -> PersonalTripDetail
    private let migrate: (String, String, String, String) async throws -> PersonalTripDetail
    private let idempotencyKey: () -> String
    private var pendingCancelIntent: MutationIntent?
    private var pendingMigrationIntent: MutationIntent?

    private struct MutationIntent: Equatable {
        let signature: String
        let idempotencyKey: String
    }

    init(service: any PersonalTripServicing) {
        self.loadDetail = { try await service.detail(tripID: $0) }
        self.loadDays = { try await service.days(tripID: $0) }
        self.loadWeather = { try await service.weather(tripID: $0) }
        self.loadRouteVersionStatus = { try await service.routeVersionStatus(tripID: $0) }
        self.cancel = {
            try await service.cancel(
                tripID: $0,
                expectedRevision: $1,
                confirmed: $2,
                idempotencyKey: $3
            )
        }
        self.migrate = {
            try await service.migrate(
                tripID: $0,
                expectedRevision: $1,
                targetRouteVersionID: $2,
                idempotencyKey: $3
            )
        }
        self.idempotencyKey = { UUID().uuidString }
    }

    init(
        loadDetail: @escaping (String) async throws -> PersonalTripDetail,
        loadDays: @escaping (String) async throws -> PersonalTripDays,
        loadWeather: @escaping (String) async throws -> PersonalTripWeather,
        loadRouteVersionStatus: ((String) async throws -> PersonalTripRouteVersionStatus)? = nil,
        cancelTrip: @escaping (String, String, Bool, String) async throws -> PersonalTripDetail = { tripID, _, _, _ in
            throw APIClientError.mockNotFound("POST /trips/\(tripID)/cancellations")
        },
        migrateTrip: @escaping (String, String, String, String) async throws -> PersonalTripDetail = { tripID, _, _, _ in
            throw APIClientError.mockNotFound("POST /trips/\(tripID)/route-migrations")
        },
        idempotencyKey: @escaping () -> String = { UUID().uuidString }
    ) {
        self.loadDetail = loadDetail
        self.loadDays = loadDays
        self.loadWeather = loadWeather
        self.loadRouteVersionStatus = loadRouteVersionStatus ?? {
            try await loadDetail($0).routeVersionStatus
        }
        self.cancel = cancelTrip
        self.migrate = migrateTrip
        self.idempotencyKey = idempotencyKey
    }

    var isFrozenTrackUnavailable: Bool {
        trip != nil && mapCoordinates.isEmpty
    }

    var actionPolicy: TripDetailActionPolicy? {
        guard let trip else { return nil }
        return TripDetailActionPolicy(
            status: trip.trip.status,
            migrationEligible: routeVersionStatus?.migrationEligible == true
        )
    }

    func loadTrip(id: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let loadedDetail = loadDetail(id)
            async let loadedDays = loadDays(id)
            async let loadedWeather = loadWeather(id)
            let (detail, days, weather) = try await (
                loadedDetail,
                loadedDays,
                loadedWeather
            )
            try requireMatchingRevision(detail: detail, days: days, weather: weather)
            replaceProjection(detail: detail, days: days, weather: weather)
        } catch {
            errorMessage = message(for: error, operation: "加载")
        }
    }

    func refreshRouteVersionStatus(id: String) async {
        do {
            let status = try await loadRouteVersionStatus(id)
            guard let trip, status.tripRevision == trip.revision else {
                throw APIClientError.invalidResponse
            }
            routeVersionStatus = status
            errorMessage = nil
        } catch {
            errorMessage = message(for: error, operation: "刷新版本状态")
        }
    }

    func cancelTrip(id: String) async {
        guard let trip, actionPolicy?.canCancel == true else { return }
        let signature = "\(id)|\(trip.revision)|true"
        let intent = intent(for: signature, current: pendingCancelIntent)
        pendingCancelIntent = intent
        await mutate(operation: "取消行程") {
            do {
                let detail = try await cancel(id, trip.revision, true, intent.idempotencyKey)
                pendingCancelIntent = nil
                return detail
            } catch {
                if !Self.hasUnknownResult(error) { pendingCancelIntent = nil }
                throw error
            }
        }
    }

    func migrateTrip(id: String) async {
        guard let trip else { return }
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }

        do {
            let latestStatus = try await loadRouteVersionStatus(id)
            guard latestStatus.tripRevision == trip.revision,
                  latestStatus.versionRelationship == .newerPublicVersionAvailable,
                  latestStatus.migrationEligible,
                  let target = latestStatus.currentPublicVersion?.routeVersionID else {
                throw APIClientError.invalidResponse
            }
            let signature = "\(id)|\(trip.revision)|\(target)"
            let intent = intent(for: signature, current: pendingMigrationIntent)
            pendingMigrationIntent = intent
            do {
                let migrated = try await migrate(id, trip.revision, target, intent.idempotencyKey)
                pendingMigrationIntent = nil
                replaceWithMutationProjection(migrated)
            } catch {
                if !Self.hasUnknownResult(error) { pendingMigrationIntent = nil }
                throw error
            }
        } catch {
            errorMessage = message(for: error, operation: "迁移行程")
        }
    }

    private func mutate(
        operation: String,
        action: () async throws -> PersonalTripDetail
    ) async {
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }
        do {
            replaceWithMutationProjection(try await action())
        } catch {
            errorMessage = message(for: error, operation: operation)
        }
    }

    private func intent(for signature: String, current: MutationIntent?) -> MutationIntent {
        if let current, current.signature == signature { return current }
        return MutationIntent(signature: signature, idempotencyKey: idempotencyKey())
    }

    private static func hasUnknownResult(_ error: Error) -> Bool {
        switch error {
        case APIClientError.transport:
            return true
        case APIClientError.http(let statusCode):
            return statusCode >= 500
        case APIClientError.api(_, _, let retryable, _):
            return retryable
        default:
            return false
        }
    }

    private func requireMatchingRevision(
        detail: PersonalTripDetail,
        days: PersonalTripDays,
        weather: PersonalTripWeather
    ) throws {
        guard detail.revision == days.revision,
              detail.revision == weather.revision,
              detail.routeVersionStatus.tripRevision == detail.revision,
              days.tripID == detail.trip.identity,
              weather.tripID == detail.trip.identity else {
            throw APIClientError.invalidResponse
        }
    }

    private func replaceProjection(
        detail: PersonalTripDetail,
        days: PersonalTripDays,
        weather: PersonalTripWeather
    ) {
        trip = detail
        self.days = days
        self.weather = weather
        routeVersionStatus = detail.routeVersionStatus
        mapCoordinates = detail.trip.frozenRouteBasis.mainTrackPath.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private func replaceWithMutationProjection(_ detail: PersonalTripDetail) {
        trip = detail
        days = PersonalTripDays(
            tripID: detail.trip.identity,
            revision: detail.revision,
            startDate: detail.trip.startDate,
            endDate: detail.trip.endDate,
            totalDayCount: detail.trip.totalDayCount,
            hikingDayCount: detail.trip.hikingDayCount,
            days: detail.days
        )
        weather = PersonalTripWeather(
            tripID: detail.trip.identity,
            revision: detail.revision,
            routeName: detail.trip.frozenRouteBasis.routeName,
            startDate: detail.trip.startDate,
            endDate: detail.trip.endDate,
            days: detail.days.map {
                PersonalTripWeatherDay(
                    tripDayID: $0.identity,
                    dayNumber: $0.dayNumber,
                    date: $0.date,
                    primaryStage: $0.primaryStage,
                    hikingDayNumber: $0.hikingDayNumber,
                    weather: $0.weather
                )
            },
            weatherOverview: detail.trip.weatherOverview
        )
        routeVersionStatus = detail.routeVersionStatus
        mapCoordinates = detail.trip.frozenRouteBasis.mainTrackPath.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private func message(for error: Error, operation: String) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "\(operation)失败：\(error.localizedDescription)"
    }
}
