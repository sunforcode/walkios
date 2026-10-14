import UIKit
import MapboxMaps
import MapComponentCore

/// Installs only component-owned sources/layers. Recreates them after every style reload.
final class MapSceneRenderer {
    static let tracks = "outdoor-tracks"
    static let points = "outdoor-points"
    static let heat = "outdoor-heat"
    static let routeLayer = "outdoor-route"
    static let pinLayer = "outdoor-pins"
    static let contourLayer = "outdoor-contours"
    static let heatLayer = "outdoor-heatmap"
    static let demSource = "outdoor-dem"
    static let hillshadeLayer = "outdoor-hillshade"
    static let userPositionSource = "outdoor-user-position"
    static let userAccuracyLayer = "outdoor-user-accuracy"
    static let userLocationLayer = "outdoor-user-location"
    static let scrubPositionSource = "outdoor-scrub-position"
    static let scrubMarkerLayer = "outdoor-scrub-marker"
    private static let userArrowImage = "outdoor-user-heading-icon"
    private static let userDotImage = "outdoor-user-dot-icon"
    private let map: MapboxMap
    private var renderedScene: MapScene?

    init(map: MapboxMap) { self.map = map }

    func styleDidReload() { renderedScene = nil }

    func render(scene: MapScene, options: MapDisplayOptions, selection: MapSelection?,
                location: GuidanceLocation? = nil, scrubMarker: MapScrubMarker? = nil) throws {
        try installDEM()
        try installContours()
        try installHillshade()
        if renderedScene != scene {
            for point in scene.points {
                let id = Self.imageID(point)
                if !map.imageExists(withId: id) { try map.addImage(Self.pinImage(point), id: id) }
            }
            try putSource(Self.tracks, features: Self.trackFeatures(scene))
            try putSource(Self.points, features: Self.pointFeatures(scene))
            try putSource(Self.heat, features: Self.heatFeatures(scene))
            renderedScene = scene
        }
        // Install heat before both route strokes so enabling it never masks a track.
        try putLayer([
            "id": Self.heatLayer, "type": "heatmap", "source": Self.heat, "slot": "top",
            "paint": [
                "heatmap-weight": ["get", "weight"], "heatmap-radius": 32, "heatmap-intensity": 1.2,
                "heatmap-opacity": 0.65,
                "heatmap-color": ["interpolate", ["linear"], ["heatmap-density"],
                                  0, "rgba(46,136,255,0)", 0.25, "#3CB4F7", 0.5, "#68E5BC",
                                  0.75, "#FFD270", 1, "#F36B45"]
            ]
        ])
        try putLayer([
            "id": "outdoor-route-casing", "type": "line", "source": Self.tracks, "slot": "top",
            "layout": ["line-cap": "round", "line-join": "round"],
            "paint": ["line-color": ["get", "casingColor"], "line-width": ["get", "casingWidth"],
                      "line-opacity": ["get", "opacity"], "line-emissive-strength": 1]
        ])
        try putLayer([
            "id": Self.routeLayer, "type": "line", "source": Self.tracks, "slot": "top",
            "layout": ["line-cap": "round", "line-join": "round"],
            "paint": ["line-color": ["get", "color"], "line-width": ["get", "width"],
                      "line-opacity": ["get", "opacity"], "line-emissive-strength": 1]
        ])
        try putLayer([
            "id": "outdoor-pin-selection", "type": "circle", "source": Self.points, "slot": "top",
            "paint": ["circle-radius": 17, "circle-color": "#FFFFFF", "circle-opacity": 0.45,
                      "circle-stroke-color": "#AC6BD8", "circle-stroke-width": 2]
        ])
        try putLayer([
            "id": Self.pinLayer, "type": "symbol", "source": Self.points, "slot": "top",
            "layout": ["icon-image": ["get", "icon"], "icon-size": 1,
                       "icon-anchor": ["get", "anchor"], "icon-offset": ["get", "offset"], "icon-padding": 2,
                       "symbol-sort-key": ["case", ["get", "interactive"], 1, 0],
                       "icon-allow-overlap": true, "icon-ignore-placement": true],
            "paint": ["icon-emissive-strength": 1]
        ])
        try visible(Self.hillshadeLayer, options.baseMap == .topographic)
        try visible(Self.heatLayer, options.showsHeatmap)
        try visible(Self.contourLayer, options.showsContours)
        try visible("outdoor-contour-labels", options.showsContours)
        let trackID: String
        let pointID: String
        if case .track(let id) = selection { trackID = id } else { trackID = "" }
        if case .point(let id) = selection { pointID = id } else { pointID = "" }
        try map.setLayerProperty(for: Self.routeLayer, property: "line-width",
                                 value: ["case", ["==", ["get", "objectID"], trackID],
                                         ["+", ["get", "width"], 2.5], ["get", "width"]])
        try map.setLayerProperty(for: "outdoor-route-casing", property: "line-width",
                                 value: ["case", ["==", ["get", "objectID"], trackID],
                                         ["+", ["get", "casingWidth"], 2.5], ["get", "casingWidth"]])
        try map.setLayerProperty(for: "outdoor-pin-selection", property: "filter",
                                 value: ["==", ["get", "objectID"], pointID])
        try map.setLayerProperty(for: Self.pinLayer, property: "icon-size",
                                 value: ["case", ["==", ["get", "objectID"], pointID], 1.34, 1])
        if options.showsTerrain {
            var terrain = Terrain(sourceId: Self.demSource)
            terrain.exaggeration = .constant(options.terrainLevel.exaggeration)
            try map.setTerrain(terrain)
        } else { map.removeTerrain() }
        try renderScrubMarker(scrubMarker)
        try renderLocation(location)
    }

