import Foundation
import Observation
import WalkData

@MainActor @Observable
final class TripListViewModel {
    private(set) var currentTrips: [PersonalTripSummary] = []
    private(set) var historicalTrips: [PersonalTripSummary] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let fetchTrips: () async throws -> PersonalTripCollection
    @ObservationIgnored private var loading: TripRequestLifetime?
    let automaticallyLoads = true

    init(service: any PersonalTripServicing) {
        self.fetchTrips = { try await service.list() }
    }

    init(loadTrips: @escaping () async throws -> PersonalTripCollection) {
        self.fetchTrips = loadTrips
    }

    var isEmpty: Bool {
        currentTrips.isEmpty && historicalTrips.isEmpty
    }

    func loadTrips() async {
        guard !Task.isCancelled, loading == nil || loading?.isCancelled == true else { return }
        let request = TripRequestLifetime()
        loading = request
        isLoading = true
        errorMessage = nil
        defer {
            if loading === request {
                loading = nil
                isLoading = false
            }
        }
        await withTaskCancellationHandler {
            do {
                let collection = try await fetchTrips()
                guard loading === request, !request.isCancelled, !Task.isCancelled else { return }
                currentTrips = collection.currentTrips
                historicalTrips = collection.historicalTrips
            } catch {
                guard loading === request, !request.isCancelled, !Task.isCancelled,
                      !tripRequestWasCancelled(error) else { return }
                currentTrips = []
                historicalTrips = []
                if let localized = error as? LocalizedError {
                    errorMessage = localized.errorDescription ?? error.localizedDescription
                } else {
                    errorMessage = "加载失败：\(error.localizedDescription)"
                }
            }
        } onCancel: {
            request.cancel()
        }
    }

    func retry() async { await loadTrips() }
    func refresh() async { await loadTrips() }
}
