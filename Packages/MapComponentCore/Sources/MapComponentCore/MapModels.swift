import Foundation

public enum MapInputError: LocalizedError, Equatable {
    case invalidCoordinate, invalidIdentity, insufficientTrackPositions, invalidPinStyle, invalidHeatWeight, invalidTrackStyle
    case duplicateIdentity(String)

    public var errorDescription: String? {
        switch self {
        case .invalidCoordinate: return "坐标或海拔无效。"
        case .invalidIdentity: return "地图对象 ID 不能为空。"
        case .insufficientTrackPositions: return "轨迹至少需要两个坐标。"
        case .invalidPinStyle: return "点位样式需要 #RRGGBB 颜色和非空图标名称。"
        case .invalidHeatWeight: return "热力权重必须是有限的非负数。"
        case .invalidTrackStyle: return "轨迹样式需要有效颜色、宽度和透明度。"
        case .duplicateIdentity(let id): return "地图对象 ID 重复：\(id)"
        }
    }
}

private func validateIdentity(_ id: String) throws {
    guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw MapInputError.invalidIdentity
    }
}

public struct MapCoordinate: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let elevation: Double?
    public init(latitude: Double, longitude: Double, elevation: Double? = nil) throws {
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude),
              elevation?.isFinite != false else { throw MapInputError.invalidCoordinate }
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
    }
}

public struct MapTrack: Equatable, Sendable {
    public let id: String
    public let name: String
    public let coordinates: [MapCoordinate]
    public let style: MapTrackStyle
    public init(id: String, name: String, coordinates: [MapCoordinate], style: MapTrackStyle? = nil) throws {
        try validateIdentity(id)
        guard coordinates.count >= 2 else { throw MapInputError.insufficientTrackPositions }
        self.id = id
        self.name = name
        self.coordinates = coordinates
        self.style = try style ?? MapTrackStyle()
    }
}

public struct MapTrackStyle: Equatable, Sendable {
    public let colorHex: String
    public let casingColorHex: String
    public let lineWidth: Double
    public let casingWidth: Double
    public let opacity: Double

    public init(colorHex: String = "#FFD454", casingColorHex: String = "#AC6BD8",
                lineWidth: Double = 4, casingWidth: Double = 7.5, opacity: Double = 1) throws {
        guard isHexColor(colorHex), isHexColor(casingColorHex), lineWidth.isFinite, casingWidth.isFinite,
              lineWidth > 0, casingWidth >= lineWidth, opacity.isFinite, (0...1).contains(opacity) else {
            throw MapInputError.invalidTrackStyle
        }
        self.colorHex = colorHex
        self.casingColorHex = casingColorHex
        self.lineWidth = lineWidth
        self.casingWidth = casingWidth
        self.opacity = opacity
    }
}

private func isHexColor(_ value: String) -> Bool {
    value.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
}

public struct MapPinStyle: Equatable, Sendable {
    public enum MarkerShape: String, Equatable, Sendable { case labeled, circle, badge }
    public let colorHex: String
    public let symbolName: String
    public let markerShape: MarkerShape
    public let glyphText: String?
    public let showsPhotoBadge: Bool
    public init(colorHex: String = "#41D9B0", symbolName: String = "mappin",
                markerShape: MarkerShape = .labeled, glyphText: String? = nil, showsPhotoBadge: Bool = false) throws {
        guard isHexColor(colorHex), !symbolName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              glyphText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != true else {
            throw MapInputError.invalidPinStyle
        }
        self.colorHex = colorHex
        self.symbolName = symbolName
        self.markerShape = markerShape
        self.glyphText = glyphText
        self.showsPhotoBadge = showsPhotoBadge
    }
}

public struct MapPoint: Equatable, Sendable {
    public let id: String
    public let objectID: String
    public let name: String
    public let coordinate: MapCoordinate
    public let style: MapPinStyle
    public let isInteractive: Bool
    public init(id: String, name: String, coordinate: MapCoordinate, style: MapPinStyle? = nil,
                objectID: String? = nil, isInteractive: Bool = true) throws {
        try validateIdentity(id)
        try validateIdentity(objectID ?? id)
        self.id = id
        self.objectID = objectID ?? id
        self.name = name
        self.coordinate = coordinate
        self.style = try style ?? MapPinStyle()
        self.isInteractive = isInteractive
    }
}

/// A temporary host-selected position, independent of GPS and scene fitting.
public struct MapScrubMarker: Equatable, Sendable {
    public let coordinate: MapCoordinate
    public init(coordinate: MapCoordinate) { self.coordinate = coordinate }
}

public struct MapHeatPoint: Equatable, Sendable {
    public let id: String
    public let coordinate: MapCoordinate
    public let weight: Double
    public init(id: String, coordinate: MapCoordinate, weight: Double = 1) throws {
        try validateIdentity(id)
        guard weight.isFinite, weight >= 0 else { throw MapInputError.invalidHeatWeight }
        self.id = id
        self.coordinate = coordinate
        self.weight = weight
    }
}

public struct MapScene: Equatable, Sendable {
    public let tracks: [MapTrack]
    public let points: [MapPoint]
    public let heatPoints: [MapHeatPoint]
    public init(tracks: [MapTrack] = [], points: [MapPoint] = [], heatPoints: [MapHeatPoint] = []) throws {
        var identities = Set<String>()
        for id in tracks.map(\.id) + points.map(\.id) + heatPoints.map(\.id) {
            guard identities.insert(id).inserted else { throw MapInputError.duplicateIdentity(id) }
        }
        self.tracks = tracks
        self.points = points
        self.heatPoints = heatPoints
    }

    public var coordinates: [MapCoordinate] {
        tracks.flatMap(\.coordinates) + points.map(\.coordinate) + heatPoints.map(\.coordinate)
    }
}

public enum MapSelection: Equatable, Sendable {
    case track(String)
    case point(String)
}
