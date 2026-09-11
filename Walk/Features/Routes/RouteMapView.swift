import SwiftUI
import MapKit
import CoreLocation
import WalkData
import WalkDesignSystem

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
        let mappedSegments = segments.compactMap { segment -> Overlay? in
            guard segment.coordinates.count >= 2 else { return nil }
            return .init(
                segmentID: segment.id,
                colorHex: segment.colorHex,
                coordinates: segment.coordinates
            )
        }
        if mappedSegments.isEmpty {
            overlays = coordinates.count >= 2
                ? [.init(segmentID: nil, colorHex: nil, coordinates: coordinates)]
                : []
            usesWholeRoute = true
        } else {
            overlays = mappedSegments
            usesWholeRoute = false
        }
    }
}

struct RouteMapOverlayStyle: Equatable {
    let lineWidth: CGFloat
    let alpha: CGFloat

    static func resolve(segmentID: String?, selectedSegmentID: String?) -> Self {
        guard let selectedSegmentID else { return .init(lineWidth: 5, alpha: 1) }
        return segmentID == selectedSegmentID
            ? .init(lineWidth: 5, alpha: 1)
            : .init(lineWidth: 5, alpha: 0.2)
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
    static let detailDrawerHeightRatio: CGFloat = 0.58
    static let detailMapRevealHeight: CGFloat = 330

    static func fit(coordinates: [CLLocationCoordinate2D], edgeInsets: UIEdgeInsets) -> RouteMapCameraFit? {
        guard coordinates.count >= 2 else { return nil }
        let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
        return .init(mapRect: polyline.boundingMapRect, edgeInsets: edgeInsets)
    }

    static func detailEdgeInsets(
        viewportHeight: CGFloat,
        drawerHeightRatio: CGFloat = detailDrawerHeightRatio
    ) -> UIEdgeInsets {
        .init(
            top: standardEdgeInsets.top,
            left: standardEdgeInsets.left,
            bottom: viewportHeight * drawerHeightRatio + standardEdgeInsets.bottom,
            right: standardEdgeInsets.right
        )
    }

    static func detailEdgeInsets(
        viewportHeight: CGFloat,
        mapRevealHeight: CGFloat
    ) -> UIEdgeInsets {
        .init(
            top: standardEdgeInsets.top,
            left: standardEdgeInsets.left,
            bottom: max(standardEdgeInsets.bottom, viewportHeight - mapRevealHeight + standardEdgeInsets.bottom),
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
    let highlightedAnnotationIDs: Set<String>
    let startCoordinate: CLLocationCoordinate2D?
    let endCoordinate: CLLocationCoordinate2D?
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
        highlightedAnnotationIDs: Set<String> = [],
        startCoordinate: CLLocationCoordinate2D? = nil,
        endCoordinate: CLLocationCoordinate2D? = nil,
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
        self.highlightedAnnotationIDs = highlightedAnnotationIDs
        self.startCoordinate = startCoordinate
        self.endCoordinate = endCoordinate
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
        let terminalFingerprint = [startCoordinate, endCoordinate].compactMap {
            $0.map { "\($0.latitude),\($0.longitude)" }
        }
        let overlayFingerprint = (segments.isEmpty
            ? coordinates.map { "\($0.latitude),\($0.longitude)" }
            : segments.map { segment in
                let points = segment.coordinates.map { "\($0.latitude),\($0.longitude)" }.joined(separator: ";")
                return "\(segment.id)-\(segment.colorHex ?? "")-\(points)"
            }) + terminalFingerprint
        let annotationsChanged = annotationFingerprint != context.coordinator.annotationFingerprint
        let overlaysChanged = overlayFingerprint != context.coordinator.overlayFingerprint
        let selectionChanged = selectedSegmentID != context.coordinator.selectedSegmentID
        let insetsFingerprint = RouteMapInsetsFingerprint(edgeInsets)
        let insetsChanged = insetsFingerprint != context.coordinator.insetsFingerprint
        let previousHighlightedAnnotationIDs = context.coordinator.highlightedAnnotationIDs
        let highlightChanged = highlightedAnnotationIDs != previousHighlightedAnnotationIDs
        guard decision.shouldUpdateRoute || annotationsChanged || overlaysChanged || selectionChanged || insetsChanged || highlightChanged else { return }

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
            mapView.addOverlay(RouteSegmentOutlinePolyline(
                coordinates: $0.coordinates,
                segmentID: $0.segmentID
            ))
            mapView.addOverlay(RouteSegmentPolyline(
                coordinates: $0.coordinates,
                segmentID: $0.segmentID,
                colorHex: $0.colorHex
            ))
        }
        if let start = startCoordinate ?? coordinates.first {
            mapView.addAnnotation(RoutePointAnnotation(coordinate: start, title: "起点", subtitle: nil, type: .start))
        }
        if let end = endCoordinate ?? coordinates.last {
            mapView.addAnnotation(RoutePointAnnotation(coordinate: end, title: "终点", subtitle: nil, type: .end))
        }

        poiAnnotations.forEach {
            mapView.addAnnotation(RoutePointAnnotation(
                coordinate: $0.coordinate,
                title: $0.title,
                subtitle: "类别：\($0.category) · 子类别：\($0.subCategory)\n描述：\($0.detail) · 海拔：\($0.elevation)",
                type: pointType(for: $0.category),
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
        } else if coordinates.isEmpty,
                  !context.coordinator.userHasInteracted {
            let fallbackCoordinates = [startCoordinate, endCoordinate].compactMap { $0 }
                + poiAnnotations.map(\.coordinate)
                + trackPointAnnotations.map(\.coordinate)
                + waypointAnnotations.map(\.coordinate)
            if let fit = RouteMapCamera.fit(coordinates: fallbackCoordinates, edgeInsets: edgeInsets) {
                mapView.setVisibleMapRect(fit.mapRect, edgePadding: fit.edgeInsets, animated: false)
            } else if let first = fallbackCoordinates.first {
                mapView.setRegion(.init(center: first, latitudinalMeters: 5_000, longitudinalMeters: 5_000), animated: false)
            }
        }

        context.coordinator.highlightedAnnotationIDs = highlightedAnnotationIDs
        context.coordinator.refreshHighlightStates(mapView: mapView)
        if highlightChanged && !highlightedAnnotationIDs.isEmpty {
            context.coordinator.focusHighlightedAnnotations(
                mapView: mapView,
                edgeInsets: edgeInsets,
                poiAnnotations: poiAnnotations,
                trackPoints: trackPointAnnotations,
                waypoints: waypointAnnotations
            )
        } else if highlightChanged,
                  !previousHighlightedAnnotationIDs.isEmpty,
                  !context.coordinator.userHasInteracted,
                  let fit = RouteMapCamera.fit(coordinates: coordinates, edgeInsets: edgeInsets) {
            mapView.setVisibleMapRect(fit.mapRect, edgePadding: fit.edgeInsets, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelectSegment: onSelectSegment, onSelectMarker: onSelectMarker)
    }

    private func configure(_ mapView: MKMapView) {
        mapView.mapType = mapType
        mapView.overrideUserInterfaceStyle = .dark
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.showsUserLocation = showsUserLocation
        mapView.isZoomEnabled = zoomEnabled
        mapView.isRotateEnabled = rotateEnabled
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = cameraPitch > 0
    }

    private func pointType(for category: String) -> RoutePointType {
        if category.contains("营地") { return .camp }
        if category.contains("过夜") || category.contains("住宿") { return .overnight }
        if category.contains("水") { return .water }
        if category.contains("补给") { return .supply }
        if category.contains("兴趣") || category.contains("景") { return .interest }
        return .poi
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var coordinatesFingerprint: RouteCoordinatesFingerprint?
        var annotationFingerprint: RouteMapAnnotationFingerprint?
        var overlayFingerprint: [String] = []
        var selectedSegmentID: String?
        var insetsFingerprint: RouteMapInsetsFingerprint?
        var highlightedAnnotationIDs: Set<String> = []
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
            if let outline = overlay as? RouteSegmentOutlinePolyline {
                let renderer = MKPolylineRenderer(polyline: outline)
                let style = RouteMapOverlayStyle.resolve(
                    segmentID: outline.segmentID,
                    selectedSegmentID: selectedSegmentID
                )
                renderer.strokeColor = UIColor(AppColors.pageBase)
                renderer.lineWidth = 11
                renderer.alpha = style.alpha
                return renderer
            }
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
            applyMarkerStyle(
                to: view,
                point: point,
                isHighlighted: point.selection.map { highlightedAnnotationIDs.contains($0.annotationID) } == true
            )
            return view
        }

        func refreshHighlightStates(mapView: MKMapView) {
            for annotation in mapView.annotations {
                guard let point = annotation as? RoutePointAnnotation,
                      let selection = point.selection,
                      let view = mapView.view(for: annotation) as? MKMarkerAnnotationView else { continue }
                applyMarkerStyle(
                    to: view,
                    point: point,
                    isHighlighted: highlightedAnnotationIDs.contains(selection.annotationID)
                )
            }
        }

        private func applyMarkerStyle(
            to view: MKMarkerAnnotationView,
            point: RoutePointAnnotation,
            isHighlighted: Bool
        ) {
            view.glyphText = point.type.glyph
            view.glyphTintColor = isHighlighted ? UIColor(AppColors.pageBase) : .white
            view.markerTintColor = markerColor(for: point.type, isHighlighted: isHighlighted)
            view.displayPriority = isHighlighted ? .required : .defaultHigh
            view.transform = isHighlighted ? CGAffineTransform(scaleX: 1.34, y: 1.34) : .identity
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = isHighlighted ? 0.48 : 0.32
            view.layer.shadowRadius = isHighlighted ? 11 : 7
            view.layer.shadowOffset = CGSize(width: 0, height: isHighlighted ? 8 : 5)
        }

        func focusHighlightedAnnotations(
            mapView: MKMapView,
            edgeInsets: UIEdgeInsets,
            poiAnnotations: [RoutePOIAnnotation],
            trackPoints: [RouteTrackPointMetadata],
            waypoints: [RouteWaypointAnnotation]
        ) {
            let highlightedIDs = highlightedAnnotationIDs
            let coordinates = (
                poiAnnotations.map { ($0.id, $0.coordinate) }
                    + trackPoints.map { ($0.id, $0.coordinate) }
                    + waypoints.map { ($0.id, $0.coordinate) }
            )
            .filter { highlightedIDs.contains($0.0) }
            .map(\.1)
            guard !coordinates.isEmpty else { return }
            if coordinates.count == 1 {
                mapView.setRegion(
                    .init(center: coordinates[0], latitudinalMeters: 2_000, longitudinalMeters: 2_000),
                    animated: true
                )
            } else if let fit = RouteMapCamera.fit(coordinates: coordinates, edgeInsets: edgeInsets) {
                mapView.setVisibleMapRect(fit.mapRect, edgePadding: fit.edgeInsets, animated: true)
            }
        }

        private func markerColor(for type: RoutePointType, isHighlighted: Bool) -> UIColor {
            if isHighlighted { return UIColor(AppColors.interactionPrimary) }
            switch type {
            case .start: return UIColor(AppColors.mapStart)
            case .end: return UIColor(AppColors.mapEnd)
            case .waypoint: return UIColor(red: 161 / 255, green: 98 / 255, blue: 7 / 255, alpha: 1)
            case .interest: return UIColor(red: 37 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1)
            case .camp: return UIColor(red: 124 / 255, green: 58 / 255, blue: 237 / 255, alpha: 1)
            case .overnight: return UIColor(red: 109 / 255, green: 40 / 255, blue: 217 / 255, alpha: 1)
            case .water: return UIColor(red: 8 / 255, green: 145 / 255, blue: 178 / 255, alpha: 1)
            case .supply: return UIColor(red: 194 / 255, green: 65 / 255, blue: 12 / 255, alpha: 1)
            case .poi: return UIColor(AppColors.mapPOI)
            case .trackPoint: return UIColor(AppColors.mapRoute)
            }
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let point = view.annotation as? RoutePointAnnotation,
                  let selection = point.selection else { return }
            highlightedAnnotationIDs = Set(
                mapView.annotations.compactMap { annotation in
                    guard let candidate = annotation as? RoutePointAnnotation,
                          let candidateSelection = candidate.selection,
                          candidateSelection.identity == selection.identity else { return nil }
                    return candidateSelection.annotationID
                }
            )
            refreshHighlightStates(mapView: mapView)
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
    case start, end, waypoint, interest, camp, overnight, water, supply, poi, trackPoint

    var glyph: String {
        switch self {
        case .start: "起"
        case .end: "终"
        case .waypoint: "关"
        case .interest: "景"
        case .camp: "营"
        case .overnight: "宿"
        case .water: "水"
        case .supply: "补"
        case .poi: "点"
        case .trackPoint: "点"
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

final class RouteSegmentOutlinePolyline: MKPolyline {
    private(set) var segmentID: String?

    convenience init(coordinates: [CLLocationCoordinate2D], segmentID: String?) {
        self.init(coordinates: coordinates, count: coordinates.count)
        self.segmentID = segmentID
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
