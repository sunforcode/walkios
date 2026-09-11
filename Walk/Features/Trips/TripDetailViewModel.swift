import SwiftUI

enum TripDetailBlock: Equatable, CaseIterable {
    case identity
    case days
    case route
    case weather
    case equipment
    case notices
}

struct TripDetailPresentation: Equatable {
    let detail: PersonalTripDetail
    let days: PersonalTripDays
    let weather: LegacyPersonalTripWeather?
    let routeVersionStatus: PersonalTripRouteVersionStatus

    var coverProjection: TripCoverHeaderProjection {
        TripCoverHeaderProjection(
            name: detail.trip.name,
            status: detail.trip.status,
            departureCity: detail.trip.departureCity,
            startDate: detail.trip.startDate.description,
            endDate: detail.trip.endDate.description,
            totalDayCount: detail.trip.totalDayCount,
            hikingDayCount: detail.trip.hikingDayCount,
            versionLabel: detail.trip.frozenRouteBasis.versionLabel,
            coverAvailable: false
        )
    }

    var dayProjections: [TripDayProjection] {
        days.days.map(Self.dayProjection)
    }

    var weatherSummaryProjection: TripWeatherSummaryProjection? {
        weather.map {
            TripWeatherSummaryProjection(
                days: $0.days.map { TripWeatherDayComponentPresentation(day: $0).projection },
                notice: nil
            )
        }
    }

    var equipmentSummaryProjection: TripEquipmentSummaryProjection {
        let summary = detail.equipmentSnapshot.summary
        return TripEquipmentSummaryProjection(
            knownTotalWeight: Self.weightText(summary.knownTotalWeight.grams),
            itemCount: summary.itemCount,
            ownedItemCount: summary.ownedItemCount,
            unconfirmedOwnedItemCount: summary.unconfirmedOwnedItemCount,
            missingWeightItemCount: summary.missingWeightItemCount,
            editable: detail.trip.status == .planned
        )
    }