    private func renderScrubMarker(_ marker: MapScrubMarker?) throws {
        try putSource(Self.scrubPositionSource, features: Self.scrubFeatures(marker))
        try putLayer([
            "id": Self.scrubMarkerLayer, "type": "circle", "source": Self.scrubPositionSource, "slot": "top",
            "paint": ["circle-radius": 7, "circle-color": "#FFFFFF", "circle-stroke-color": "#41D9B0",
                      "circle-stroke-width": 3, "circle-emissive-strength": 1]
        ], position: .above(Self.pinLayer))
        try visible(Self.scrubMarkerLayer, marker != nil)
    }

    static func scrubFeatures(_ marker: MapScrubMarker?) -> [Feature] {
        guard let marker else { return [] }
        var feature = Feature(geometry: .point(Point(marker.coordinate.clCoordinate)))
        feature.identifier = .string("outdoor-scrub")
        return [feature]
    }

    private func renderLocation(_ location: GuidanceLocation?) throws {
        let features = Self.locationFeatures(location)
        // Only the independent position source changes for a new fix. The coordinate
        // is the original GPS/simulation coordinate, never a match on the KML line.
        try putSource(Self.userPositionSource, features: features)
        if !map.imageExists(withId: Self.userArrowImage) {
            try map.addImage(Self.userPositionImage(showsHeading: true), id: Self.userArrowImage)
        }
        if !map.imageExists(withId: Self.userDotImage) {
            try map.addImage(Self.userPositionImage(showsHeading: false), id: Self.userDotImage)
        }
        try putLayer([
            "id": Self.userAccuracyLayer, "type": "circle", "source": Self.userPositionSource, "slot": "top",
            "paint": [
                "circle-radius": ["interpolate", ["exponential", 2], ["zoom"],
                                  0, ["get", "accuracyAtZoomZero"],
                                  22, ["*", ["get", "accuracyAtZoomZero"], 4_194_304]],
                "circle-pitch-alignment": "map", "circle-pitch-scale": "map",
                "circle-color": "#2980F2", "circle-opacity": 0.1,
                "circle-stroke-color": "#2980F2", "circle-stroke-opacity": 0.3,
                "circle-stroke-width": 1, "circle-emissive-strength": 1
            ]
        ], position: .below("outdoor-route-casing"))
        try putLayer([
            "id": Self.userLocationLayer, "type": "symbol", "source": Self.userPositionSource, "slot": "top",
            "layout": ["icon-image": ["get", "icon"], "icon-size": 1, "icon-anchor": "center",
                       "icon-rotate": ["get", "course"], "icon-rotation-alignment": "map",
                       "icon-pitch-alignment": "viewport", "icon-allow-overlap": true,
                       "icon-ignore-placement": true],
            "paint": ["icon-emissive-strength": 1]
        ], position: .above(Self.pinLayer))
        try visible(Self.userAccuracyLayer, !features.isEmpty)
        try visible(Self.userLocationLayer, !features.isEmpty)
    }

