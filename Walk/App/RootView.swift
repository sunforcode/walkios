import SwiftUI
import WalkData
import WalkDesignSystem

struct RootView: View {
    @ObservedObject private var appEnvironment: AppEnvironment
    @State private var shell = AppShellState()
    /// 认证编排：待处理意图与来源 tab（account-access / app-flow）。
    @State private var authFlow = AuthenticationFlow()
    @State private var authenticationGeneration = 0
    @State private var authenticationIdentity: String?
    @State private var tripEquipmentSession = TripEquipmentSession()
    /// S5：搜索会话状态提升到 App 层，返回后再进 PAGE-SEARCH 恢复 query 与结果。
    @State private var routeSearchModel: RouteDiscoveryViewModel
    @State private var routeSearchQuery = ""
    /// 我的区域与账户菜单共享同一账号/退出状态，提升到 App 层。
    @State private var profileModel: ProfileViewModel

    init(appEnvironment: AppEnvironment) {
        _appEnvironment = ObservedObject(wrappedValue: appEnvironment)
        _authenticationIdentity = State(initialValue: appEnvironment.authManager.isLoggedIn ? appEnvironment.authManager.cacheIdentity : nil)
        _routeSearchModel = State(initialValue: RouteDiscoveryViewModel(service: appEnvironment.routeService))
        _profileModel = State(initialValue: ProfileViewModel(
            accountService: appEnvironment.accountService,
            tripService: appEnvironment.personalTripService,
            authSession: appEnvironment.authManager,
            clearCachedResponses: {
                await appEnvironment.apiStorageGeneration.invalidate()
                try? await appEnvironment.apiStorage.removeAll()
            }
        ))
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
            tabStack(for: .trips) { tripsRoot }
                .tabItem { Label(AppTab.trips.title, systemImage: AppTab.trips.systemImage) }
                .tag(AppTab.trips)

            tabStack(for: .routes) { routesRoot }
                .tabItem { Label(AppTab.routes.title, systemImage: AppTab.routes.systemImage) }
                .tag(AppTab.routes)

            tabStack(for: .equipment) { equipmentRoot }
                .tabItem { Label(AppTab.equipment.title, systemImage: AppTab.equipment.systemImage) }
                .tag(AppTab.equipment)

            tabStack(for: .profile) { profileRoot }
                .tabItem { Label(AppTab.profile.title, systemImage: AppTab.profile.systemImage) }
                .tag(AppTab.profile)
        }
        .preferredColorScheme(.dark)
        .toolbarBackground(AppColors.pageBase, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .fullScreenCover(isPresented: $shell.isLoginPresented) {
            loginCover
                .interactiveDismissDisabled()
        }
        .overlay {
            if shell.isAccountMenuPresented {
                accountMenuCover
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: shell.isAccountMenuPresented)
        .onReceive(NotificationCenter.default.publisher(for: .walkAuthenticationRequired, object: appEnvironment.authManager)) { _ in
            requestAuthentication(.reauthenticate, in: shell.selectedTab, force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .walkAuthenticationDidChange, object: appEnvironment.authManager)) { _ in
            synchronizeAuthentication()
        }
        .onChange(of: shell.selectedTab) { tab in
            guard tab == .routes, shell.path(for: .routes).isEmpty else { return }
            shell.routeListShowsBackEntry = false
        }
        .onChange(of: shell.path(for: .profile)) { path in
            // 设置项经我的页任务栈承接：父级任务栈一旦推入新页，Sheet 立即关闭，
            // 模态不残留覆盖在推入页之上。
            if shell.isAccountMenuPresented && !path.isEmpty {
                shell.dismissAccountMenu()
            }
        }
    }

    private var selectedTabBinding: Binding<AppTab> {
        Binding(get: { shell.selectedTab }, set: { shell.selectTab($0) })
    }

    /// PAGE-LOGIN：Modal 任务承载，全屏覆盖呈现，不进入任务栈。
    private var loginCover: some View {
        LoginView(
            accountService: appEnvironment.accountService,
            intent: authFlow.pending?.intent,
            onAuthenticated: completeAuthentication,
            onCancel: {
                authFlow.cancel()
                shell.discardSuspendedTask()
            }
        )
    }

    /// PAGE-ACCOUNT-MENU：Modal 任务，以 App 层 overlay 呈现模态 Sheet，只承载设置主页；
    /// 设置项经我的页任务栈承接：先关闭 Sheet，再从我的页任务栈推入目标页。
    private var accountMenuCover: some View {
        AccountMenuView(
            viewModel: profileModel,
            onClose: { shell.dismissAccountMenu() },
            onNavigate: { destination in
                shell.dismissAccountMenu()
                navigate(destination, in: .profile)
            },
            onLoggedOut: handleLoggedOut
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

    @ViewBuilder
    private var tripsRoot: some View {
        HomeView(
            onAuthenticate: { requestAuthentication($0, in: .trips) },
            onNavigate: { navigate($0, in: .trips) },
            service: appEnvironment.personalTripService,
            authSession: appEnvironment.authManager
        )
        .id(authenticationGeneration)
    }

    @ViewBuilder
    private var equipmentRoot: some View {
        Group {
            if appEnvironment.authManager.isLoggedIn {
                EquipmentListView(
                    service: appEnvironment.equipmentService,
                    presentation: .root,
                    onEditEquipment: { navigate(.equipmentEdit(equipmentID: $0), in: .equipment) }
                )
            } else {
                guestRoot(title: "装备", description: "管理个人装备与常用清单", message: "登录后管理个人装备与清单", icon: "backpack", intent: .equipment, tab: .equipment)
            }
        }
        .id(authenticationGeneration)
    }

    private func guestRoot(title: String, description: String, message: String, icon: String, intent: PendingAuthIntent, tab: AppTab) -> some View {
        PageShell(title: title, description: description, background: { AppColors.pageBase }) {
            ScrollView(showsIndicators: false) {
                EmptyStateView(
                    title: message,
                    message: "登录后即可继续。",
                    icon: icon,
                    actionTitle: "登录",
                    action: { requestAuthentication(intent, in: tab) }
                )
                .frame(maxWidth: .infinity, minHeight: 440)
                .padding(.horizontal, Spacing.pageHorizontal)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var routesRoot: some View {
        RouteDiscoveryView(
            routeService: appEnvironment.routeService,
            onNavigate: { destination in
                navigate(destination, in: .routes)
            }
        )
        .toolbar(.hidden, for: .navigationBar)
    }

    private var profileRoot: some View {
        ProfileView(
            viewModel: profileModel,
            onNavigate: { navigate($0, in: .profile) },
            onOpenAccountMenu: { shell.presentAccountMenu() },
            onAuthenticate: { requestAuthentication($0, in: .profile) },
            onLoggedOut: handleLoggedOut
        )
        .id(authenticationGeneration)
    }

    private func handleLoggedOut() {
        authFlow.cancel()
        shell.resetAfterLogout()
        synchronizeAuthentication()
    }

    private func synchronizeAuthentication() {
        let identity = appEnvironment.authManager.isLoggedIn ? appEnvironment.authManager.cacheIdentity : nil
        if identity != authenticationIdentity {
            if authenticationIdentity != nil, identity == nil, !profileModel.isLoggingOut {
                shell.suspendSelectedTask()
            } else if authenticationIdentity != nil {
                shell.discardSuspendedTask()
            }
            shell.clearPersonalNavigation()
            tripEquipmentSession.clear()
            authenticationIdentity = identity
            authenticationGeneration += 1
        }
        profileModel.synchronizeAuthentication()
    }

    private func requestAuthentication(
        _ intent: PendingAuthIntent,
        in tab: AppTab,
        force: Bool = false
    ) {
        apply(authFlow.request(
            intent,
            from: tab,
            isLoggedIn: appEnvironment.authManager.isLoggedIn,
            force: force
        ))
    }

    private func completeAuthentication() {
        shell.dismissLogin()
        synchronizeAuthentication()
        apply(authFlow.complete(currentTab: shell.selectedTab))
    }

    private func apply(_ effect: AuthenticationFlow.Effect) {
        switch effect {
        case .none:
            break
        case .presentLogin:
            shell.presentLogin()
        case let .execute(intent, tab):
            execute(intent, in: tab)
        }
    }

    private func execute(_ intent: PendingAuthIntent, in tab: AppTab) {
        switch intent {
        case .trips:
            shell.selectTab(.trips)
        case .equipment:
            shell.selectTab(.equipment)
        case .profile:
            shell.selectTab(.profile)
        case .createTrip(let routeID):
            shell.selectTab(tab)
            navigate(.createTrip(routeID: routeID), in: tab)
        case .reauthenticate:
            shell.resumeSuspendedTask()
        }
    }

    private func navigate(_ destination: AppDestination, in tab: AppTab) {
        var path = shell.path(for: tab)
        guard path.last != destination else { return }
        // PAGE-ROUTE-LIST 从来源页推入，返回恢复来源任务。
        if destination == .routeList { shell.routeListShowsBackEntry = true }
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
                ProfileDetailsView(viewModel: profileModel)
            case .tripList:
                TripListView(
                    service: appEnvironment.personalTripService,
                    onNavigate: { navigate($0, in: shell.selectedTab) },
                    onFindRoute: { navigate(.routeList, in: shell.selectedTab) }
                )
            case let .tripDetail(tripID):
                TripDetailView(
                    tripID: tripID,
                    service: appEnvironment.personalTripService,
                    reloadRevision: shell.reloadRevision(for: tripID),
                    demoScenesEnabled: appEnvironment.configuration.dataMode == .mock,
                    onOpenRoute: { navigate(.routeDetail($0), in: shell.selectedTab) },
                    onOpenEquipment: { navigate(.tripEquipment(tripID), in: shell.selectedTab) },
                    onOpenWeather: {
                        navigate(.tripWeather(tripID), in: shell.selectedTab)
                    },
                    onOpenBrowse: { dayNumber in
                        navigate(.tripBrowse(tripID: tripID, dayNumber: dayNumber), in: shell.selectedTab)
                    }
                )
            case let .tripBrowse(tripID, dayNumber):
                TripBrowseView(
                    tripID: tripID,
                    service: appEnvironment.personalTripService,
                    initialDayNumber: dayNumber
                )
            case let .tripEquipment(tripID):
                TripEquipmentView(
                    viewModel: tripEquipmentSession.model(
                        tripID: tripID,
                        service: appEnvironment.tripEquipmentService,
                        equipmentService: appEnvironment.equipmentService,
                        onRevisionChange: { shell.recordTripRevision($0, tripID: tripID) }
                    ),
                    onManagePersonalEquipment: {
                        navigate(.personalEquipment, in: shell.selectedTab)
                    }
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
