import SwiftUI
import MapKit
import CoreLocation

struct RouteCoordinatesFingerprint: Equatable {
    private struct Coordinate: Equatable {
        let latitude: Double
        let longitude: Double
    }
    private let coordinates: [Coordinate]

    init(coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates.map { Coordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

struct RouteMapUpdateDecision: Equatable {
    let shouldUpdateRoute: Bool
    let shouldFitCamera: Bool
}

enum RouteMapUpdatePolicy {
    static func decision(previousFingerprint: RouteCoordinatesFingerprint?, coordinates: [CLLocationCoordinate2D], userHasInteracted: Bool) -> RouteMapUpdateDecision {
        let changed = RouteCoordinatesFingerprint(coordinates: coordinates) != previousFingerprint
        return .init(shouldUpdateRoute: changed, shouldFitCamera: changed && !userHasInteracted)
    }
}

struct RouteMapCameraFit {
    let mapRect: MKMapRect
    let edgeInsets: UIEdgeInsets
}

enum RouteMapCamera {
    static let standardEdgeInsets = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
    static let detailDrawerHeightRatio = 0.58

    static func fit(coordinates: [CLLocationCoordinate2D], edgeInsets: UIEdgeInsets) -> RouteMapCameraFit? {
        guard coordinates.count >= 2 else { return nil }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        return .init(mapRect: polyline.boundingMapRect, edgeInsets: edgeInsets)
    }

    static func detailEdgeInsets(viewportHeight: CGFloat, safeAreaTop: CGFloat, safeAreaBottom: CGFloat) -> UIEdgeInsets {
        .init(
            top: safeAreaTop + standardEdgeInsets.top,
            left: standardEdgeInsets.left,
            bottom: viewportHeight * detailDrawerHeightRatio + safeAreaBottom + standardEdgeInsets.bottom,
            right: standardEdgeInsets.right
        )
    }
}

struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let poiAnnotations: [RoutePOIAnnotation]
    let trackPointAnnotations: [RouteTrackPointMetadata]
    let waypointAnnotations: [RouteWaypointAnnotation]
    let showsUserLocation: Bool
    let mapType: MKMapType
    let zoomEnabled: Bool
    let rotateEnabled: Bool
    let cameraPitch: CGFloat
    let edgeInsets: UIEdgeInsets
    let onSelectTrackPoint: ((RouteTrackPointMetadata) -> Void)?
    let onSelectWaypoint: ((RouteWaypointAnnotation) -> Void)?

    init(
        coordinates: [CLLocationCoordinate2D] = [],
        poiAnnotations: [RoutePOIAnnotation] = [],
        trackPointAnnotations: [RouteTrackPointMetadata] = [],
        waypointAnnotations: [RouteWaypointAnnotation] = [],
        showsUserLocation: Bool = true,
        mapType: MKMapType = .standard,
        zoomEnabled: Bool = true,
        rotateEnabled: Bool = true,
        cameraPitch: CGFloat = 0,
        edgeInsets: UIEdgeInsets = RouteMapCamera.standardEdgeInsets,
        onSelectTrackPoint: ((RouteTrackPointMetadata) -> Void)? = nil,
        onSelectWaypoint: ((RouteWaypointAnnotation) -> Void)? = nil
    ) {
        self.coordinates = coordinates
        self.poiAnnotations = poiAnnotations
        self.trackPointAnnotations = trackPointAnnotations
        self.waypointAnnotations = waypointAnnotations
        self.showsUserLocation = showsUserLocation
        self.mapType = mapType
        self.zoomEnabled = zoomEnabled
        self.rotateEnabled = rotateEnabled
        self.cameraPitch = cameraPitch
        self.edgeInsets = edgeInsets
        self.onSelectTrackPoint = onSelectTrackPoint
        self.onSelectWaypoint = onSelectWaypoint
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        configure(mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        configure(mapView)
        context.coordinator.onSelectTrackPoint = onSelectTrackPoint
        context.coordinator.onSelectWaypoint = onSelectWaypoint
        let decision = RouteMapUpdatePolicy.decision(
            previousFingerprint: context.coordinator.coordinatesFingerprint,
            coordinates: coordinates,
            userHasInteracted: context.coordinator.userHasInteracted
        )
        let annotationFingerprint = poiAnnotations.map { "poi-\($0.id)" }
            + trackPointAnnotations.map { "track-\($0.id)" }
            + waypointAnnotations.map { "waypoint-\($0.id)" }
        let annotationsChanged = annotationFingerprint != context.coordinator.annotationFingerprint
        guard decision.shouldUpdateRoute || annotationsChanged else { return }

        context.coordinator.coordinatesFingerprint = RouteCoordinatesFingerprint(coordinates: coordinates)
        context.coordinator.annotationFingerprint = annotationFingerprint
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        if coordinates.count >= 2 {
            mapView.addOverlay(MKPolyline(coordinates: coordinates, count: coordinates.count))
            if let start = coordinates.first {
                mapView.addAnnotation(RoutePointAnnotation(coordinate: start, title: "起点", subtitle: nil, type: .start))
            }
            if let end = coordinates.last {
                mapView.addAnnotation(RoutePointAnnotation(coordinate: end, title: "终点", subtitle: nil, type: .end))
            }
        }

        poiAnnotations.forEach {
            mapView.addAnnotation(RoutePointAnnotation(
                coordinate: $0.coordinate,
                title: $0.title,
                subtitle: "类别：\($0.category) · 子类别：\($0.subCategory)\n描述：\($0.detail) · 海拔：\($0.elevation)",
                type: .poi,
                trackPoint: nil
            ))
        }
        trackPointAnnotations.forEach {
            mapView.addAnnotation(RoutePointAnnotation(
                coordinate: $0.coordinate,
                title: $0.title,
                subtitle: $0.type,
                type: .trackPoint,
                trackPoint: $0
            ))
        }
        waypointAnnotations.forEach {
            mapView.addAnnotation(RoutePointAnnotation(
                coordinate: $0.coordinate,
                title: $0.title,
                subtitle: $0.type,
                type: .waypoint,
                waypoint: $0
            ))
        }

        if decision.shouldFitCamera,
           let fit = RouteMapCamera.fit(coordinates: coordinates, edgeInsets: edgeInsets) {
            mapView.setVisibleMapRect(fit.mapRect, edgePadding: fit.edgeInsets, animated: false)
        } else if coordinates.isEmpty,
                  let first = (poiAnnotations.first?.coordinate ?? trackPointAnnotations.first?.coordinate ?? waypointAnnotations.first?.coordinate) {
            mapView.setRegion(.init(center: first, latitudinalMeters: 5_000, longitudinalMeters: 5_000), animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectTrackPoint: onSelectTrackPoint, onSelectWaypoint: onSelectWaypoint)
    }

    private func configure(_ mapView: MKMapView) {
        mapView.mapType = mapType
        mapView.showsUserLocation = showsUserLocation
        mapView.isZoomEnabled = zoomEnabled
        mapView.isRotateEnabled = rotateEnabled
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = cameraPitch > 0
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var coordinatesFingerprint: RouteCoordinatesFingerprint?
        var annotationFingerprint: [String] = []
        var userHasInteracted = false
        var onSelectTrackPoint: ((RouteTrackPointMetadata) -> Void)?
        var onSelectWaypoint: ((RouteWaypointAnnotation) -> Void)?

        init(
            onSelectTrackPoint: ((RouteTrackPointMetadata) -> Void)?,
            onSelectWaypoint: ((RouteWaypointAnnotation) -> Void)?
        ) {
            self.onSelectTrackPoint = onSelectTrackPoint
            self.onSelectWaypoint = onSelectWaypoint
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            for view in [mapView] + mapView.subviews {
                if (view.gestureRecognizers ?? []).contains(where: { $0.state == .began || $0.state == .changed }) {
                    userHasInteracted = true
                    return
                }
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 4
            renderer.alpha = 0.8
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let point = annotation as? RoutePointAnnotation else { return nil }
            let identifier = "RoutePoint"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = true
            view.glyphText = point.type.glyph
            switch point.type {
            case .start: view.markerTintColor = .systemGreen
            case .end: view.markerTintColor = .systemRed
            case .waypoint: view.markerTintColor = .systemPurple
            case .poi: view.markerTintColor = .systemOrange
            case .trackPoint: view.markerTintColor = .systemBlue
            }
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let point = view.annotation as? RoutePointAnnotation else { return }
            if let trackPoint = point.trackPoint { onSelectTrackPoint?(trackPoint) }
            if let waypoint = point.waypoint { onSelectWaypoint?(waypoint) }
        }
    }
}

enum RoutePointType {
    case start, end, waypoint, poi, trackPoint

    var glyph: String {
        switch self {
        case .start: "S"
        case .end: "E"
        case .waypoint: "●"
        case .poi: "P"
        case .trackPoint: "•"
        }
    }
}

final class RoutePointAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let type: RoutePointType
    let trackPoint: RouteTrackPointMetadata?
    let waypoint: RouteWaypointAnnotation?

    init(
        coordinate: CLLocationCoordinate2D,
        title: String?,
        subtitle: String?,
        type: RoutePointType,
        trackPoint: RouteTrackPointMetadata? = nil,
        waypoint: RouteWaypointAnnotation? = nil
    ) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.trackPoint = trackPoint
        self.waypoint = waypoint
        super.init()
    }
}
