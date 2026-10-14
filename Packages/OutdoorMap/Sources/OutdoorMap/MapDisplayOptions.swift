import Foundation
import MapComponentCore

public struct MapDisplayOptions: Equatable, Sendable {
    public enum BaseMap: String, CaseIterable, Sendable {
        case topographic, standard, satellite
    }
    public enum TerrainLevel: String, CaseIterable, Sendable {
        case normal, enhanced

        public var exaggeration: Double {
            switch self {
            case .normal: return 1
            case .enhanced: return 1.5
            }
        }

        var pitch: Double {
            switch self {
            case .normal: return 40
            case .enhanced: return 60
            }
        }
    }
    public var baseMap: BaseMap
    public var showsContours: Bool
    public var showsHeatmap: Bool
    public var showsTerrain: Bool
    public var terrainLevel: TerrainLevel

    public var cameraPitch: Double { showsTerrain ? terrainLevel.pitch : 0 }

    public init(baseMap: BaseMap = .topographic, showsContours: Bool = true,
                showsHeatmap: Bool = false, showsTerrain: Bool = false,
                terrainLevel: TerrainLevel = .normal) {
        self.baseMap = baseMap
        self.showsContours = showsContours
        self.showsHeatmap = showsHeatmap
        self.showsTerrain = showsTerrain
        self.terrainLevel = terrainLevel
    }
}

public enum OutdoorMapEvent {
    case styleReady
    case mapLoaded
    case selected(MapSelection?)
    case longPressed(MapCoordinate)
    case userInteractionBegan
    case failed(String)
}
