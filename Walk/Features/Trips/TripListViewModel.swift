import SwiftUI

@MainActor
final class TripListViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let repository: any TripRepository

    init(repository: any TripRepository) {
        self.repository = repository
    }

    func loadTrips() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            trips = try await repository.fetchTrips().items
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? error.localizedDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    func retry() async {
        errorMessage = nil
        await loadTrips()
    }

    func refresh() async {
        await loadTrips()
    }
}
