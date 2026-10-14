import CoreLocation
import Foundation
import WalkData

/// Map-only projection of understood geographic references. The source DTO and
/// the server's track validity / generation eligibility remain unchanged.
enum RouteMapCoordinateAdapter {
    static func coordinate(_ position: PublicRouteGeoPosition?) -> CLLocationCoordinate2D? {
        guard let position,
              position.referenceSystem == "WGS84",
              position.latitude.isFinite,
              position.longitude.isFinite else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: position.latitude, longitude: position.longitude)
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    /// A rejected vertex rejects the complete path. Filtering it would create a
    /// new connecting edge and invalidate path-position / elevation alignment.
    static func coordinates(_ path: [PublicRouteGeoPosition]) throws -> [CLLocationCoordinate2D]? {
        var result: [CLLocationCoordinate2D] = []
        result.reserveCapacity(path.count)
        for position in path {
            try Task.checkCancellation()
            guard let coordinate = coordinate(position) else { return nil }
            result.append(coordinate)
        }
        return result
    }
}
