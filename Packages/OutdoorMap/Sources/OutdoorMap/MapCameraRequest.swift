import UIKit
import MapComponentCore

/// An explicit host camera action. Increment the ID to issue another action.
public struct MapCameraRequest: Equatable {
    public let id: Int
    public let target: MapCameraTarget
    public let padding: UIEdgeInsets

    public init(id: Int, target: MapCameraTarget, padding: UIEdgeInsets = .zero) {
        self.id = id
        self.target = target
        self.padding = padding
    }
}

public enum MapCameraTarget: Equatable {
    case scene
    case track(String)
    /// The point's objectID, which may identify several annotation positions.
    case point(String)
    case coordinate(MapCoordinate, zoom: Double)
    case coordinates([MapCoordinate], maxZoom: Double)
}
