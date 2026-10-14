import CoreLocation
import SwiftUI
import UIKit
import MapComponentCore
import OutdoorMap
import WalkDesignSystem

/// Converts an already accepted route projection. It neither interprets CRS nor
/// derives path ranges; both remain responsibilities of the detail snapshot.
struct RouteMapSceneAdapter {
    let scene: MapScene
    let mainCoordinates: [MapCoordinate]
    private let selections: [String: RouteMapSelection]
    private let objectIDsByAnnotationID: [String: String]
    private let spanIDs: [String: String]
    private let segmentIDs: [String: String]

    init(
        coordinates: [CLLocationCoordinate2D] = [],
        segments: [RouteMapSegment] = [],
        baseCoordinates: [CLLocationCoordinate2D] = [],
        divisionBadges: [RouteDivisionBadgeProjection] = [],
        poiAnnotations: [RoutePOIAnnotation] = [],
        trackPointAnnotations: [RouteTrackPointMetadata] = [],
        waypointAnnotations: [RouteWaypointAnnotation] = [],
        startCoordinate: CLLocationCoordinate2D? = nil,
        endCoordinate: CLLocationCoordinate2D? = nil
    ) throws {
        // A bad path is rejected as a whole, never filtered into a new bridge.
        mainCoordinates = try coordinates.map(Self.mapCoordinate)
        let overlayPlan = RouteMapOverlayPlan(coordinates: coordinates, segments: segments, baseCoordinates: baseCoordinates)
        var segmentIDs: [String: String] = [:]
        let tracks = try overlayPlan.overlays.enumerated().map { index, overlay in
            let id = "route-overlay:\(index)"
            if let segmentID = overlay.segmentID { segmentIDs[id] = segmentID }
            let style = try MapTrackStyle(
                colorHex: Self.validHex(overlay.colorHex) ?? Self.colorHex(AppColors.mapRoute),
                casingColorHex: Self.colorHex(AppColors.pageBase), lineWidth: 5, casingWidth: 11
            )
            return try MapTrack(id: id, name: overlay.segmentID ?? "主轨迹",
                                coordinates: overlay.coordinates.map(Self.mapCoordinate), style: style)
        }
        var points: [MapPoint] = []
        var selections: [String: RouteMapSelection] = [:]
        var objectIDsByAnnotationID: [String: String] = [:]
        var spanIDs: [String: String] = [:]
        var pointInstanceIDs = Set<String>()

        func appendSelection(_ selection: RouteMapSelection, coordinate: CLLocationCoordinate2D,
                             name: String, category: RouteMapPointCategory, showsPhotoBadge: Bool = false) throws {
            let objectID = "business:\(selection.identity)"
            // Separate per-location identity from the business object's identity.
            // One selection can therefore emphasize every location of that object.
            if selections[objectID] == nil { selections[objectID] = selection }
            objectIDsByAnnotationID[selection.annotationID] = objectID
            let style = try MapPinStyle(colorHex: Self.colorHex(category.color), markerShape: .circle,
                                        glyphText: category.glyph, showsPhotoBadge: showsPhotoBadge)
            // Repeated positions can legitimately have the same annotation ID.
            // Give each occurrence a stable render identity while retaining the
            // business object ID and annotation lookup used for selection.
            let baseID = "annotation:\(selection.id)"
            var instanceID = baseID
            var occurrence = 0
            while !pointInstanceIDs.insert(instanceID).inserted {
                occurrence += 1
                instanceID = "\(baseID):occurrence:\(occurrence)"
            }
            points.append(try MapPoint(id: instanceID, name: name,
                                       coordinate: Self.mapCoordinate(coordinate), style: style, objectID: objectID))
        }
        for point in poiAnnotations {
            try appendSelection(.poi(point), coordinate: point.coordinate, name: point.title,
                                category: Self.category(for: point.category), showsPhotoBadge: point.category.contains("拍照"))
        }
        for point in trackPointAnnotations {
            try appendSelection(.trackPoint(point), coordinate: point.coordinate, name: point.title, category: .keyPoint)
        }
        for point in waypointAnnotations {
            try appendSelection(.waypoint(point), coordinate: point.coordinate, name: point.title, category: .keyPoint)
        }
        if let coordinate = startCoordinate ?? coordinates.first {
            points.append(try Self.terminal(id: "terminal:start", name: "起点", glyph: "起", coordinate: coordinate, color: AppColors.mapStart))
        }
        if let coordinate = endCoordinate ?? coordinates.last {
            points.append(try Self.terminal(id: "terminal:end", name: "终点", glyph: "终", coordinate: coordinate, color: AppColors.mapEnd))
        }
        for badge in divisionBadges {
            let objectID = "span:\(badge.spanID)"
            spanIDs[objectID] = badge.spanID
            let style = try MapPinStyle(colorHex: Self.validHex(badge.colorHex) ?? Self.colorHex(AppColors.interactionPrimary), markerShape: .badge)
            points.append(try MapPoint(id: "division-badge:\(badge.spanID)", name: badge.label,
                                       coordinate: Self.mapCoordinate(badge.coordinate), style: style, objectID: objectID))
        }
        self.scene = try MapScene(tracks: tracks, points: points)
        self.segmentIDs = segmentIDs
        self.selections = selections
        self.objectIDsByAnnotationID = objectIDsByAnnotationID
        self.spanIDs = spanIDs
    }

