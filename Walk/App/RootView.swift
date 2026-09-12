import SwiftUI
import WalkData
import WalkDesignSystem

struct RootView: View {
    @ObservedObject private var appEnvironment: AppEnvironment
    @State private var shell = AppShellState()
    @State private var pendingAuthIntent: PendingAuthIntent?
    @State private var pendingAuthTab: AppTab?
    /// account-access：认证链路确认的焦点行程结果，execute(.homeStart) 只消费该结果。
    @State private var confirmedFocusTripExists: Bool?
    @State private var authenticationGeneration = 0
    /// S5：搜索会话状态提升到 App 层，返回后再进 PAGE-SEARCH 恢复 query 与结果。
    @StateObject private var routeSearchModel: RouteDiscoveryViewModel
    @State private var routeSearchQuery = ""
    /// 我的区域与账户菜单共享同一账号/退出状态，提升到 App 层。
    @StateObject private var profileModel: ProfileViewModel

    init(appEnvironment: AppEnvironment) {
        _appEnvironment = ObservedObject(wrappedValue: appEnvironment)
        _routeSearchModel = StateObject(wrappedValue: RouteDiscoveryViewModel(service: appEnvironment.routeService))
        _profileModel = StateObject(wrappedValue: ProfileViewModel(
            accountService: appEnvironment.accountService,
            tripService: appEnvironment.personalTripService,
            equipmentService: appEnvironment.equipmentService,
            clearCachedResponses: {
                await appEnvironment.apiStorageGeneration.invalidate()
                try? await appEnvironment.apiStorage.removeAll()
            }
        ))
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            tabStack(for: .home) { homeRoot }
                .tabItem { Label(AppTab.home.title, systemImage: AppTab.home.systemImage) }
                .tag(AppTab.home)

            tabStack(for: .routes) { routesRoot }
                .tabItem { Label(AppTab.routes.title, systemImage: AppTab.routes.systemImage) }
                .tag(AppTab.routes)

            tabStack(for: .profile) { profileRoot }
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $shell.isLoginPresented) {
            loginCover
                .interactiveDismissDisabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: .walkAuthenticationRequired)) { _ in
            requestAuthentication(.reauthenticate, in: shell.selectedTab, force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .walkAuthenticationDidChange)) { _ in
            authenticationGeneration += 1
        }
        .onChange(of: shell.selectedTab) { tab in
            guard tab == .routes, shell.path(for: .routes).isEmpty else { return }
            shell.routeListShowsBackEntry = false
        }
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(get: { shell.selectedTab }, set: { shell.selectTab($0) })
    }

    /// PAGE-LOGIN：Modal 任务承载，全屏覆盖呈现，不进入任务栈。
    private var loginCover: some View {
        LoginView(
            accountService: appEnvironment.accountService,
            intent: pendingAuthIntent,
            onConfirmFocusTrip: pendingAuthIntent == .homeStart
                ? { [appEnvironment] in
                    try await appEnvironment.personalTripService.focus().trip != nil
                }
                : nil,
            onConfirmedFocusTrip: { confirmedFocusTripExists = $0 },
            onAuthenticated: completeAuthentication,
            onCancel: {
                confirmedFocusTripExists = nil
                pendingAuthIntent = nil
                pendingAuthTab = nil
            }
        )
    }

    private func pathBinding(for tab: AppTab) -> Binding<[AppDestination]> {
        Binding(get: { shell.path(for: tab) }, set: { shell.setPath($0, for: tab) })
    }

    private func tabStack<Content: View>(
        for tab: AppTab,
        @ViewBuilder root: () -> Content
    ) -> some View {
        NavigationStack(path: pathBinding(for: tab)) {
            root().navigationDestination(for: AppDestination.self, destination: destinationView)
        }
    }

    private var homeRoot: some View {
        HomeView(
            onAuthenticate: { requestAuthentication($0, in: .home) },
            onNavigate: { navigate($0, in: .home) },
            onNoFocus: {
                shell.showRouteList()
            },
            service: appEnvironment.personalTripService
        )
        .id(authenticationGeneration)
    }

    private var routesRoot: some View {
        RouteDiscoveryView(
            routeService: appEnvironment.routeService,
            onNavigate: { destination in
                if destination == .routeList { shell.routeListShowsBackEntry = true }
                navigate(destination, in: .routes)
            }
        )
        .toolbar(.hidden, for: .navigationBar)
    }

    private var profileRoot: some View {
        ProfileView(
            viewModel: profileModel,
            onNavigate: { navigate($0, in: .profile) },
            onAuthenticate: { requestAuthentication($0, in: .profile) },
            onLoggedOut: handleLoggedOut
        )
        .id(authenticationGeneration)
    }

    private func handleLoggedOut() {
        shell.showRouteDiscovery()
        authenticationGeneration += 1
    }

    private func requestAuthentication(
        _ intent: PendingAuthIntent,
        in tab: AppTab,
        force: Bool = false
    ) {
        if appEnvironment.authManager.isLoggedIn && !force {
            execute(intent, in: tab)
            return
        }
        pendingAuthIntent = intent
        pendingAuthTab = tab
        shell.presentLogin()
    }

    private func completeAuthentication() {
        let intent = pendingAuthIntent
        let tab = pendingAuthTab ?? shell.selectedTab
        shell.dismissLogin()
        pendingAuthIntent = nil
        pendingAuthTab = nil
        authenticationGeneration += 1
        if let intent { execute(intent, in: tab) }
    }

    private func execute(_ intent: PendingAuthIntent, in tab: AppTab) {
        switch intent {
        case .homeStart:
            // account-access：焦点行程结果由认证链路确认（confirmingFocus/focusError），
            // 无法确认时不会走到这里；此处只消费已确认结果，不再自行 catch 落回首页。
            guard let focusExists = confirmedFocusTripExists else { return }
            confirmedFocusTripExists = nil
            if focusExists {
                shell.setPath([], for: .home)
                shell.selectTab(.home)
            } else {
                shell.showRouteList()
            }
        case .profile:
            shell.selectTab(.profile)
            authenticationGeneration += 1
        case .createTrip(let routeID):
            navigate(.createTrip(routeID: routeID), in: tab)
        case .reauthenticate:
            break
        }
    }

    private func navigate(_ destination: AppDestination, in tab: AppTab) {
        var path = shell.path(for: tab)
        guard path.last != destination else { return }
        path.append(destination)
        shell.setPath(path, for: tab)
    }

    @ViewBuilder
    private func destinationView(for destination: AppDestination) -> some View {
        Group {
            switch destination {
            case .routeList:
                RouteCollectionView(
                    routeService: appEnvironment.routeService,
                    showsBackButton: shell.routeListShowsBackEntry,
                    onNavigate: { navigate($0, in: shell.selectedTab) }
                )
            case .routeSearch:
                RouteSearchView(
                    model: routeSearchModel,
                    query: $routeSearchQuery,
                    onNavigate: { navigate($0, in: shell.selectedTab) }
                )
            case let .routeDetail(routeID):
                RouteDetailView(
                    routeId: routeID,
                    service: appEnvironment.routeService,
                    onGenerateTrip: { selectedRouteID in
                        requestAuthentication(.createTrip(routeID: selectedRouteID), in: shell.selectedTab)
                    }
                )
            case .profileDetails:
                ProfileDetailsView(accountService: appEnvironment.accountService)
            case .accountSecurity:
                AccountSecurityView(accountService: appEnvironment.accountService)
            case .accountMenu:
                AccountMenuView(
                    viewModel: profileModel,
                    onNavigate: { navigate($0, in: shell.selectedTab) },
                    onLoggedOut: handleLoggedOut
                )
            case .tripList:
                TripListView(
                    service: appEnvironment.personalTripService,
                    onNavigate: { navigate($0, in: shell.selectedTab) },
                    onFindRoute: {
                        shell.showRouteList()
                    }
                )
            case let .tripDetail(tripID):
                TripDetailView(
                    tripID: tripID,
                    service: appEnvironment.personalTripService,
                    reloadRevision: shell.reloadRevision(for: tripID),
                    onOpenRoute: { navigate(.routeDetail($0), in: shell.selectedTab) },
                    onOpenEquipment: { navigate(.tripEquipment(tripID), in: shell.selectedTab) },
                    onOpenDay: {
                        navigate(.tripDay(tripID: tripID, initialDayID: $0), in: shell.selectedTab)
                    },
                    onOpenWeather: {
                        navigate(.tripWeather(tripID), in: shell.selectedTab)
                    }
                )
            case let .tripEquipment(tripID):
                TripEquipmentView(
                    tripID: tripID,
                    service: appEnvironment.tripEquipmentService,
                    onManagePersonalEquipment: {
                        navigate(.personalEquipment, in: shell.selectedTab)
                    },
                    onRevisionChange: { shell.recordTripRevision($0, tripID: tripID) }
                )
            case .personalEquipment:
                EquipmentListView(
                    service: appEnvironment.equipmentService,
                    onEditEquipment: {
                        navigate(.equipmentEdit(equipmentID: $0), in: shell.selectedTab)
                    }
                )
            case let .equipmentEdit(equipmentID):
                EquipmentEditView(
                    service: appEnvironment.equipmentService,
                    equipmentID: equipmentID
                )
            case let .tripDay(tripID, initialDayID):
                TripDayView(
                    tripID: tripID,
                    initialDayID: initialDayID,
                    service: appEnvironment.personalTripService
                )
            case let .tripWeather(tripID):
                TripWeatherView(tripID: tripID, service: appEnvironment.personalTripService)
            case .notificationSettings:
                NotificationSettingsView()
            case .privacySettings:
                PrivacySettingsView()
            case .helpAndFeedback:
                HelpAndFeedbackView()
            case .about:
                AboutView()
            case let .createTrip(routeID):
                CreateTripView(
                    routeID: routeID,
                    service: appEnvironment.personalTripService,
                    onManagePersonalEquipment: {
                        navigate(.personalEquipment, in: shell.selectedTab)
                    },
                    onTripCreated: { tripID in
                        shell.replaceTop(with: .tripDetail(tripID), in: shell.selectedTab)
                    }
                )
            }
        }
        // 系统tab bar 只在一级根页面可见；二级任务栈与 Modal 任务内隐藏。
        .toolbar(.hidden, for: .tabBar)
    }
}