    var notices: [PersonalTripImportantNotice] {
        (detail.trip.importantNotices ?? [])
            .filter { $0.content.value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .sorted { $0.sequence < $1.sequence }
    }

    var blocks: [TripDetailBlock] {
        var result: [TripDetailBlock] = [.identity, .days, .route]
        if weather != nil { result.append(.weather) }
        result.append(.equipment)
        if !notices.isEmpty { result.append(.notices) }
        return result
    }

    var showsPageLevelCancel: Bool { detail.trip.status == .planned }

    private static func dayProjection(_ day: PersonalTripDay) -> TripDayProjection {
        let presentation = TripDayPresentation(day: day)
        return TripDayProjection(
            tripDayID: day.identity,
            dayNumber: day.dayNumber,
            date: day.date.description,
            primaryStage: day.primaryStage,
            hikingDayNumber: day.hikingDayNumber,
            actions: presentation.presentationItems.map { item in
                TripTimelineItemProjection(
                    id: String(item.sequence),
                    time: item.action.keyTimes?.value?.first,
                    title: actionTitle(item.action),
                    details: item.details,
                    notices: item.statusNotices.map(\.message)
                )
            },
            points: presentation.pointItems.map { item in
                TripPointProjection(
                    id: String(item.sequence),
                    title: item.point.name ?? item.point.type,
                    details: pointDetails(item),
                    trailing: item.point.type
                )
            },
            weather: TripWeatherDayComponentPresentation(
                day: PersonalTripWeatherDay(
                    tripDayID: day.identity,
                    dayNumber: day.dayNumber,
                    date: day.date,
                    primaryStage: day.primaryStage,
                    hikingDayNumber: day.hikingDayNumber,
                    weather: day.weather
                )
            ).projection.weather,
            dailyRouteSummary: nil
        )
    }

    private static func actionTitle(_ action: PersonalTripAction) -> String {
        switch action.actionType {
        case "long_distance_transport": "大交通"
        case "route_transfer": "路线接驳"
        case "hike": action.routeSectionSnapshot?.name ?? "徒步"
        default: action.actionType
        }
    }

    private static func pointDetails(_ item: TripPointPresentation) -> [String] {
        var details: [String] = []
        if let meters = item.point.distance?.value?.meters {
            details.append("距离 \(distanceText(meters))")
        }
        if let detail = nonEmpty(item.point.details?.value) {
            details.append(detail)
        }
        details.append(contentsOf: item.statusNotices.map(\.message))
        return details
    }

    private static func distanceText(_ meters: Double) -> String {
        meters >= 1_000
            ? "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
            : "\(Int(meters.rounded())) m"
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func weightText(_ grams: Int) -> String {
        grams >= 1_000
            ? "\((Double(grams) / 1_000).formatted(.number.precision(.fractionLength(0...2)))) kg"
            : "\(grams) g"
    }
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
    @Published private(set) var isWeatherUnavailable = false
    @Published private(set) var routeVersionStatus: PersonalTripRouteVersionStatus?
    @Published var isLoading = false
    @Published private(set) var isMutating = false
    @Published var errorMessage: String?
    @Published private(set) var migrationErrorMessage: String?

    private let loadDetail: (String) async throws -> PersonalTripDetail
    private let loadDays: (String) async throws -> PersonalTripDays
    private let loadWeather: (String) async throws -> PersonalTripWeather
    private let loadRouteVersionStatus: (String) async throws -> PersonalTripRouteVersionStatus
    private let cancel: (String, String, Bool, String) async throws -> PersonalTripDetail
    private let migrate: (String, String, String, String) async throws -> PersonalTripDetail
    private let idempotencyKey: () -> String
    private let initialMigrationErrorMessage: String?
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
        self.initialMigrationErrorMessage = nil
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
        idempotencyKey: @escaping () -> String = { UUID().uuidString },
        initialMigrationErrorMessage: String? = nil
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
        self.initialMigrationErrorMessage = initialMigrationErrorMessage
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
        migrationErrorMessage = nil
        isWeatherUnavailable = false
        defer { isLoading = false }

        do {
            async let loadedDetail = loadDetail(id)
            async let loadedDays = loadDays(id)
            let (detail, days) = try await (loadedDetail, loadedDays)
            try requireMatchingRevision(detail: detail, days: days)

            do {
                let weather = try await loadWeather(id)
                guard PersonalTripWeatherValidator.isValid(
                    weather,
                    tripID: detail.trip.identity,
                    revision: detail.revision
                ) else {
                    throw APIClientError.invalidResponse
                }
                replaceProjection(detail: detail, days: days, weather: weather)
            } catch let error where Self.isWeatherProjectionUnavailable(error) {
                replaceProjection(detail: detail, days: days, weather: nil)
                isWeatherUnavailable = true
            }
            migrationErrorMessage = initialMigrationErrorMessage
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
        migrationErrorMessage = nil
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
            let message = message(for: error, operation: "迁移行程")
            migrationErrorMessage = message
            errorMessage = message
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
        days: PersonalTripDays
    ) throws {
        guard detail.revision == days.revision,
              detail.routeVersionStatus.tripRevision == detail.revision,
              days.tripID == detail.trip.identity else {
            throw APIClientError.invalidResponse
        }
    }

    private func replaceProjection(
        detail: PersonalTripDetail,
        days: PersonalTripDays,
        weather: PersonalTripWeather?
    ) {
        trip = detail
        self.days = days
        self.weather = weather
        routeVersionStatus = detail.routeVersionStatus
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
        weather = nil
        isWeatherUnavailable = true
        routeVersionStatus = detail.routeVersionStatus
    }

    private static func isWeatherProjectionUnavailable(_ error: Error) -> Bool {
        guard case APIClientError.api(let code, _, _, _) = error else { return false }
        return code == "trip_weather_projection_unavailable"
    }

    private func message(for error: Error, operation: String) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "\(operation)失败：\(error.localizedDescription)"
    }
}
