import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appEnvironment: AppEnvironment
    @State private var path: [RootDestination] = []
    @State private var isDrawerOpen = false
    @State private var selectedHomeRoute: Route?
    @State private var isRoutePickerPresented = false
    @StateObject private var viewModel = RootViewModel()
    private let routeSelectionStore = UserDefaultsCurrentRouteSelectionStore()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .leading) {
                HomeView(
                    onOpenDrawer: openDrawer,
                    onFindRoute: presentRoutePicker,
                    onNavigate: navigate,
                    selectionStore: routeSelectionStore,
                    routeService: appEnvironment.routeService,
                    selectedRoute: selectedHomeRoute
                )
                .allowsHitTesting(!isDrawerOpen)
                .accessibilityHidden(isDrawerOpen)

                if isRoutePickerPresented {
                    RouteDiscoveryView(routeService: appEnvironment.routeService) { route in
                        routeSelectionStore.selectRoute(id: route.id)
                        selectedHomeRoute = route
                        withAnimation(.easeInOut(duration: HomePresentation.fadeDuration)) {
                            isRoutePickerPresented = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }

                if isDrawerOpen {
                    Color.black.opacity(RootNavigation.drawerOverlayOpacity)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture(perform: closeDrawer)
                        .accessibilityLabel("关闭功能菜单")
                        .accessibilityAddTraits(.isButton)

                    DrawerView(
                        userDisplay: viewModel.drawerUserDisplay,
                        onNavigate: navigate,
                        onProfile: { navigate(to: RootNavigation.profileDestination) }
                    )
                    .ignoresSafeArea(edges: .bottom)
                    .transition(.move(edge: .leading))
                    .accessibilityAddTraits(.isModal)
                    .zIndex(3)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isDrawerOpen)
            .navigationDestination(for: RootDestination.self, destination: destinationView)
        }
        .tint(AppColors.interactiveAccent)
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadDrawerUser()
        }
    }

    private func openDrawer() {
        guard !isRoutePickerPresented else { return }
        isDrawerOpen = true
        Task { await viewModel.loadDrawerUser() }
    }

    private func closeDrawer() {
        isDrawerOpen = false
    }

    private func presentRoutePicker() {
        guard !isRoutePickerPresented else { return }
        closeDrawer()
        withAnimation(.easeInOut(duration: HomePresentation.fadeDuration)) {
            isRoutePickerPresented = true
        }
    }

    private func navigate(to destination: RootDestination) {
        closeDrawer()
        guard path.last != destination else { return }
        path.append(destination)
    }

    @ViewBuilder
    private func destinationView(for destination: RootDestination) -> some View {
        switch destination {
        case .routes: RouteDiscoveryView(routeService: appEnvironment.routeService)
        case .trips:
            TripListView(
                repository: appEnvironment.tripRepository,
                routeService: appEnvironment.routeService
            )
        case .guides: GuideListView()
        case .equipment: EquipmentListView()
        case let .routeDetail(routeID):
            RouteDetailView(routeId: routeID, service: appEnvironment.routeService)
        case .navigation: NavigationPlaceholderView()
        case .profile:
            ProfileView(
                tripRepository: appEnvironment.tripRepository,
                apiStorage: appEnvironment.apiStorage,
                storageGeneration: appEnvironment.apiStorageGeneration
            )
        }
    }
}