    static func locationFeatures(_ location: GuidanceLocation?) -> [Feature] {
        guard let location,
              location.horizontalAccuracy.isFinite, (0...50).contains(location.horizontalAccuracy),
              location.coordinate.latitude.isFinite, (-90...90).contains(location.coordinate.latitude),
              location.coordinate.longitude.isFinite, (-180...180).contains(location.coordinate.longitude) else {
            return []
        }
        let latitude = min(85, max(-85, location.coordinate.latitude))
        // Use this SDK's 512-point zoom convention rather than a 256-tile constant.
        let metersPerPoint = MapboxMaps.Projection.metersPerPoint(for: latitude, zoom: 0)
        guard metersPerPoint.isFinite, metersPerPoint > 0 else { return [] }
        let course = location.courseDegrees.flatMap { degrees -> Double? in
            degrees.isFinite && (0..<360).contains(degrees) ? degrees : nil
        }
        var feature = Feature(geometry: .point(Point(location.coordinate.clCoordinate)))
        feature.identifier = .string("outdoor-user")
        feature.properties = [
            "accuracyAtZoomZero": .number(location.horizontalAccuracy / metersPerPoint),
            "horizontalAccuracy": .number(location.horizontalAccuracy),
            "icon": .string(course == nil ? Self.userDotImage : Self.userArrowImage),
            "course": .number(course ?? 0)
        ]
        return [feature]
    }

