#if DEBUG
import SwiftUI
import WalkData
import WalkDesignSystem

enum PreviewHelpers {
    static let apiClient = MockAPIClient(fixtures: DefaultMockFixtures.all())

    static let routeService = RouteService(apiClient: apiClient)
    static let personalTripService = PersonalTripService(apiClient: apiClient)
    static let equipmentService = EquipmentService(apiClient: apiClient)
    static let accountService = AccountService(apiClient: apiClient)
}

extension TripListViewModel {
    static var preview: TripListViewModel {
        TripListViewModel(service: PreviewHelpers.personalTripService)
    }
}

extension TripDetailViewModel {
    static var preview: TripDetailViewModel {
        TripDetailViewModel(service: PreviewHelpers.personalTripService)
    }
}

extension RouteDiscoveryViewModel {
    static var preview: RouteDiscoveryViewModel {
        let vm = RouteDiscoveryViewModel(service: PreviewHelpers.routeService)
        vm.routes = [
            PublicRouteBrowseSummary(
                routeId: "route-1",
                currentVersionId: "route-1-v1",
                cover: nil,
                name: "贡嘎环线",
                region: "四川甘孜",
                difficulty: "中等",
                distance: RouteDistance(meters: 42_500),
                ascent: RouteElevationGain(meters: 2_300),
                estimatedDuration: RouteDuration(seconds: 259_200)
            )
        ]
        return vm
    }
}

extension EquipmentListViewModel {
    static var preview: EquipmentListViewModel {
        EquipmentListViewModel(service: EquipmentService(
            apiClient: MockAPIClient(fixtures: DefaultMockFixtures.all())
        ))
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
