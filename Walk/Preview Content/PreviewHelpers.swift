#if DEBUG
import SwiftUI

enum PreviewHelpers {
    static let routeService: RouteService = {
        let userID = "preview-user"
        return RouteService(
            apiClient: MockAPIClient(fixtures: DefaultMockFixtures.all(userID: userID)),
            userID: userID
        )
    }()
}

struct PreviewTripRepository: TripRepository {
    func fetchTrips(
        keyword: String?, status: TripStatus?, organizerID: String?, participantID: String?,
        page: Int, size: Int, sort: [String]
    ) async throws -> Page<Trip> {
        Page(items: MockData.trips, number: 0, size: size, totalElements: MockData.trips.count, totalPages: 1, first: true, last: true)
    }

    func fetchTrip(id: String) async throws -> Trip {
        guard let trip = MockData.trips.first(where: { $0.id == id }) ?? MockData.trips.first else {
            throw APIClientError.mockNotFound("GET /trips/\(id)")
        }
        return trip
    }

    func createTrip(_ input: TripCreateRequestDTO) async throws -> Trip { throw APIClientError.mockNotFound("POST /trips") }
    func updateTrip(id: String, input: TripUpdateRequestDTO) async throws -> Trip { throw APIClientError.mockNotFound("PUT /trips/\(id)") }
    func deleteTrip(id: String) async throws { throw APIClientError.mockNotFound("DELETE /trips/\(id)") }
    func updateTripStatus(id: String, status: TripStatus) async throws -> Trip { throw APIClientError.mockNotFound("PATCH /trips/\(id)/status") }
}

extension TripListViewModel {
    static var preview: TripListViewModel {
        let vm = TripListViewModel(repository: PreviewTripRepository())
        vm.trips = MockData.trips
        return vm
    }
}

extension TripDetailViewModel {
    static var preview: TripDetailViewModel {
        let vm = TripDetailViewModel(repository: PreviewTripRepository(), loadRoute: { _ in MockData.routes.first })
        vm.trip = MockData.trips.first
        vm.associatedRouteName = MockData.routes.first?.name
        vm.mapCoordinates = MockData.wutaiShanCoordinates
        return vm
    }
}

extension RouteDiscoveryViewModel {
    static var preview: RouteDiscoveryViewModel {
        let vm = RouteDiscoveryViewModel(service: PreviewHelpers.routeService)
        vm.routes = MockData.routes
        return vm
    }
}

extension EquipmentListViewModel {
    static var preview: EquipmentListViewModel {
        let vm = EquipmentListViewModel()
        vm.checklist = MockData.equipmentChecklist
        vm.checkedItems = Set(MockData.equipment.filter { $0.isChecked == true }.map { $0.id })
        return vm
    }
}

extension GuideListViewModel {
    static var preview: GuideListViewModel {
        let vm = GuideListViewModel()
        vm.guides = MockData.guides
        return vm
    }
}

extension GuideDetailViewModel {
    static var preview: GuideDetailViewModel {
        let vm = GuideDetailViewModel()
        vm.guide = MockData.guides.first
        return vm
    }
}

extension ProfileViewModel {
    static var preview: ProfileViewModel {
        let vm = ProfileViewModel(tripRepository: PreviewTripRepository())
        vm.user = MockData.user
        vm.isLoggedIn = true
        vm.tripCount = 12
        vm.routeCount = 8
        vm.totalDistance = 156
        return vm
    }
}

struct PreviewContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
    }
}
#endif
