import SwiftUI
import WalkData
import WalkDesignSystem

struct RootView: View {
    @ObservedObject private var appEnvironment: AppEnvironment
    @State private var shell = AppShellState()
    /// 认证编排：待处理意图、来源 tab 与焦点行程确认结果（account-access / app-flow）。
    @State private var authFlow = AuthenticationFlow()
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
            authSession: appEnvironment.authManager,
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
            onConfirmFocusTrip: authFlow.pending?.intent == .homeStart
                ? { [appEnvironment] in
                    try await appEnvironment.personalTripService.focus().trip != nil
                }
                : nil,
            onConfirmedFocusTrip: { authFlow.recordFocusConfirmation($0) },
            onAuthenticated: completeAuthentication,
            onCancel: { authFlow.cancel() }
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

    private var homeRoot: some View {
        HomeView(
            onAuthenticate: { requestAuthentication($0, in: .home) },
            onNavigate: { navigate($0, in: .home) },
            service: appEnvironment.personalTripService,
            authSession: appEnvironment.authManager
        )
        .id(authenticationGeneration)
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
        shell.dismissAccountMenu()
        shell.showRouteDiscovery()
        authenticationGeneration += 1
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
        authenticationGeneration += 1
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
        case .homeStart:
            // account-access：焦点行程结果由认证链路确认（confirmingFocus/focusError），
            // 无法确认时不会走到这里；此处只消费已确认结果，不再自行 catch 落回首页。
            // 无焦点行程同样回到首页空态，不自动进入全部路线（app-flow）。
            guard authFlow.consumeFocusConfirmation() else { return }
            shell.setPath([], for: .home)
            shell.selectTab(.home)
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
        // PAGE-ROUTE-LIST 经任意页推入均为普通任务：显示返回入口；
        // 任务栈根页到达（行程清单找路线）走 showRouteList，不经过此处。
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
