import SwiftUI

enum RootDestination: Hashable {
    case routes
    case trips
    case guides
    case equipment
    case profile
    case routeDetail(String)
    case navigation
}

enum DrawerItem: String, CaseIterable, Identifiable {
    case routes
    case trips
    case guides
    case equipment
    case weather
    case calendar
    case statistics
    case navigation
    case nearby

    var id: Self { self }

    var title: String {
        switch self {
        case .routes: "路线"
        case .trips: "我的行程"
        case .guides: "攻略"
        case .equipment: "装备"
        case .weather: "天气"
        case .calendar: "日历"
        case .statistics: "统计"
        case .navigation: "导航"
        case .nearby: "附近"
        }
    }

    var systemImage: String {
        switch self {
        case .routes: "point.topleft.down.curvedto.point.bottomright.up"
        case .trips: "map"
        case .guides: "book.closed"
        case .equipment: "backpack"
        case .weather: "cloud.sun"
        case .calendar: "calendar"
        case .statistics: "chart.bar"
        case .navigation: "location.north.line"
        case .nearby: "mappin.and.ellipse"
        }
    }

    var destination: RootDestination? {
        switch self {
        case .routes: .routes
        case .trips: .trips
        case .guides: .guides
        case .equipment: .equipment
        case .weather, .calendar, .statistics, .navigation, .nearby: nil
        }
    }

    var isAvailable: Bool { destination != nil }
}

enum RootNavigation {
    static let drawerWidth: CGFloat = 280
    static let drawerOverlayOpacity: Double = 0.50
    static let profileDestination: RootDestination = .profile
}

enum DrawerStyle {
    static let backgroundColor = AppColors.bgDrawer
    static let brandSubtitleColor = AppColors.textWeak
    static let brandTitle = "WALK"
    static let brandSubtitle = "徒步旅行助手"
    static let brandSpacing: CGFloat = 6
    static let brandTitleFontSize: CGFloat = 42
    // Flutter FontWeight.w800 has no exact SwiftUI counterpart; .heavy is the closest system weight.
    static let brandTitleFontWeight: Font.Weight = .heavy
    static let columnCount = 3
    static let gridGap: CGFloat = 8
    static let cellAspectRatio: CGFloat = 1
    static let cellBorderWidth: CGFloat = 0.5
}

enum HomeRoutePickerTransition: Equatable {
    case opacity
}

enum HomePresentation {
    static let routePickerTransition: HomeRoutePickerTransition = .opacity
    static let fadeDuration: Double = 0.24
}

enum HomeStyle {
    static let gradientStops: [Gradient.Stop] = [
        .init(color: AppColors.bgBase, location: 0),
        .init(color: AppColors.bgMap, location: 0.4),
        .init(color: AppColors.bgGradientEnd, location: 1)
    ]
    static let gradientStartPoint = UnitPoint(x: 0.25, y: 0)
    static let gradientEndPoint = UnitPoint(x: 0.75, y: 1)
    static let weatherPlaceholder = "天气 --"
}
