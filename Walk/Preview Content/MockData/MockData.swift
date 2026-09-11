#if DEBUG
import Foundation
import CoreLocation
import WalkData
import WalkDesignSystem

/// 全局 Mock 数据
/// 用于 SwiftUI Preview 和开发联调（无后端时）
enum MockData {
    // MARK: - User

    static let user = User(
        id: "user_001",
        username: "山野行者",
        email: "hiker@example.com",
        avatarUrl: nil,
        createdAt: Date(timeIntervalSince1970: 1700000000)
    )

    // MARK: - Trips

    static let trips: [Trip] = [
        Trip(
            id: "trip_001",
            name: "五台山朝台",
            description: "五台山朝台路线，全程约 50km，分三天完成。途经北台、中台、南台，海拔最高 3058m。",
            status: .inProgress,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()),
            userId: "user_001",
            routeId: "route_001",
            createdAt: Date(timeIntervalSince1970: 1704067200),
            updatedAt: Date()
        ),
        Trip(
            id: "trip_002",
            name: "箭扣长城穿越",
            description: "箭扣长城精华段，从九眼楼到慕田峪，全长约 12km，爬升约 800m。",
            status: .planning,
            startDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()),
            endDate: Calendar.current.date(byAdding: .day, value: 8, to: Date()),
            userId: "user_001",
            routeId: "route_002",
            createdAt: Date(timeIntervalSince1970: 1703980800),
            updatedAt: Date()
        ),
        Trip(
            id: "trip_003",
            name: "海坨山露营",
            description: "海坨山高山草甸露营，观日出日落。",
            status: .completed,
            startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date()),
            endDate: Calendar.current.date(byAdding: .day, value: -28, to: Date()),
            userId: "user_001",
            routeId: "route_003",
            createdAt: Date(timeIntervalSince1970: 1701388800),
            updatedAt: Date(timeIntervalSince1970: 1698796800)
        ),
        Trip(
            id: "trip_004",
            name: "鳌太穿越",
            description: "秦岭鳌太线，中国十大徒步路线之一，全程约 80km。",
            status: .cancelled,
            startDate: nil,
            endDate: nil,
            userId: "user_001",
            routeId: nil,
            createdAt: Date(timeIntervalSince1970: 1698710400),
            updatedAt: Date(timeIntervalSince1970: 1696118400)
        )
    ]

    // MARK: - Routes

    static let routes: [Route] = [
        Route(
            id: "route_001",
            name: "五台山逆穿",
            description: "五台山逆穿路线，从鸿门岩出发，经华北屋脊到狮子窝。经典朝台路线。",
            category: .hiking,
            difficulty: .hard,
            distance: 50.0,
            duration: 3,
            elevation: 1200,
            routeType: "loop",
            coverImageUrl: nil,
            createdAt: Date(timeIntervalSince1970: 1704067200)
        ),
        Route(
            id: "route_002",
            name: "箭扣长城",
            description: "箭扣长城精华段，九眼楼到慕田峪。",
            category: .hiking,
            difficulty: .medium,
            distance: 12.0,
            duration: 1,
            elevation: 800,
            routeType: "point_to_point",
            coverImageUrl: nil,
            createdAt: Date(timeIntervalSince1970: 1703980800)
        ),
        Route(
            id: "route_003",
            name: "海坨山南坡",
            description: "海坨山南坡登顶路线，适合初级登山者。",
            category: .mountain,
            difficulty: .easy,
            distance: 8.0,
            duration: 1,
            elevation: 500,
            routeType: "out_and_back",
            coverImageUrl: nil,
            createdAt: Date(timeIntervalSince1970: 1701388800)
        )
    ]

    // MARK: - Equipment

    static let equipment: [Equipment] = [
        Equipment(id: "eq_001", name: "冲锋衣", category: .clothing, weight: 450, quantity: 1, isChecked: true, description: "防风防水", createdAt: nil),
        Equipment(id: "eq_002", name: "抓绒衣", category: .clothing, weight: 300, quantity: 1, isChecked: true, description: "保暖层", createdAt: nil),
        Equipment(id: "eq_003", name: "速干裤", category: .clothing, weight: 200, quantity: 2, isChecked: false, description: "徒步裤", createdAt: nil),
        Equipment(id: "eq_004", name: "登山鞋", category: .footwear, weight: 800, quantity: 1, isChecked: true, description: "高帮防水", createdAt: nil),
        Equipment(id: "eq_005", name: "登山杖", category: .navigation, weight: 250, quantity: 2, isChecked: true, description: "碳纤维", createdAt: nil),
        Equipment(id: "eq_006", name: "帐篷", category: .shelter, weight: 2000, quantity: 1, isChecked: false, description: "双人三季帐", createdAt: nil),
        Equipment(id: "eq_007", name: "睡袋", category: .shelter, weight: 1200, quantity: 1, isChecked: false, description: "羽绒 -5°C", createdAt: nil),
        Equipment(id: "eq_008", name: "炉头", category: .cooking, weight: 80, quantity: 1, isChecked: true, description: "分体式", createdAt: nil),
        Equipment(id: "eq_009", name: "气罐", category: .cooking, weight: 400, quantity: 2, isChecked: true, description: "230g", createdAt: nil),
        Equipment(id: "eq_010", name: "急救包", category: .safety, weight: 200, quantity: 1, isChecked: true, description: "基础急救", createdAt: nil),
        Equipment(id: "eq_011", name: "头灯", category: .electronics, weight: 80, quantity: 1, isChecked: true, description: "充电式", createdAt: nil),
        Equipment(id: "eq_012", name: "充电宝", category: .electronics, weight: 300, quantity: 1, isChecked: false, description: "20000mAh", createdAt: nil)
    ]

    static let equipmentChecklist = EquipmentChecklist(
        tripId: "trip_001",
        items: equipment,
        createdAt: Date(),
        updatedAt: Date()
    )

    // MARK: - Coordinates

    static let wutaiShanCoordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 39.0580, longitude: 113.5760), // 鸿门岩起点
        CLLocationCoordinate2D(latitude: 39.0650, longitude: 113.5850),
        CLLocationCoordinate2D(latitude: 39.0700, longitude: 113.5950),
        CLLocationCoordinate2D(latitude: 39.0680, longitude: 113.6050),
        CLLocationCoordinate2D(latitude: 39.0600, longitude: 113.6100), // 北台
        CLLocationCoordinate2D(latitude: 39.0520, longitude: 113.6150),
        CLLocationCoordinate2D(latitude: 39.0450, longitude: 113.6200), // 中台
        CLLocationCoordinate2D(latitude: 39.0380, longitude: 113.6250),
        CLLocationCoordinate2D(latitude: 39.0300, longitude: 113.6300), // 南台
    ]
}
#endif
