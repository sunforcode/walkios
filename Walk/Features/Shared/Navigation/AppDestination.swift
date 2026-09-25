import SwiftUI
import WalkData
import WalkDesignSystem

// 跨域导航合同。
//
// 依据 specs/README.md R-DEP：导航意图放在明确的共享合同位置，Feature 通过它向 App 表达
// 「去哪里」「需要什么认证」，不引用 App 根实现；任务栈与呈现方式仍由 App 决定。

enum PendingAuthIntent: Equatable {
    case homeStart
    case profile
    case createTrip(routeID: String)
    case reauthenticate
}

enum AppDestination: Hashable {
    case routeList
    case routeSearch
    case routeDetail(String)
    case profileDetails
    case notificationSettings
    case privacySettings
    case helpAndFeedback
    case about
    case tripList
    case createTrip(routeID: String)
    case tripDetail(String)
    case tripBrowse(tripID: String, dayNumber: Int)
    case tripEquipment(String)
    case personalEquipment
    case equipmentEdit(equipmentID: String?)
    case tripWeather(String)

    var pageID: String {
        switch self {
        case .routeList: "PAGE-ROUTE-LIST"
        case .routeSearch: "PAGE-SEARCH"
        case .routeDetail: "PAGE-ROUTE-DETAIL"
        case .profileDetails, .notificationSettings, .privacySettings,
             .helpAndFeedback, .about: "PAGE-ME"
        case .tripList: "PAGE-TRIPS"
        case .createTrip: "PAGE-TRIP-CREATE"
        case .tripDetail: "PAGE-TRIP-DETAIL"
        case .tripBrowse: "PAGE-TRIP-BROWSE"
        case .tripEquipment: "PAGE-TRIP-EQUIPMENT"
        case .personalEquipment: "PAGE-MY-EQUIPMENT"
        case .equipmentEdit: "PAGE-EQUIPMENT-EDIT"
        case .tripWeather: "PAGE-TRIP-WEATHER"
        }
    }
}
