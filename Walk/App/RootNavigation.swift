import SwiftUI

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

    static func makeTabBarAppearance() -> UITabBarAppearance {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = nil
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        return appearance
    }

    static func applyTabBarAppearance() {
        let appearance = makeTabBarAppearance()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
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
        .init(color: AppColors.pageBase, location: 0),
        .init(color: AppColors.pageMiddle, location: 0.4),
        .init(color: AppColors.pageOuter, location: 1)
    ]
    static let gradientStartPoint = UnitPoint(x: 0.25, y: 0)
    static let gradientEndPoint = UnitPoint(x: 0.75, y: 1)
    static let weatherPlaceholder = "天气 --"
}
