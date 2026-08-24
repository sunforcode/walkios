import SwiftUI
import CoreLocation

@MainActor
final class TripDetailViewModel: ObservableObject {
    @Published var trip: Trip?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var mapCoordinates: [CLLocationCoordinate2D] = []
    @Published var associatedRouteName: String?

    private let repository: any TripRepository
    private let loadRoute: (String) async throws -> Route?

    init(
        repository: any TripRepository,
        loadRoute: @escaping (String) async throws -> Route?
    ) {
        self.repository = repository
        self.loadRoute = loadRoute
    }

    static var fallbackCoordinates: [CLLocationCoordinate2D] {
        #if DEBUG
        MockData.wutaiShanCoordinates
        #else
        []
        #endif
    }

    func loadTrip(id: String) async {
        isLoading = true
        errorMessage = nil
        mapCoordinates = []
        associatedRouteName = nil
        defer { isLoading = false }

        do {
            trip = try await repository.fetchTrip(id: id)
            if let routeID = trip?.routeId {
                await loadAssociatedRoute(routeID: routeID)
            }
        } catch let error as LocalizedError {
            errorMessage = error.errorDescription ?? error.localizedDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }
    }

    private func loadAssociatedRoute(routeID: String) async {
        do {
            let route = try await loadRoute(routeID)
            associatedRouteName = route?.name
            mapCoordinates = route == nil ? [] : Self.fallbackCoordinates
        } catch {
            associatedRouteName = nil
            mapCoordinates = []
        }
    }
}
