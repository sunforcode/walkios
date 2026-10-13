import Foundation
import Observation
import WalkData

@MainActor @Observable
final class CreateTripViewModel {
    private(set) var state = CreateTripState()
    let routeID: String

    private let loadContext: (String) async throws -> PersonalTripGenerationContext
    private let createTrip: (PersonalTripCreateRequest, String) async throws -> PersonalTripGenerationResult
    private let idempotencyKey: () -> String
    @ObservationIgnored private var lastRequest: PersonalTripCreateRequest?
    @ObservationIgnored private var lastIdempotencyKey: String?
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var shouldRefreshContextOnAppearance = false
    @ObservationIgnored private var loading: TripRequestLifetime?

    var context: PersonalTripGenerationContext? { state.context }
    var departureCity: String { state.draft.departureCity }
    var startDate: Date { state.draft.startDate }
    var selectedEquipmentListID: String? { state.draft.selectedEquipmentListID }
    var selectedTransportOptionID: String? { state.draft.selectedTransportOptionID }
    var transportSelection: PersonalTripTransportSelection? { state.transportSelection }
    var isVersionConflict: Bool { state.isVersionConflict }
    var isLoading: Bool { state.isLoading }
    var isSubmitting: Bool { state.phase == .submitting }
    var errorMessage: String? { state.errorMessage }
    var departureCityError: String? { state.departureCityError }
    var canSubmit: Bool { state.canSubmit }
    var createdTripID: String? {
        if case .created(let id) = state.phase { return id }
        return nil
    }

    convenience init(routeID: String, service: any PersonalTripServicing) {
        self.init(
            routeID: routeID,
            loadContext: { try await service.generationContext(routeID: $0) },
            createTrip: { try await service.create($0, idempotencyKey: $1) }
        )
    }

    init(
        routeID: String,
        loadContext: @escaping (String) async throws -> PersonalTripGenerationContext,
        createTrip: @escaping (PersonalTripCreateRequest, String) async throws -> PersonalTripGenerationResult,
        idempotencyKey: @escaping () -> String = { UUID().uuidString }
    ) {
        self.routeID = routeID
        self.loadContext = loadContext
        self.createTrip = createTrip
        self.idempotencyKey = idempotencyKey
    }

    func updateDepartureCity(_ value: String) {
        guard !isSubmitting, value != departureCity else { return }
        state.draft.departureCity = value
        invalidateTransportSelection()
    }

    func updateStartDate(_ value: Date) {
        guard !isSubmitting, value != startDate else { return }
        state.draft.startDate = value
        invalidateTransportSelection()
    }

    func selectEquipmentList(_ value: String?) {
        guard !isSubmitting, value != selectedEquipmentListID else { return }
        state.draft.selectedEquipmentListID = value
        invalidateTransportSelection()
    }

    func selectTransportOption(_ value: String?) {
        guard !isSubmitting else { return }
        state.draft.selectedTransportOptionID = value
    }

    func load() async {
        guard !Task.isCancelled, !isSubmitting, loading == nil || loading?.isCancelled == true else { return }
        let request = TripRequestLifetime()
        loading = request
        let conflict = isVersionConflict
        state.phase = .loading(versionConflict: conflict)
        state.errorMessage = nil
        defer {
            if loading === request {
                loading = nil
                if state.isLoading { state.phase = conflict ? .versionConflict : (hasLoaded ? .ready : .idle) }
            }
        }
        await withTaskCancellationHandler {
            do {
                let context = try await loadContext(routeID)
                guard loading === request, !request.isCancelled, !Task.isCancelled else { return }
                state.context = context
                hasLoaded = true
                shouldRefreshContextOnAppearance = false
                state.phase = .ready
                // Preserve the existing equipment-return transport reset in this migration.
                state.transportSelection = nil
                state.draft.selectedTransportOptionID = nil
                lastRequest = nil
                lastIdempotencyKey = nil
                if let selectedEquipmentListID,
                   !context.equipmentLists.contains(where: { $0.equipmentListID == selectedEquipmentListID }) {
                    state.draft.selectedEquipmentListID = nil
                }
            } catch {
                guard loading === request, !request.isCancelled, !Task.isCancelled,
                      !tripRequestWasCancelled(error) else { return }
                state.errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "加载失败：\(error.localizedDescription)"
            }
        } onCancel: {
            request.cancel()
        }
    }

    func prepareForPersonalEquipment() { shouldRefreshContextOnAppearance = true }

    func handleAppearance() async {
        guard !hasLoaded || shouldRefreshContextOnAppearance else { return }
        await load()
    }

    func submit() async {
        guard !Task.isCancelled, !isSubmitting, canSubmit, let context else { return }
        let transport = transportSelection.flatMap { selection in
            selectedTransportOptionID.map {
                PersonalTripTransportSelectionRequest(selectionID: selection.selectionID, transportOptionID: $0)
            }
        }
        let request = PersonalTripCreateRequest(
            routeID: routeID,
            routeVersionID: context.route.currentPublicRouteVersionID,
            departureCity: departureCity.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: LocalDate(date: startDate, calendar: .business),
            equipmentListID: selectedEquipmentListID,
            transportSelection: transport
        )
        let key: String
        if lastRequest == request, let lastIdempotencyKey {
            key = lastIdempotencyKey
        } else {
            key = idempotencyKey()
            lastRequest = request
            lastIdempotencyKey = key
        }
        // Keep the submitting phase until the write returns, even on cancellation.
        // A cancelled client task does not prove the backend write did not happen.
        state.phase = .submitting
        state.errorMessage = nil
        defer {
            if state.phase == .submitting { state.phase = .ready }
        }
        do {
            let result = try await createTrip(request, key)
            guard !Task.isCancelled else { return }
            switch result {
            case .transportSelectionRequired(let selection):
                guard selection.options.count >= 2 else {
                    state.transportSelection = nil
                    state.draft.selectedTransportOptionID = nil
                    throw APIClientError.invalidResponse
                }
                state.transportSelection = selection
                state.draft.selectedTransportOptionID = nil
                lastRequest = nil
                lastIdempotencyKey = nil
            case .tripCreated(let detail):
                state.transportSelection = nil
                state.phase = .created(detail.trip.identity)
            }
        } catch {
            guard !Task.isCancelled, !tripRequestWasCancelled(error) else { return }
            if case APIClientError.api(let code, _, _, _) = error, code == "route_version_conflict" {
                state.phase = .versionConflict
                state.transportSelection = nil
                state.draft.selectedTransportOptionID = nil
                lastRequest = nil
                lastIdempotencyKey = nil
            } else {
                state.errorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "生成失败：\(error.localizedDescription)"
            }
        }
    }

    private func invalidateTransportSelection() {
        guard transportSelection != nil else { return }
        state.transportSelection = nil
        state.draft.selectedTransportOptionID = nil
        lastRequest = nil
        lastIdempotencyKey = nil
    }
}