    /// Only selection styles change; the accepted coordinate arrays are retained.
    func makeScene(selectedSegmentID: String?) throws -> MapScene {
        guard let selectedSegmentID, segmentIDs.values.contains(selectedSegmentID) else { return scene }
        let tracks = try scene.tracks.map { track in
            let selected = segmentIDs[track.id] == selectedSegmentID
            let style = try MapTrackStyle(colorHex: track.style.colorHex, casingColorHex: track.style.casingColorHex,
                                          lineWidth: selected ? 7.5 : 5, casingWidth: selected ? 13.5 : 11,
                                          opacity: selected ? 1 : 0.2)
            return try MapTrack(id: track.id, name: track.name, coordinates: track.coordinates, style: style)
        }
        return try MapScene(tracks: tracks, points: scene.points)
    }

    func mapSelection(highlightedAnnotationIDs: Set<String>) -> MapSelection? {
        for id in highlightedAnnotationIDs.sorted() {
            if let objectID = objectIDsByAnnotationID[id] { return .point(objectID) }
        }
        return nil
    }

    func selection(for objectID: String) -> RouteMapSelection? { selections[objectID] }
    func spanID(for objectID: String) -> String? { spanIDs[objectID] }
    func segmentID(for trackID: String) -> String? { segmentIDs[trackID] }
    func trackID(for segmentID: String) -> String? { scene.tracks.first { segmentIDs[$0.id] == segmentID }?.id }

    static func mapCoordinate(_ coordinate: CLLocationCoordinate2D) throws -> MapCoordinate {
        try .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    static func colorHex(_ color: Color) -> String {
        let color = UIColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    private static func validHex(_ value: String?) -> String? {
        guard let value, value.range(of: "^#?[0-9A-Fa-f]{6}$", options: .regularExpression) != nil else { return nil }
        return value.hasPrefix("#") ? value : "#" + value
    }

    private static func category(for category: String) -> RouteMapPointCategory {
        if category.contains("营地") { return .camp }
        if category.contains("过夜") || category.contains("住宿") { return .overnight }
        if category.contains("水") { return .water }
        if category.contains("补给") { return .supply }
        return .interest
    }

    private static func terminal(id: String, name: String, glyph: String, coordinate: CLLocationCoordinate2D, color: Color) throws -> MapPoint {
        let style = try MapPinStyle(colorHex: colorHex(color), markerShape: .circle, glyphText: glyph)
        return try MapPoint(id: id, name: name, coordinate: mapCoordinate(coordinate), style: style, isInteractive: false)
    }
}

/// Selections, recenter and visible-area changes produce explicit commands.
/// Ordinary data refresh and elevation scrubbing preserve manual browsing.
struct RouteMapCameraDriver {
    var userHasInteracted = false
    private var request: MapCameraRequest?
    private var selectedSegmentID: String?
    private var highlightedAnnotationIDs: Set<String> = []
    private var edgeInsets: RouteMapInsetsFingerprint?
    private var recenterRequest: Int?

    mutating func update(
        adapter: RouteMapSceneAdapter, sourceChanged: Bool, coordinatesChanged: Bool,
        edgeInsets: UIEdgeInsets, selectedSegmentID: String?, highlightedAnnotationIDs: Set<String>, recenterRequest: Int
    ) -> MapCameraRequest {
        let insets = RouteMapInsetsFingerprint(edgeInsets)
        let insetsChanged = insets != self.edgeInsets
        let highlightsChanged = highlightedAnnotationIDs != self.highlightedAnnotationIDs
        let recenterChanged = self.recenterRequest != recenterRequest
        let segmentChanged = selectedSegmentID != self.selectedSegmentID
        let fullRoute: MapCameraTarget = adapter.mainCoordinates.isEmpty
            ? .scene : .coordinates(adapter.mainCoordinates, maxZoom: 15)
        var target: MapCameraTarget?
        if recenterChanged {
            target = fullRoute
        } else if highlightsChanged, case .point(let objectID) = adapter.mapSelection(highlightedAnnotationIDs: highlightedAnnotationIDs) {
            target = .point(objectID)
        } else if segmentChanged, let selectedSegmentID, let trackID = adapter.trackID(for: selectedSegmentID) {
            target = .track(trackID)
        } else if insetsChanged {
            // Switching the detail drawer / pure-map dock changes the usable map
            // area and SDK ornament placement even after the user browsed it.
            if case .point(let objectID) = adapter.mapSelection(highlightedAnnotationIDs: highlightedAnnotationIDs) {
                target = .point(objectID)
            } else if let selectedSegmentID, let trackID = adapter.trackID(for: selectedSegmentID) {
                target = .track(trackID)
            } else {
                target = fullRoute
            }
        } else if !userHasInteracted,
                  coordinatesChanged || (sourceChanged && adapter.mainCoordinates.isEmpty)
                    || (highlightsChanged && !self.highlightedAnnotationIDs.isEmpty && highlightedAnnotationIDs.isEmpty) {
            target = fullRoute
        }
        if let target {
            request = .init(id: (request?.id ?? 0) + 1, target: target, padding: edgeInsets)
        }
        self.edgeInsets = insets
        self.selectedSegmentID = selectedSegmentID
        self.highlightedAnnotationIDs = highlightedAnnotationIDs
        self.recenterRequest = recenterRequest
        // The first update always has a changed recenter counter.
        return request ?? .init(id: 0, target: fullRoute, padding: edgeInsets)
    }
}
