import SwiftUI

@MainActor
final class TripListViewModel: ObservableObject {
    @Published private(set) var currentTrips: [PersonalTripSummary] = []
    @Published private(set) var historicalTrips: [PersonalTripSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let fetchTrips: () async throws -> PersonalTripCollection

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
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let collection = try await fetchTrips()
            currentTrips = collection.currentTrips
            historicalTrips = collection.historicalTrips
        } catch let error as LocalizedError {
            currentTrips = []
            historicalTrips = []
            errorMessage = error.errorDescription ?? error.localizedDescription
        } catch {
            currentTrips = []
            historicalTrips = []
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    func retry() async { await loadTrips() }
    func refresh() async { await loadTrips() }
}
