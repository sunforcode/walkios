import SwiftUI
import WalkData
import WalkDesignSystem

enum PendingAuthIntent: Equatable {
    case homeStart
    case profile
    case createTrip(routeID: String)
    case reauthenticate
}

enum AppDestination: Hashable {
    case login
    case routeList
    case routeSearch
    case routeDetail(String)
    case profileDetails
    case accountSecurity
    case notificationSettings
    case privacySettings
    case helpAndFeedback
    case about
    case tripList
    case createTrip(routeID: String)
    case tripDetail(String)
    case tripEquipment(String)
    case personalEquipment
    case equipmentEdit(equipmentID: String?)
    case tripDay(tripID: String, initialDayID: String)
    case tripWeather(String)

    var pageID: String {
        switch self {
        case .login: "PAGE-LOGIN"
        case .routeList: "PAGE-ROUTE-LIST"
        case .routeSearch: "PAGE-SEARCH"
        case .routeDetail: "PAGE-ROUTE-DETAIL"
        case .profileDetails, .accountSecurity, .notificationSettings, .privacySettings,
             .helpAndFeedback, .about: "PAGE-ME"
        case .tripList: "PAGE-TRIPS"
        case .createTrip: "PAGE-TRIP-CREATE"
        case .tripDetail: "PAGE-TRIP-DETAIL"
        case .tripEquipment: "PAGE-TRIP-EQUIPMENT"
        case .personalEquipment: "PAGE-MY-EQUIPMENT"
        case .equipmentEdit: "PAGE-EQUIPMENT-EDIT"
        case .tripDay: "PAGE-TRIP-DAY"
        case .tripWeather: "PAGE-TRIP-WEATHER"
        }
    }
}

enum EntryPageContract {
    static let profileFields = ["昵称", "脱敏手机号", "头像"]
    static let notificationOptions = ["通知总开关", "行程提醒", "天气提醒"]
    static let privacyOptions = ["资料可见性", "位置共享", "匿名分析"]
    static let feedbackFields = ["反馈分类", "反馈内容"]
    static let tripFields = ["出发城市", "开始日期", "装备清单（可选）"]
    static let equipmentFields = ["名称", "拥有数量", "单件克重（可选）"]
}

struct AppShellState: Equatable {
    var selectedTab: AppTab = .home

    private var homePath: [AppDestination] = []
    private var routesPath: [AppDestination] = []
    private var profilePath: [AppDestination] = []
    private var reloadRevisions: [String: String] = [:]

    mutating func showRouteDiscovery() {
        routesPath = []
        selectedTab = .routes
    }

    mutating func showRouteList() {
        routesPath = [.routeList]
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

    var showsPrimaryTabBar: Bool {
        path(for: selectedTab).isEmpty
    }

    mutating func setPath(_ path: [AppDestination], for tab: AppTab) {
        switch tab {
        case .home: homePath = path
        case .routes: routesPath = path
        case .profile: profilePath = path
        }
    }

    mutating func presentLogin(in tab: AppTab) {
        var path = path(for: tab)
        if path.last != .login { path.append(.login) }
        setPath(path, for: tab)
    }

    mutating func dismissLogin(in tab: AppTab) {
        var path = path(for: tab)
        if path.last == .login { path.removeLast() }
        setPath(path, for: tab)
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
    static let minimumHitSize: CGFloat = 44
    static let toolButtonHitSize = minimumHitSize

    // PrimaryTabBar 规范：不增加独立胶囊；沉浸式场景延伸至系统边缘。
    // 保持 tabBar 背景透明，只保留 Tab 项的选中/未选文字与图标色。
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
        let appearance = makeTabBarAppearance()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isHidden = true
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

enum HomeStyle {
    static let gradientStops: [Gradient.Stop] = [
        .init(color: AppColors.sceneForestHighlight, location: 0),
        .init(color: AppColors.sceneForestMiddle, location: 0.46),
        .init(color: AppColors.pageBase, location: 1),
    ]
    static let gradientStartPoint = UnitPoint(x: 0, y: 0)
    static let gradientEndPoint = UnitPoint(x: 1, y: 1)
    static let weatherPlaceholder = "天气摘要暂不可用"
}
