import SwiftUI
import MapKit
import CoreLocation
import WalkData
import WalkDesignSystem
import MapComponentCore
import OutdoorMap

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

    init(
        coordinates: [CLLocationCoordinate2D],
        segments: [RouteMapSegment],
        baseCoordinates: [CLLocationCoordinate2D] = []
    ) {
        let mappedSegments = segments.compactMap { segment -> Overlay? in
            guard segment.coordinates.count >= 2 else { return nil }
            return .init(
                segmentID: segment.id,
                colorHex: segment.colorHex,
                coordinates: segment.coordinates
            )
        }
        // 划分着色时先铺主轨迹底色，再叠加划分色区段；未划分的轨迹段保留底色。
        let baseOverlay: [Overlay] = baseCoordinates.count >= 2
            ? [.init(segmentID: nil, colorHex: nil, coordinates: baseCoordinates)]
            : []
        if mappedSegments.isEmpty && baseOverlay.isEmpty {
            overlays = coordinates.count >= 2
                ? [.init(segmentID: nil, colorHex: nil, coordinates: coordinates)]
                : []
            usesWholeRoute = true
        } else {
            overlays = baseOverlay + mappedSegments
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

    /// 纯地图状态：地图占满内容区，为底部 dock 预留避让。
    static func pureMapEdgeInsets(bottomDockHeight: CGFloat) -> UIEdgeInsets {
        .init(
            top: standardEdgeInsets.top,
            left: standardEdgeInsets.left,
            bottom: max(standardEdgeInsets.bottom, bottomDockHeight + standardEdgeInsets.bottom),
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

/// Business adapter over the shared production map; no SDK renderer lives here.
struct RouteMapView: UIViewControllerRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    let segments: [RouteMapSegment]
    let baseCoordinates: [CLLocationCoordinate2D]
    let selectedSegmentID: String?
    let divisionBadges: [RouteDivisionBadgeProjection]
    let scrubCoordinate: CLLocationCoordinate2D?
    let recenterRequest: Int
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
    let displayOptions: MapDisplayOptions?
    let isMapAvailable: Bool
    let onSelectSegment: ((String) -> Void)?
    let onSelectMarker: ((RouteMapSelection) -> Void)?
    let onSelectSpan: ((String) -> Void)?
    let onMapEvent: ((OutdoorMapEvent) -> Void)?

    init(
        coordinates: [CLLocationCoordinate2D] = [],
        segments: [RouteMapSegment] = [],
        baseCoordinates: [CLLocationCoordinate2D] = [],
        selectedSegmentID: String? = nil,
        divisionBadges: [RouteDivisionBadgeProjection] = [],
        scrubCoordinate: CLLocationCoordinate2D? = nil,
        recenterRequest: Int = 0,
        poiAnnotations: [RoutePOIAnnotation] = [],
        trackPointAnnotations: [RouteTrackPointMetadata] = [],
        waypointAnnotations: [RouteWaypointAnnotation] = [],
        highlightedAnnotationIDs: Set<String> = [],
        startCoordinate: CLLocationCoordinate2D? = nil,
        endCoordinate: CLLocationCoordinate2D? = nil,
        showsUserLocation: Bool = false,
        mapType: MKMapType = .standard,
        zoomEnabled: Bool = true,
        rotateEnabled: Bool = true,
        cameraPitch: CGFloat = 0,
        edgeInsets: UIEdgeInsets = RouteMapCamera.standardEdgeInsets,
        displayOptions: MapDisplayOptions? = nil,
        isMapAvailable: Bool = false,
        onSelectSegment: ((String) -> Void)? = nil,
        onSelectMarker: ((RouteMapSelection) -> Void)? = nil,
        onSelectSpan: ((String) -> Void)? = nil,
        onMapEvent: ((OutdoorMapEvent) -> Void)? = nil
    ) {
        self.coordinates = coordinates
        self.segments = segments
        self.baseCoordinates = baseCoordinates
        self.selectedSegmentID = selectedSegmentID
        self.divisionBadges = divisionBadges
        self.scrubCoordinate = scrubCoordinate
        self.recenterRequest = recenterRequest
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
        self.displayOptions = displayOptions
        self.isMapAvailable = isMapAvailable
        self.onSelectSegment = onSelectSegment
        self.onSelectMarker = onSelectMarker
        self.onSelectSpan = onSelectSpan
        self.onMapEvent = onMapEvent
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIHostingController<AnyView> {
        let controller = UIHostingController(rootView: AnyView(AppColors.pageBase.opacity(0)))
        controller.safeAreaRegions = []
        controller.view.backgroundColor = UIColor(AppColors.pageBase)
        context.coordinator.update(self, controller: controller)
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<AnyView>, context: Context) {
        context.coordinator.update(self, controller: controller)
    }

    private var resolvedOptions: MapDisplayOptions {
        displayOptions ?? MapDisplayOptions(
            baseMap: mapType == .satellite || mapType == .hybrid ? .satellite : .topographic,
            showsTerrain: cameraPitch > 0
        )
    }

    final class Coordinator {
        private var parent: RouteMapView?
        private var source: RouteMapSourceFingerprint?
        private var adapter: RouteMapSceneAdapter?
        private var renderedScene: MapScene?
        private var renderedSegmentID: String?
        private var accessWasAvailable: Bool?
        private var camera = RouteMapCameraDriver()

        func update(_ parent: RouteMapView, controller: UIHostingController<AnyView>) {
            self.parent = parent
            // App supplies availability after configuring access once. An unavailable
            // surface never creates MapView, whose SDK requires a nonempty token.
            guard parent.isMapAvailable else {
                controller.rootView = AnyView(AppColors.pageBase.opacity(0))
                if accessWasAvailable != false {
                    DispatchQueue.main.async { [weak self] in self?.parent?.onMapEvent?(.failed("地图访问配置未就绪。")) }
                }
                accessWasAvailable = false
                return
            }
            accessWasAvailable = true
            let fingerprint = RouteMapSourceFingerprint(parent)
            let sourceChanged = source != fingerprint
            let coordinatesChanged = source.map { !Self.equalCoordinates($0.coordinates, parent.coordinates) } ?? true
            if sourceChanged {
                do {
                    adapter = try fingerprint.makeAdapter()
                } catch {
                    // Keep independently accepted points if an unexpected path is bad.
                    adapter = try? fingerprint.makeAdapter(includingTrack: false)
                    DispatchQueue.main.async { [weak self] in self?.parent?.onMapEvent?(.failed("路线地图坐标暂不可用，已保留可验证点位。")) }
                }
                source = fingerprint
            }
            guard let adapter else {
                controller.rootView = AnyView(AppColors.pageBase.opacity(0))
                return
            }
            if sourceChanged || renderedSegmentID != parent.selectedSegmentID || renderedScene == nil {
                renderedScene = try? adapter.makeScene(selectedSegmentID: parent.selectedSegmentID)
                renderedSegmentID = parent.selectedSegmentID
            }
            guard let scene = renderedScene else { return }
            let selection = adapter.mapSelection(highlightedAnnotationIDs: parent.highlightedAnnotationIDs)
            let cameraRequest = camera.update(
                adapter: adapter, sourceChanged: sourceChanged, coordinatesChanged: coordinatesChanged,
                edgeInsets: parent.edgeInsets, selectedSegmentID: parent.selectedSegmentID,
                highlightedAnnotationIDs: parent.highlightedAnnotationIDs, recenterRequest: parent.recenterRequest
            )
            let scrubMarker = parent.scrubCoordinate.flatMap { try? RouteMapSceneAdapter.mapCoordinate($0) }.map(MapScrubMarker.init)
            // No GPS input is supplied; the elevation cursor stays separate from location.
            controller.rootView = AnyView(MapboxOutdoorMap(
                scene: scene, options: parent.resolvedOptions, selection: selection,
                scrubMarker: scrubMarker, cameraRequest: cameraRequest,
                zoomEnabled: parent.zoomEnabled, rotateEnabled: parent.rotateEnabled,
                onEvent: { [weak self] in self?.handle($0) }
            ))
        }

        private func handle(_ event: OutdoorMapEvent) {
            guard let parent else { return }
            switch event {
            case .userInteractionBegan: camera.userHasInteracted = true
            case .selected(.point(let objectID)):
                if let spanID = adapter?.spanID(for: objectID) { parent.onSelectSpan?(spanID) }
                else if let selection = adapter?.selection(for: objectID) { parent.onSelectMarker?(selection) }
            case .selected(.track(let trackID)):
                if let segmentID = adapter?.segmentID(for: trackID) { parent.onSelectSegment?(segmentID) }
            default: break
            }
            parent.onMapEvent?(event)
        }

        fileprivate static func equalCoordinates(_ lhs: [CLLocationCoordinate2D], _ rhs: [CLLocationCoordinate2D]) -> Bool {
            lhs.elementsEqual(rhs) { $0.latitude == $1.latitude && $0.longitude == $1.longitude }
        }
    }
}

/// Value snapshots share the source arrays; a scrub update does not rebuild scene
/// objects or serialize the route coordinates into new strings.
private struct RouteMapSourceFingerprint: Equatable {
    let coordinates: [CLLocationCoordinate2D]
    let segments: [RouteMapSegment]
    let baseCoordinates: [CLLocationCoordinate2D]
    let divisionBadges: [RouteDivisionBadgeProjection]
    let poiAnnotations: [RoutePOIAnnotation]
    let trackPointAnnotations: [RouteTrackPointMetadata]
    let waypointAnnotations: [RouteWaypointAnnotation]
    let terminalCoordinates: [CLLocationCoordinate2D]
    let startCoordinate: CLLocationCoordinate2D?
    let endCoordinate: CLLocationCoordinate2D?

    init(_ view: RouteMapView) {
        coordinates = view.coordinates
        segments = view.segments
        baseCoordinates = view.baseCoordinates
        divisionBadges = view.divisionBadges
        poiAnnotations = view.poiAnnotations
        trackPointAnnotations = view.trackPointAnnotations
        waypointAnnotations = view.waypointAnnotations
        startCoordinate = view.startCoordinate
        endCoordinate = view.endCoordinate
        terminalCoordinates = [view.startCoordinate, view.endCoordinate].compactMap { $0 }
    }

    func makeAdapter(includingTrack: Bool = true) throws -> RouteMapSceneAdapter {
        try .init(coordinates: includingTrack ? coordinates : [], segments: includingTrack ? segments : [],
                  baseCoordinates: includingTrack ? baseCoordinates : [], divisionBadges: includingTrack ? divisionBadges : [],
                  poiAnnotations: poiAnnotations, trackPointAnnotations: trackPointAnnotations,
                  waypointAnnotations: waypointAnnotations, startCoordinate: startCoordinate, endCoordinate: endCoordinate)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        RouteMapView.Coordinator.equalCoordinates(lhs.coordinates, rhs.coordinates)
            && RouteMapView.Coordinator.equalCoordinates(lhs.baseCoordinates, rhs.baseCoordinates)
            && lhs.segments.count == rhs.segments.count
            && zip(lhs.segments, rhs.segments).allSatisfy { left, right in
                left.id == right.id && left.name == right.name && left.colorHex == right.colorHex
                    && RouteMapView.Coordinator.equalCoordinates(left.coordinates, right.coordinates)
            }
            && lhs.divisionBadges == rhs.divisionBadges
            && lhs.poiAnnotations == rhs.poiAnnotations
            && lhs.trackPointAnnotations == rhs.trackPointAnnotations
            && lhs.waypointAnnotations == rhs.waypointAnnotations
            && RouteMapView.Coordinator.equalCoordinates(lhs.terminalCoordinates, rhs.terminalCoordinates)
            && (lhs.startCoordinate == nil) == (rhs.startCoordinate == nil)
            && (lhs.endCoordinate == nil) == (rhs.endCoordinate == nil)
    }
}
