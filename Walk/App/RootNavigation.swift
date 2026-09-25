import SwiftUI
import WalkData
import WalkDesignSystem

/// 一级导航的三个一级根 Page；系统 tab bar 的 tab 项由该枚举提供标题与图标。
enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case routes
    case profile

    var id: Self { self }

    var title: String {
        switch self {
        case .home: "首页"
        case .routes: "路线"
        case .profile: "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .routes: "map"
        case .profile: "person"
        }
    }
}

struct AppShellState: Equatable {
    var selectedTab: AppTab = .home
    /// PAGE-ROUTE-LIST 的返回入口可见性：由到达方式决定（发现页推入显示，行程清单找路线等任务栈根页到达不显示）。
    var routeListShowsBackEntry = false
    /// PAGE-LOGIN 为 Modal 任务，全屏覆盖呈现，不进入任务栈。
    var isLoginPresented = false
    /// PAGE-ACCOUNT-MENU 为 Modal 任务，以模态 Sheet 呈现，不进入任务栈；设置项由 Modal 内部导航承载。
    var isAccountMenuPresented = false

    private var homePath: [AppDestination] = []
    private var routesPath: [AppDestination] = []
    private var profilePath: [AppDestination] = []
    private var reloadRevisions: [String: String] = [:]

    mutating func showRouteDiscovery() {
        routesPath = []
        routeListShowsBackEntry = false
        selectedTab = .routes
    }

    mutating func showRouteList(showsBackEntry: Bool = false) {
        routesPath = [.routeList]
        routeListShowsBackEntry = showsBackEntry
        selectedTab = .routes
    }

    mutating func selectTab(_ tab: AppTab) {
        selectedTab = tab
    }

    func path(for tab: AppTab) -> [AppDestination] {
        switch tab {
        case .home: homePath
        case .routes: routesPath
        case .profile: profilePath
        }
    }

    var showsGlobalNavigation: Bool {
        path(for: selectedTab).isEmpty
    }

    mutating func setPath(_ path: [AppDestination], for tab: AppTab) {
        switch tab {
        case .home: homePath = path
        case .routes: routesPath = path
        case .profile: profilePath = path
        }
    }

    mutating func presentLogin() {
        isLoginPresented = true
    }

    mutating func dismissLogin() {
        isLoginPresented = false
    }

    mutating func presentAccountMenu() {
        isAccountMenuPresented = true
    }

    mutating func dismissAccountMenu() {
        isAccountMenuPresented = false
    }

    mutating func replaceTop(with destination: AppDestination, in tab: AppTab) {
        var path = path(for: tab)
        if !path.isEmpty { path.removeLast() }
        path.append(destination)
        setPath(path, for: tab)
    }

    mutating func recordTripRevision(_ revision: String, tripID: String) {
        reloadRevisions[tripID] = revision
    }

    func reloadRevision(for tripID: String) -> String? {
        reloadRevisions[tripID]
    }
}

enum RootNavigation {
    static let minimumHitSize = HitTarget.minimum
    static let toolButtonHitSize = minimumHitSize

    // 一级导航由系统 tab bar 承载：不增加独立胶囊；沉浸式场景延伸至系统边缘。
    // 内容在顶部（scrollEdge）时背景透明；内容滚到 bar 下方（standard）时使用系统材质，
    // 由系统在两套外观间播放透明↔材质过渡。只保留 Tab 项的选中/未选文字与图标色。
    static func makeTabBarAppearance() -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()

        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor(AppColors.textWeak)
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textWeak),
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
        ]
        itemAppearance.selected.iconColor = UIColor(AppColors.interactionPrimary)
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.interactionPrimary),
            .font: UIFont.systemFont(ofSize: 10, weight: .bold),
        ]
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        return appearance
    }

    static func applyTabBarAppearance() {
        // window 背景兜底：home indicator 底部安全区不跟随系统外观，
        // 强制深色，避免浅色系统下最底部露出系统白底。
        UIWindow.appearance().backgroundColor = UIColor(AppColors.pageBase)
        // tab bar 两个状态都用显式深色不透明背景，脱离系统外观：
        // .preferredColorScheme(.dark) 只约束 SwiftUI 视图树，UITabBar.appearance()
        // 代理在浅色系统模式下会兜底成系统浅色材质（configureWithTransparentBackground
        // 的"透明"在浅色下仍是浅色模糊），导致真机浅色模式 tab bar 露白。
        let scrollEdge = makeTabBarAppearance()
        scrollEdge.configureWithOpaqueBackground()
        scrollEdge.backgroundColor = UIColor(AppColors.pageBase)
        UITabBar.appearance().scrollEdgeAppearance = scrollEdge

        let standard = makeTabBarAppearance()
        standard.configureWithOpaqueBackground()
        standard.backgroundColor = UIColor(AppColors.pageBase)
        UITabBar.appearance().standardAppearance = standard
    }

    static func makeNavigationBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundEffect = nil
        appearance.backgroundColor = UIColor(AppColors.pageBase)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(AppColors.textPrimary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AppColors.textPrimary)]
        return appearance
    }

    static func applyNavigationBarAppearance() {
        let appearance = makeNavigationBarAppearance()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
