import SwiftUI
import CoreLocation
import WalkDesignSystem
import OutdoorMap

enum RouteMapPointCategory: Equatable {
    case keyPoint
    case interest
    case camp
    case overnight
    case water
    case supply

    var glyph: String {
        switch self {
        case .keyPoint: "关"
        case .interest: "景"
        case .camp: "营"
        case .overnight: "宿"
        case .water: "水"
        case .supply: "补"
        }
    }

    var color: Color {
        switch self {
        // 与生产地图 RouteMapView 使用同一组类别 Token（add-map-point-category-tokens）。
        case .keyPoint: AppColors.mapKeyPoint
        case .interest: AppColors.mapInterest
        case .camp: AppColors.mapCamp
        case .overnight: AppColors.mapOvernight
        case .water: AppColors.mapWater
        case .supply: AppColors.mapSupply
        }
    }
}


#if DEBUG
/// Supplies explicit synthetic geographic input to the same production map used by the detail page.
struct RouteMapComponentExperience: View {
    @Environment(\.routeMapAccessAvailable) private var mapAccessAvailable
    @State private var selectedPointID: String?

    private let coordinates = [
        CLLocationCoordinate2D(latitude: 45.925, longitude: 6.925),
        CLLocationCoordinate2D(latitude: 45.920, longitude: 6.932),
        CLLocationCoordinate2D(latitude: 45.913, longitude: 6.941),
        CLLocationCoordinate2D(latitude: 45.906, longitude: 6.950)
    ]

    private var points: [RoutePOIAnnotation] {
        [
            .init(id: "sample-camp", objectIdentity: "sample-camp", title: "合成营地",
                  category: "营地", subCategory: "", detail: "独立地图展示样例", elevation: "", imageURL: nil,
                  latitude: coordinates[1].latitude, longitude: coordinates[1].longitude),
            .init(id: "sample-water", objectIdentity: "sample-water", title: "合成水源",
                  category: "水源", subCategory: "", detail: "独立地图展示样例", elevation: "", imageURL: nil,
                  latitude: coordinates[2].latitude, longitude: coordinates[2].longitude)
        ]
    }

    var body: some View {
        RouteMapView(
            coordinates: coordinates,
            poiAnnotations: points,
            highlightedAnnotationIDs: selectedPointID.map { [$0] } ?? [],
            showsUserLocation: false,
            displayOptions: .init(showsTerrain: true),
            isMapAvailable: mapAccessAvailable,
            onSelectMarker: { selectedPointID = $0.annotationID }
        )
        .overlay(alignment: .topLeading) {
            Text("真实底图 · 合成轨迹与点位")
                .font(.micro).foregroundStyle(AppColors.textPrimary)
                .padding(Spacing.sm)
                .background(AppColors.surfaceControlOverlay, in: Capsule())
                .padding(Spacing.md)
        }
        .overlay {
            if !mapAccessAvailable { NoticeView(message: "地图暂不可用，请检查开发访问配置。") }
        }
    }
}

#Preview("RouteMap · 生产实现") {
    RouteMapComponentExperience()
}
#endif