    private static func userPositionImage(showsHeading: Bool) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 36, height: 36)).image { _ in
            let path: UIBezierPath
            if showsHeading {
                // The sprite points north; the symbol layer rotates it by the fix's course.
                path = UIBezierPath()
                path.move(to: CGPoint(x: 18, y: 3))
                path.addLine(to: CGPoint(x: 30, y: 29))
                path.addLine(to: CGPoint(x: 18, y: 23))
                path.addLine(to: CGPoint(x: 6, y: 29))
                path.close()
                path.lineJoinStyle = .round
            } else {
                // A directionless fix must not suggest a heading toward north.
                path = UIBezierPath(ovalIn: CGRect(x: 9, y: 9, width: 18, height: 18))
            }
            UIColor(red: 0.16, green: 0.5, blue: 0.95, alpha: 1).setFill()
            path.fill()
            UIColor.white.setStroke()
            path.lineWidth = 3
            path.stroke()
        }
    }

    private func installDEM() throws {
        guard !map.sourceExists(withId: Self.demSource) else { return }
        var source = RasterDemSource(id: Self.demSource)
        source.url = "mapbox://mapbox.mapbox-terrain-dem-v1"
        source.tileSize = 512
        source.maxzoom = 14
        try map.addSource(source)
    }

    private func installHillshade() throws {
        // The same DEM stays available in 2D and supplies the optional 3D geometry.
        // Only refer to our local basemap or component layer IDs, never Standard internals.
        let anchor = map.layerExists(withId: "outdoor-base-water") ? "outdoor-base-water" : Self.contourLayer
        try putLayer([
            "id": Self.hillshadeLayer, "type": "hillshade", "source": Self.demSource, "slot": "middle",
            "paint": ["hillshade-exaggeration": 0.62,
                      "hillshade-highlight-color": "#FFFFFF", "hillshade-shadow-color": "#6C6D69",
                      "hillshade-accent-color": "#858681", "hillshade-illumination-anchor": "map",
                      "hillshade-illumination-direction": 315, "hillshade-emissive-strength": 1]
        ], position: .below(anchor))
    }

    private func installContours() throws {
        if !map.sourceExists(withId: "outdoor-terrain-vector") {
            var source = VectorSource(id: "outdoor-terrain-vector")
            source.url = "mapbox://mapbox.mapbox-terrain-v2"
            try map.addSource(source)
        }
        try putLayer([
            "id": Self.contourLayer, "type": "line", "source": "outdoor-terrain-vector",
            "source-layer": "contour", "slot": "middle", "minzoom": 10,
            "paint": ["line-color": "#8C9190", "line-opacity": 0.35,
                      "line-width": ["case", [">=", ["get", "index"], 5], 0.65, 0.35]]
        ])
        try putLayer([
            "id": "outdoor-contour-labels", "type": "symbol", "source": "outdoor-terrain-vector",
            "source-layer": "contour", "slot": "middle", "minzoom": 12,
            "filter": [">=", ["get", "index"], 5],
            "layout": ["symbol-placement": "line", "text-field": ["concat", ["to-string", ["get", "ele"]], " m"],
                       "text-font": ["DIN Pro Regular", "Arial Unicode MS Regular"], "text-size": 10],
            "paint": ["text-color": "#777D79", "text-opacity": 0.65,
                      "text-halo-color": "#FFFFFF", "text-halo-width": 1]
        ])
    }

    private func putLayer(_ properties: [String: Any], position: LayerPosition? = nil) throws {
        let id = properties["id"] as! String
        if !map.layerExists(withId: id) { try map.addLayer(with: properties, layerPosition: position) }
    }

    private func visible(_ id: String, _ visible: Bool) throws {
        try map.setLayerProperty(for: id, property: "visibility", value: visible ? "visible" : "none")
    }

    private func putSource(_ id: String, features: [Feature]) throws {
        let collection = FeatureCollection(features: features)
        if map.sourceExists(withId: id) {
            map.updateGeoJSONSource(withId: id, data: .featureCollection(collection))
        } else {
            var source = GeoJSONSource(id: id)
            source.data = .featureCollection(collection)
            try map.addSource(source)
        }
    }

    static func trackFeatures(_ scene: MapScene) -> [Feature] {
        scene.tracks.map { track in
            var feature = Feature(geometry: .lineString(LineString(track.coordinates.map(\.clCoordinate))))
            feature.identifier = .string(track.id)
            feature.properties = ["objectID": .string(track.id), "name": .string(track.name),
                                  "color": .string(track.style.colorHex),
                                  "casingColor": .string(track.style.casingColorHex),
                                  "width": .number(track.style.lineWidth),
                                  "casingWidth": .number(track.style.casingWidth),
                                  "opacity": .number(track.style.opacity)]
            return feature
        }
    }

    static func pointFeatures(_ scene: MapScene) -> [Feature] {
        scene.points.map { point in
            var feature = Feature(geometry: .point(Point(point.coordinate.clCoordinate)))
            feature.identifier = .string(point.id)
            let isLabeled = point.style.markerShape == .labeled
            feature.properties = ["objectID": .string(point.objectID), "name": .string(point.name),
                                  "interactive": .boolean(point.isInteractive),
                                  "label": .string(pointLabel(point)), "icon": .string(imageID(point)),
                                  "anchor": .string(isLabeled ? "left" : "center"),
                                  "offset": .array([.number(isLabeled ? -14 : 0), .number(0)])]
            if let elevation = point.coordinate.elevation { feature.properties?["elevation"] = .number(elevation) }
            return feature
        }
    }

    static func heatFeatures(_ scene: MapScene) -> [Feature] {
        scene.heatPoints.map { point in
            var feature = Feature(geometry: .point(Point(point.coordinate.clCoordinate)))
            feature.identifier = .string(point.id)
            feature.properties = ["weight": .number(point.weight)]
            return feature
        }
    }

    private static func pointLabel(_ point: MapPoint) -> String {
        guard let elevation = point.coordinate.elevation else { return point.name }
        let rounded = elevation.rounded()
        let meters = String(format: "%.0f m", rounded == 0 ? 0 : rounded)
        return point.name.isEmpty ? meters : "\(point.name) · \(meters)"
    }

    private static func imageID(_ point: MapPoint) -> String {
        // Label/style changes receive a new image, while identical content can share it.
        let content = "\(point.style.colorHex)|\(point.style.symbolName)|\(pointLabel(point))|\(point.style.markerShape)|\(point.style.glyphText ?? "")|\(point.style.showsPhotoBadge)"
        let signature = content.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return "outdoor-pin-\(String(signature, radix: 16))"
    }

    private static func pinImage(_ point: MapPoint) -> UIImage {
        let style = point.style
        let rgb = UInt32(style.colorHex.dropFirst(), radix: 16) ?? 0
        let color = UIColor(red: CGFloat((rgb >> 16) & 255) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
                            blue: CGFloat(rgb & 255) / 255, alpha: 1)
        if style.markerShape == .circle { return circleImage(point, color: color) }
        if style.markerShape == .badge { return badgeImage(point, color: color) }
        let nameFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let elevationFont = UIFont.systemFont(ofSize: 11, weight: .regular)
        let elevationText = point.coordinate.elevation.map { elevation in
            let rounded = elevation.rounded()
            return String(format: "%.0f米", rounded == 0 ? 0 : rounded)
        }
        let nameWidth = ceil((point.name as NSString).size(withAttributes: [.font: nameFont]).width)
        let elevationWidth = elevationText.map {
            ceil(($0 as NSString).size(withAttributes: [.font: elevationFont]).width)
        } ?? 0
        let labelWidth = min(160, max(nameWidth, elevationWidth))
        let size = CGSize(width: 39 + labelWidth, height: 32)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIColor.white.setFill()
            let plateHeight: CGFloat = elevationText == nil ? 26 : 32
            let plate = UIBezierPath(roundedRect: CGRect(x: 29, y: (32 - plateHeight) / 2,
                                                         width: labelWidth + 10, height: plateHeight),
                                     cornerRadius: 5)
            plate.fill()
            let circle = UIBezierPath(ovalIn: CGRect(x: 3, y: 5, width: 22, height: 22))
            circle.fill()
            color.setStroke()
            circle.lineWidth = 1.8
            circle.stroke()
            let icon = UIImage(systemName: style.symbolName) ?? UIImage(systemName: "mappin")!
            icon.withTintColor(color, renderingMode: .alwaysOriginal).draw(in: CGRect(x: 8, y: 10, width: 12, height: 12))
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineBreakMode = .byTruncatingTail
            let textHeight = nameFont.lineHeight + (elevationText == nil ? 0 : elevationFont.lineHeight + 0.5)
            let textTop = (32 - textHeight) / 2
            (point.name as NSString).draw(in: CGRect(x: 34, y: textTop,
                                                     width: labelWidth, height: nameFont.lineHeight + 1),
                                          withAttributes: [.font: nameFont,
                                                           .foregroundColor: UIColor(white: 0.25, alpha: 1),
                                                           .paragraphStyle: paragraph])
            if let elevationText {
                (elevationText as NSString).draw(in: CGRect(x: 34, y: textTop + nameFont.lineHeight + 0.5,
                                                           width: labelWidth, height: elevationFont.lineHeight + 1),
                                                withAttributes: [.font: elevationFont,
                                                                 .foregroundColor: UIColor(white: 0.35, alpha: 1),
                                                                 .paragraphStyle: paragraph])
            }
        }
    }

    private static func circleImage(_ point: MapPoint, color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 44, height: 44)).image { _ in
            let circle = UIBezierPath(ovalIn: CGRect(x: 8, y: 8, width: 28, height: 28))
            color.setFill(); circle.fill()
            UIColor.white.withAlphaComponent(0.8).setStroke(); circle.lineWidth = 1.5; circle.stroke()
            if let glyph = point.style.glyphText {
                let font = UIFont.systemFont(ofSize: 13, weight: .semibold)
                let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
                let size = (glyph as NSString).size(withAttributes: attributes)
                (glyph as NSString).draw(at: CGPoint(x: (44 - size.width) / 2, y: (44 - size.height) / 2),
                                        withAttributes: attributes)
            } else {
                UIImage(systemName: point.style.symbolName)?.withTintColor(.white, renderingMode: .alwaysOriginal)
                    .draw(in: CGRect(x: 15, y: 15, width: 14, height: 14))
            }
            if point.style.showsPhotoBadge {
                let badge = UIBezierPath(ovalIn: CGRect(x: 28, y: 3, width: 15, height: 15))
                UIColor.white.setFill(); badge.fill()
                UIImage(systemName: "camera.fill")?.withTintColor(color, renderingMode: .alwaysOriginal)
                    .draw(in: CGRect(x: 31, y: 7, width: 9, height: 7))
            }
        }
    }

    private static func badgeImage(_ point: MapPoint, color: UIColor) -> UIImage {
        let font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let textWidth = min(180, ceil((point.name as NSString).size(withAttributes: [.font: font]).width))
        return UIGraphicsImageRenderer(size: CGSize(width: max(28, textWidth + 16), height: 32)).image { _ in
            let rect = CGRect(x: 0, y: 2, width: max(28, textWidth + 16), height: 28)
            color.setFill(); UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingTail
            (point.name as NSString).draw(in: CGRect(x: 8, y: (32 - font.lineHeight) / 2,
                                                     width: textWidth, height: font.lineHeight + 1),
                                          withAttributes: [.font: font, .foregroundColor: UIColor.white,
                                                           .paragraphStyle: paragraph])
        }
    }
}

extension MapCoordinate {
    var clCoordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}
