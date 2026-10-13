import CoreLocation
import Foundation
import WalkData

/// 一次加载产生的不可变展示快照，路线与投影不可分别替换。
struct RouteDetailSnapshot {
    let route: PublicRouteDetail
    let mapCoordinates: [CLLocationCoordinate2D]
    let mapSegments: [RouteMapSegment]
    let dayMapSegments: [RouteMapSegment]
    let coloredMapSegments: [RouteMapSegment]
    let poiAnnotations: [RoutePOIAnnotation]
    let waypointAnnotations: [RouteWaypointAnnotation]
    let elevationSamples: [RouteElevationSample]
    let elevationProfile: ElevationProfileProjection?
}

struct RouteDetailState {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    var routeID: String?
    var snapshot: RouteDetailSnapshot?
    var route: PublicRouteDetail? { snapshot?.route }
    var phase: Phase = .idle
    var selectedSegmentID: String?
    var highlightedPointIdentity: String?
    var scenes: PublicRouteScenes?
    let sceneRequestID = UUID()

    var isLoading: Bool { phase == .loading }
    var errorMessage: String? {
        guard case .failed(let message) = phase else { return nil }
        return message
    }
}
