import SwiftUI
import WalkData
import WalkDesignSystem

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
            coverAvailable: false
        )
    }

    var dayProjections: [TripDayProjection] {
        days.days.map { Self.dayProjection($0, totalTrekDays: days.hikingDayCount) }
    }

    /// 概览日入口投影：仅冻结事实（日序、日期、徒步日序、当日行程起讫）。
    var dayOverviewEntries: [TripDayOverviewEntryProjection] {
        days.days
            .sorted { $0.dayNumber < $1.dayNumber }
            .map { day in
                TripDayOverviewEntryProjection(
                    tripDayID: day.identity,
                    dayNumber: day.dayNumber,
                    date: Self.overviewDateText(day.date),
                    hikingDayNumber: day.hikingDayNumber,
                    totalTrekDays: days.hikingDayCount,
                    subtitle: Self.overviewSubtitle(day)
                )
            }
    }

    /// 副标题只来自冻结行动事实：徒步日取起讫点名，交通日取接驳起讫链；缺失为 nil。
    private static func overviewSubtitle(_ day: PersonalTripDay) -> String? {
        if let hike = day.actions.first(where: { $0.actionType == "hike" }) {
            let names = [hike.start?.value?.name, hike.end?.value?.name].compactMap { $0 }
            return names.isEmpty ? nil : names.joined(separator: " → ")
        }
        let chain = day.actions
            .filter { ["long_distance_transport", "route_transfer"].contains($0.actionType) }
            .compactMap { action -> [String]? in
                let origin = action.origin?.value?.name
                let destination = action.destination?.value?.name
                guard origin != nil || destination != nil else { return nil }
                return [origin, destination].compactMap { $0 }
            }
            .map { $0.joined(separator: " → ") }
            .joined(separator: " → ")
        return tripNonEmpty(chain)
    }

    private static func overviewDateText(_ date: LocalDate) -> String {
        "\(date.month)月\(date.day)日"
    }

    var weatherSummaryProjection: TripWeatherSummaryProjection? {
        let samples = days.days.compactMap(Self.trendSample)
        guard !samples.isEmpty else { return nil }
        return TripWeatherSummaryProjection(samples: samples, notice: nil)
    }

    /// 行程详情页每日独立天气卡投影：从冻结自然日天气直接派生，地点取冻结 placeContext。
    var weatherDayProjections: [TripWeatherDayProjection] {
        days.days.map { day in
            TripWeatherDayProjection(
                id: day.identity,
                dayNumber: day.dayNumber,
                date: Self.overviewDateText(day.date),
                primaryStage: day.primaryStage,
                hikingDayNumber: day.hikingDayNumber,
                placeContext: Self.nonEmptyText(day.weather.placeContext.value),
                weather: TripWeatherProjection(
                    condition: Self.weatherValue(TripWeatherFieldPresentation(qualified: day.weather.condition)),
                    temperature: Self.weatherValue(TripWeatherFieldPresentation(temperatureRange: day.weather.temperatureRange)),
                    precipitation: Self.weatherValue(TripWeatherFieldPresentation(qualified: day.weather.precipitation)),
                    wind: Self.weatherValue(TripWeatherFieldPresentation(qualified: day.weather.wind))
                )
            )
        }
    }

    private static func nonEmptyText(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    private static func weatherValue(_ field: TripWeatherFieldPresentation) -> TripWeatherValueProjection {
        TripWeatherValueProjection(
            value: field.text,
            state: TripWeatherDayComponentPresentation.informationState(field.status)
        )
    }

    /// 天气摘要从冻结自然日派生（方案 A）：不依赖独立天气关联接口，
    /// 天气结果可用时入口必须呈现（app-flow 场景）。
    private static func trendSample(_ day: PersonalTripDay) -> TripWeatherTrendSampleProjection? {
        let range = day.weather.temperatureRange.value
        let low = range?.low
        let high = range?.high
        let rain = precipitationProbability(day.weather.precipitation.value)
        guard low != nil || high != nil || rain != nil else { return nil }
        return TripWeatherTrendSampleProjection(
            id: day.identity,
            date: String(format: "%02d-%02d", day.date.month, day.date.day),
            low: low,
            high: high,
            rain: rain
        )
    }

    private static func precipitationProbability(_ text: String?) -> Double? {
        guard let text,
              let match = text.range(of: "(\\d+(?:\\.\\d+)?)\\s*%", options: .regularExpression)
        else { return nil }
        let number = Double(text[match].dropLast().trimmingCharacters(in: .whitespaces))
        return number.map { $0 / 100 }
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
        if !weatherDayProjections.isEmpty || detail.trip.weatherOverview?.summary.value != nil {
            result.append(.weather)
        }
        result.append(.equipment)
        if !notices.isEmpty { result.append(.notices) }
        return result
    }

    var showsPageLevelCancel: Bool { detail.trip.status == .planned }

    private static func dayProjection(_ day: PersonalTripDay, totalTrekDays: Int) -> TripDayProjection {
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
            resources: presentation.pointItems.map { item in
                TripDayResourceProjection(
                    id: "point-\(item.sequence)",
                    category: item.point.type,
                    name: item.point.name,
                    distance: item.point.distance?.value.map { distanceText($0.meters) }
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
            dailyRouteSummary: nil,
            totalTrekDays: totalTrekDays,
            outboundTransport: transportProjection(day: day, direction: .outbound),
            hikeSummary: hikeProjection(from: day.actions),
            returnTransport: transportProjection(day: day, direction: .return)
        )
    }

    static func actionTitle(_ action: PersonalTripAction) -> String {
        switch action.actionType {
        case "long_distance_transport": "大交通"
        case "route_transfer": "路线接驳"
        case "hike": action.routeSectionSnapshot?.name ?? "徒步"
        default: action.actionType
        }
    }

    /// 接驳块按徒步行动分段：首段徒步之前的交通为去程，末段徒步之后的为返程。
    static func transportProjection(
        day: PersonalTripDay,
        direction: TripDayTransportSummaryProjection.Direction
    ) -> TripDayTransportSummaryProjection? {
        let transportActions = day.actions.filter {
            ["long_distance_transport", "route_transfer"].contains($0.actionType)
        }
        guard !transportActions.isEmpty else { return nil }

        let hikeSequences = day.actions
            .filter { $0.actionType == "hike" }
            .map(\.sequence)
        let selected: [PersonalTripAction]
        switch direction {
        case .outbound:
            guard let firstHike = hikeSequences.min() else { return nil }
            selected = transportActions.filter { $0.sequence < firstHike }
        case .return:
            guard let lastHike = hikeSequences.max() else { return nil }
            selected = transportActions.filter { $0.sequence > lastHike }
        }
        guard !selected.isEmpty else { return nil }
        return transportProjection(from: selected, direction: direction)
    }

    /// 由给定交通行动集合构造接驳摘要投影；供浏览页无徒步日复用。
    static func transportProjection(
        from selected: [PersonalTripAction],
        direction: TripDayTransportSummaryProjection.Direction
    ) -> TripDayTransportSummaryProjection? {
        guard !selected.isEmpty else { return nil }

        let places = selected.compactMap { action -> [String]? in
            let origin = action.origin?.value?.name
            let destination = action.destination?.value?.name
            guard origin != nil || destination != nil else { return nil }
            return [origin, destination].compactMap { $0 }
        }
        let path = places.map { $0.joined(separator: " → ") }.joined(separator: " → ")
        let modes = selected.compactMap { tripNonEmpty($0.mode?.value) }.joined(separator: "、")
        let transferNotes = selected.flatMap {
            $0.transferNotes?.value ?? []
        }.joined(separator: "、")
        let durationSeconds = selected.compactMap {
            $0.estimatedDuration?.value?.seconds
        }.reduce(0, +)
        let timeRange = selected.compactMap {
            $0.keyTimes?.value?.joined(separator: "、")
        }.joined(separator: "、")

        return TripDayTransportSummaryProjection(
            direction: direction,
            title: "",
            timeRange: tripNonEmpty(timeRange),
            duration: durationSeconds > 0 ? tripDurationTextForProjection(durationSeconds) : nil,
            path: tripNonEmpty(path),
            modes: tripNonEmpty(modes),
            notice: tripNonEmpty(transferNotes)
        )
    }

    static func hikeProjection(from actions: [PersonalTripAction]) -> TripDayHikeSummaryProjection? {
        guard let hike = actions.first(where: { $0.actionType == "hike" }) else { return nil }

        var nodes: [TripDayHikeNodeProjection] = []
        if let start = hike.start?.value {
            nodes.append(TripDayHikeNodeProjection(type: "起点", name: start.name, position: nil))
        }
        if let end = hike.end?.value {
            nodes.append(TripDayHikeNodeProjection(type: "终点", name: end.name, position: nil))
        }

        return TripDayHikeSummaryProjection(
            segment: tripNonEmpty(hike.routeSectionSnapshot?.name) ?? "徒步段",
            distance: hike.distance?.value.map { Self.distanceText($0.meters) },
            ascent: hike.ascent?.value.map { "\(Int($0.meters.rounded())) m" },
            duration: hike.estimatedDuration?.value.map { tripDurationTextForProjection($0.seconds) },
            nodes: nodes
        )
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

    private static func tripDurationTextForProjection(_ seconds: Double) -> String {
        let hours = seconds / 3_600
        return hours >= 1
            ? "\((hours * 10).rounded() / 10) 小时"
            : "\(Int((seconds / 60).rounded())) 分钟"
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
