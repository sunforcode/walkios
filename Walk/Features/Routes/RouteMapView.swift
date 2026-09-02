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

struct RouteMapAnnotationFingerprint: Equatable {
    private let values: [String]

    init(
        poiAnnotations: [RoutePOIAnnotation],
        trackPoints: [RouteTrackPointMetadata],
        waypoints: [RouteWaypointAnnotation]
    ) {
        values = poiAnnotations.map {
            "poi|\($0.id)|\($0.title)|\($0.category)|\($0.subCategory)|\($0.detail)|\($0.elevation)|\($0.imageURL?.absoluteString ?? "")|\($0.latitude)|\($0.longitude)"
        } + trackPoints.map {
            "track|\($0.id)|\($0.title)|\($0.type)|\($0.detail)|\($0.imageURL?.absoluteString ?? "")|\($0.latitude)|\($0.longitude)"
        } + waypoints.map {
            "waypoint|\($0.id)|\($0.title)|\($0.detail)|\($0.elevation)|\($0.type)|\($0.imageURL?.absoluteString ?? "")|\($0.latitude)|\($0.longitude)"
        }
    }
}

struct RouteMapUpdateDecision: Equatable {
    let shouldUpdateRoute: Bool
    let shouldFitCamera: Bool
}

struct RouteMapInsetsFingerprint: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat

    init(_ insets: UIEdgeInsets) {
        top = insets.top
        left = insets.left
        bottom = insets.bottom
        right = insets.right
    }
}

struct RouteMapOverlayPlan {
    struct Overlay {
        let segmentID: String?
        let colorHex: String?
        let coordinates: [CLLocationCoordinate2D]
    }

    let overlays: [Overlay]
    let usesWholeRoute: Bool

    init(coordinates: [CLLocationCoordinate2D], segments: [RouteMapSegment]) {
        if segments.isEmpty {
            overlays = coordinates.count >= 2
                ? [.init(segmentID: nil, colorHex: nil, coordinates: coordinates)]
                : []
            usesWholeRoute = true
        } else {
            overlays = segments.map {
                .init(segmentID: $0.id, colorHex: $0.colorHex, coordinates: $0.coordinates)
            }
            usesWholeRoute = false
        }
    }
}

struct RouteMapOverlayStyle: Equatable {
    let lineWidth: CGFloat
    let alpha: CGFloat

    static func resolve(segmentID: String?, selectedSegmentID: String?) -> Self {
        guard let selectedSegmentID else { return .init(lineWidth: 4, alpha: 0.8) }
        return segmentID == selectedSegmentID
            ? .init(lineWidth: 7, alpha: 1)
            : .init(lineWidth: 4, alpha: 0.3)
    }
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

    static func detailEdgeInsets(
        viewportHeight: CGFloat,
        safeAreaTop: CGFloat,
        safeAreaBottom: CGFloat,
        drawerHeightRatio: CGFloat = detailDrawerHeightRatio
    ) -> UIEdgeInsets {
        .init(
            top: safeAreaTop + standardEdgeInsets.top,
            left: standardEdgeInsets.left,
            bottom: viewportHeight * drawerHeightRatio + safeAreaBottom + standardEdgeInsets.bottom,
            right: standardEdgeInsets.right
        )
    }

    static func shouldFocusSegment(previousSelection: String?, selection: String?) -> Bool {
        selection != nil && selection != previousSelection
    }

    static func shouldFocusMarker(hasCoordinates: Bool, userHasInteracted: Bool) -> Bool {
        !hasCoordinates && !userHasInteracted
    }
}

struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let segments: [RouteMapSegment]
    let selectedSegmentID: String?
    let poiAnnotations: [RoutePOIAnnotation]
    let trackPointAnnotations: [RouteTrackPointMetadata]
    let waypointAnnotations: [RouteWaypointAnnotation]
    let showsUserLocation: Bool
    let mapType: MKMapType
    let zoomEnabled: Bool
    let rotateEnabled: Bool
    let cameraPitch: CGFloat
    let edgeInsets: UIEdgeInsets
    let onSelectSegment: ((String) -> Void)?
    let onSelectMarker: ((RouteMapSelection) -> Void)?

    init(
        coordinates: [CLLocationCoordinate2D] = [],
        segments: [RouteMapSegment] = [],
        selectedSegmentID: String? = nil,
        poiAnnotations: [RoutePOIAnnotation] = [],
        trackPointAnnotations: [RouteTrackPointMetadata] = [],
        waypointAnnotations: [RouteWaypointAnnotation] = [],
        showsUserLocation: Bool = true,
        mapType: MKMapType = .standard,
        zoomEnabled: Bool = true,
        rotateEnabled: Bool = true,
        cameraPitch: CGFloat = 0,
        edgeInsets: UIEdgeInsets = RouteMapCamera.standardEdgeInsets,
        onSelectSegment: ((String) -> Void)? = nil,
        onSelectMarker: ((RouteMapSelection) -> Void)? = nil
    ) {
        self.coordinates = coordinates
        self.segments = segments
        self.selectedSegmentID = selectedSegmentID
        self.poiAnnotations = poiAnnotations
        self.trackPointAnnotations = trackPointAnnotations
        self.waypointAnnotations = waypointAnnotations
        self.showsUserLocation = showsUserLocation
        self.mapType = mapType
        self.zoomEnabled = zoomEnabled
        self.rotateEnabled = rotateEnabled
        self.cameraPitch = cameraPitch
        self.edgeInsets = edgeInsets
        self.onSelectSegment = onSelectSegment
        self.onSelectMarker = onSelectMarker
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.addGestureRecognizer(UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleMapTap(_:))))
        configure(mapView)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        configure(mapView)
        context.coordinator.onSelectSegment = onSelectSegment
        context.coordinator.onSelectMarker = onSelectMarker
        let decision = RouteMapUpdatePolicy.decision(
            previousFingerprint: context.coordinator.coordinatesFingerprint,
            coordinates: coordinates,
            userHasInteracted: context.coordinator.userHasInteracted
        )
        let annotationFingerprint = RouteMapAnnotationFingerprint(
            poiAnnotations: poiAnnotations,
            trackPoints: trackPointAnnotations,
            waypoints: waypointAnnotations
        )
        let overlayFingerprint = segments.map { segment in
            let points = segment.coordinates.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";")
            return "\(segment.id)-\(segment.colorHex ?? "")-\(points)"
        }
        let annotationsChanged = annotationFingerprint != context.coordinator.annotationFingerprint
        let overlaysChanged = overlayFingerprint != context.coordinator.overlayFingerprint
        let selectionChanged = selectedSegmentID != context.coordinator.selectedSegmentID
        let insetsFingerprint = RouteMapInsetsFingerprint(edgeInsets)
        let insetsChanged = insetsFingerprint != context.coordinator.insetsFingerprint
        guard decision.shouldUpdateRoute || annotationsChanged || overlaysChanged || selectionChanged || insetsChanged else { return }

        let previousSelection = context.coordinator.selectedSegmentID
        context.coordinator.coordinatesFingerprint = RouteCoordinatesFingerprint(coordinates: coordinates)
        context.coordinator.annotationFingerprint = annotationFingerprint
        context.coordinator.overlayFingerprint = overlayFingerprint
        context.coordinator.selectedSegmentID = selectedSegmentID
        context.coordinator.insetsFingerprint = insetsFingerprint
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })

        let overlayPlan = RouteMapOverlayPlan(coordinates: coordinates, segments: segments)
        overlayPlan.overlays.forEach {
            mapView.addOverlay(RouteSegmentPolyline(
                coordinates: $0.coordinates,
                segmentID: $0.segmentID,
                colorHex: $0.colorHex
            ))
        }
        if coordinates.count >= 2 {
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
                selection: .poi($0)
            ))
        }
        trackPointAnnotations.forEach {
            mapView.addAnnotation(RoutePointAnnotation(
                coordinate: $0.coordinate,
                title: $0.title,
                subtitle: $0.type,
                type: .trackPoint,
                selection: .trackPoint($0)
            ))
        }
        waypointAnnotations.forEach {
            mapView.addAnnotation(RoutePointAnnotation(
                coordinate: $0.coordinate,
                title: $0.title,
                subtitle: $0.type,
                type: .waypoint,
                selection: .waypoint($0)
            ))
        }

        if RouteMapCamera.shouldFocusSegment(previousSelection: previousSelection, selection: selectedSegmentID),
           let selected = segments.first(where: { $0.id == selectedSegmentID }),
           let fit = RouteMapCamera.fit(coordinates: selected.coordinates, edgeInsets: edgeInsets) {
            mapView.setVisibleMapRect(fit.mapRect, edgePadding: fit.edgeInsets, animated: true)
        } else if (decision.shouldFitCamera || insetsChanged) && !context.coordinator.userHasInteracted,
                  let fit = RouteMapCamera.fit(coordinates: coordinates, edgeInsets: edgeInsets) {
            mapView.setVisibleMapRect(fit.mapRect, edgePadding: fit.edgeInsets, animated: insetsChanged)
        } else if RouteMapCamera.shouldFocusMarker(
            hasCoordinates: !coordinates.isEmpty,
            userHasInteracted: context.coordinator.userHasInteracted
        ), let first = (poiAnnotations.first?.coordinate ?? trackPointAnnotations.first?.coordinate ?? waypointAnnotations.first?.coordinate) {
            mapView.setRegion(.init(center: first, latitudinalMeters: 5_000, longitudinalMeters: 5_000), animated: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectSegment: onSelectSegment, onSelectMarker: onSelectMarker)
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
        var annotationFingerprint: RouteMapAnnotationFingerprint?
        var overlayFingerprint: [String] = []
        var selectedSegmentID: String?
        var insetsFingerprint: RouteMapInsetsFingerprint?
        var userHasInteracted = false
        var onSelectSegment: ((String) -> Void)?
        var onSelectMarker: ((RouteMapSelection) -> Void)?

        init(
            onSelectSegment: ((String) -> Void)?,
            onSelectMarker: ((RouteMapSelection) -> Void)?
        ) {
            self.onSelectSegment = onSelectSegment
            self.onSelectMarker = onSelectMarker
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
            guard let polyline = overlay as? RouteSegmentPolyline else { return MKOverlayRenderer(overlay: overlay) }
            let renderer = MKPolylineRenderer(polyline: polyline)
            let style = RouteMapOverlayStyle.resolve(segmentID: polyline.segmentID, selectedSegmentID: selectedSegmentID)
            renderer.strokeColor = UIColor(routeHex: polyline.colorHex) ?? UIColor(AppColors.mapRoute)
            renderer.lineWidth = style.lineWidth
            renderer.alpha = style.alpha
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let point = annotation as? RoutePointAnnotation else { return nil }
            let identifier = "RoutePoint"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = false
            view.glyphText = point.type.glyph
            switch point.type {
            case .start: view.markerTintColor = UIColor(AppColors.mapStart)
            case .end: view.markerTintColor = UIColor(AppColors.mapEnd)
            case .waypoint: view.markerTintColor = UIColor(AppColors.mapWaypoint)
            case .poi: view.markerTintColor = UIColor(AppColors.mapPOI)
            case .trackPoint: view.markerTintColor = UIColor(AppColors.mapRoute)
            }
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let point = view.annotation as? RoutePointAnnotation,
                  let selection = point.selection else { return }
            onSelectMarker?(selection)
        }

        @objc func handleMapTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let mapView = recognizer.view as? MKMapView else { return }
            let tapPoint = recognizer.location(in: mapView)
            for overlay in mapView.overlays.reversed() {
                guard let polyline = overlay as? RouteSegmentPolyline,
                      let segmentID = polyline.segmentID,
                      let renderer = mapView.renderer(for: polyline) as? MKPolylineRenderer else { continue }
                let mapPoint = MKMapPoint(mapView.convert(tapPoint, toCoordinateFrom: mapView))
                let rendererPoint = renderer.point(for: mapPoint)
                let hitPath = renderer.path?.copy(strokingWithWidth: max(renderer.lineWidth, 22), lineCap: .round, lineJoin: .round, miterLimit: 0)
                if hitPath?.contains(rendererPoint) == true {
                    onSelectSegment?(segmentID)
                    return
                }
            }
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
    let selection: RouteMapSelection?

    init(
        coordinate: CLLocationCoordinate2D,
        title: String?,
        subtitle: String?,
        type: RoutePointType,
        selection: RouteMapSelection? = nil
    ) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.selection = selection
        super.init()
    }
}

final class RouteSegmentPolyline: MKPolyline {
    private(set) var segmentID: String?
    private(set) var colorHex: String?

    convenience init(coordinates: [CLLocationCoordinate2D], segmentID: String?, colorHex: String?) {
        self.init(coordinates: coordinates, count: coordinates.count)
        self.segmentID = segmentID
        self.colorHex = colorHex
    }
}

private extension UIColor {
    convenience init?(routeHex: String?) {
        guard let routeHex else { return nil }
        let value = routeHex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard value.count == 6, let rgb = UInt64(value, radix: 16) else { return nil }
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
