import Foundation

public struct GuidanceLocation: Equatable, Sendable {
    public let coordinate: MapCoordinate
    public let horizontalAccuracy: Double
    public let timestamp: Date
    public let courseDegrees: Double?

    public init(coordinate: MapCoordinate, horizontalAccuracy: Double, timestamp: Date = Date(), courseDegrees: Double? = nil) {
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
        self.courseDegrees = courseDegrees
    }
}

public struct TrackGuidanceProgress: Equatable, Sendable {
    public let matchedCoordinate: MapCoordinate
    public let distanceAlongRouteMeters: Double
    public let remainingDistanceMeters: Double
    public let totalDistanceMeters: Double
    public let distanceToRouteMeters: Double
    public let courseToFollowDegrees: Double
    public let isOffRoute: Bool
    public let isAtEnd: Bool

    public var fraction: Double { totalDistanceMeters > 0 ? min(1, max(0, distanceAlongRouteMeters / totalDistanceMeters)) : 0 }
}

public enum TrackGuidanceError: LocalizedError, Equatable {
    case zeroLengthTrack
    case invalidDeviationThreshold
    case antipodalSegment

    public var errorDescription: String? {
        switch self {
        case .zeroLengthTrack: return "轨迹没有可导航的水平长度。"
        case .invalidDeviationThreshold: return "偏离阈值必须为有限的正数。"
        case .antipodalSegment: return "轨迹包含无法确定方向的对跖点，请补充中间坐标。"
        }
    }
}

/// Matches a location to one ordered track. Progress is distance along the route,
/// not accumulated distance walked; reversing direction can decrease progress.
public struct TrackGuidance {
    public let track: MapTrack
    public let totalDistanceMeters: Double
    private let segments: [GuidanceSegment]
    private let offRouteThresholdMeters: Double
    private let isClosedLoop: Bool
    private var previousDistanceAlong: Double?
    private var initialDistanceAlong: Double?
    private var hasAdvanced = false
    private var previousTimestamp: Date?
    private var previousLocation: GuidanceLocation?
    private var previousSegmentIndex: Int?

    public init(track: MapTrack, offRouteThresholdMeters: Double = 40) throws {
        guard offRouteThresholdMeters.isFinite, offRouteThresholdMeters > 0 else {
            throw TrackGuidanceError.invalidDeviationThreshold
        }
        var built: [GuidanceSegment] = []
        var length = 0.0
        for (start, end) in zip(track.coordinates, track.coordinates.dropFirst()) {
            let a = GuidanceVector(start), b = GuidanceVector(end)
            let angle = a.angle(to: b)
            let segmentLength = angle * GuidanceSegment.earthRadius
            // Ignore duplicates, including coordinates whose only change is elevation.
            guard segmentLength > 0.001 else { continue }
            guard a.cross(b).length > 1e-12 else { throw TrackGuidanceError.antipodalSegment }
            built.append(GuidanceSegment(start: start, end: end, startDistance: length, angle: angle))
            length += segmentLength
        }
        guard !built.isEmpty, length.isFinite, length > 0 else { throw TrackGuidanceError.zeroLengthTrack }
        self.track = track
        self.totalDistanceMeters = length
        self.segments = built
        self.offRouteThresholdMeters = offRouteThresholdMeters
        self.isClosedLoop = GuidanceVector(track.coordinates[0]).angle(to: GuidanceVector(track.coordinates[track.coordinates.count - 1]))
            * GuidanceSegment.earthRadius < 1
    }

    public mutating func update(_ location: GuidanceLocation, now: Date = Date()) -> TrackGuidanceProgress? {
        let accuracy = location.horizontalAccuracy
        let age = now.timeIntervalSince(location.timestamp)
        guard accuracy.isFinite, accuracy >= 0, accuracy <= 50,
              age.isFinite, age >= -5, age <= 15 else { return nil }
        if let previousTimestamp, location.timestamp < previousTimestamp { return nil }

        let point = GuidanceVector(location.coordinate)
        let candidates = segments.enumerated().map { index, segment in
            segment.match(point, segmentIndex: index)
        }
        guard let closestDistance = candidates.map(\.distanceToRoute).min() else { return nil }
        // Nearby branches at a crossing are inherently ambiguous. Keep the branch
        // closest to the previous route progress instead of jumping to a later lap.
        // Both uncertainty circles matter: a newly accurate fix must not silently
        // discard the branch established by the previous, less accurate fix.
        let ambiguityMeters = max(1, accuracy + (previousLocation?.horizontalAccuracy ?? 0))
        let nearCandidates = candidates.filter { $0.distanceToRoute <= closestDistance + ambiguityMeters }
        let prefersContinuousMatch: (GuidanceMatch, GuidanceMatch) -> Bool = { lhs, rhs in
            if let previousDistanceAlong {
                let lhsDelta = abs(lhs.distanceAlong - previousDistanceAlong)
                let rhsDelta = abs(rhs.distanceAlong - previousDistanceAlong)
                if abs(lhsDelta - rhsDelta) > 0.001 { return lhsDelta < rhsDelta }
            }
            // On the first fix, a loop's coincident start/end belongs to the start.
            if abs(lhs.distanceAlong - rhs.distanceAlong) > 0.001 { return lhs.distanceAlong < rhs.distanceAlong }
            return lhs.distanceToRoute < rhs.distanceToRoute
        }
        guard var match = nearCandidates.min(by: prefersContinuousMatch) else { return nil }

        if let previousLocation, let previousDistanceAlong, let previousSegmentIndex {
            let displacement = GuidanceVector(previousLocation.coordinate).angle(to: point) * GuidanceSegment.earthRadius
            // A nearby fix cannot confidently establish a giant jump to a distant
            // nonadjacent branch. Allow a bend between fixes (2x the displacement)
            // plus both GPS uncertainties. Adjacent segments remain unrestricted,
            // and this only selects another available match; it never clamps progress
            // forward or blocks legitimate reverse movement.
            let continuityMeters = 2 * displacement + accuracy + previousLocation.horizontalAccuracy
            if abs(match.distanceAlong - previousDistanceAlong) > continuityMeters,
               abs(match.segmentIndex - previousSegmentIndex) > 1 {
                let nearbyProgressCandidates = candidates.filter {
                    abs($0.distanceAlong - previousDistanceAlong) <= continuityMeters + 0.001
                        && $0.distanceToRoute - accuracy <= offRouteThresholdMeters
                }
                if let continuousMatch = nearbyProgressCandidates.min(by: prefersContinuousMatch) { match = continuousMatch }
            }
        }

        let offRoute = match.distanceToRoute - accuracy > offRouteThresholdMeters
        let along = min(totalDistanceMeters, max(0, match.distanceAlong))
        let remaining = max(0, totalDistanceMeters - along)
        if !offRoute {
            if let initialDistanceAlong, along > initialDistanceAlong + 5 { hasAdvanced = true }
            if initialDistanceAlong == nil { initialDistanceAlong = along }
        }
        let distanceToEnd = point.angle(to: GuidanceVector(track.coordinates[track.coordinates.count - 1]))
            * GuidanceSegment.earthRadius
        // A short track can fit entirely inside a 20 m arrival circle. Require
        // progress into its final 10% so the start is never reported as arrival.
        let arrivalDistance = min(20, totalDistanceMeters * 0.1)
        let atEnd = !offRoute && match.segmentIndex == segments.count - 1 && remaining <= arrivalDistance && distanceToEnd <= 20
            && (!isClosedLoop || hasAdvanced)
        previousTimestamp = location.timestamp
        // A far-off-route fix should not move the continuity anchor to another branch.
        if !offRoute {
            previousDistanceAlong = along
            previousLocation = location
            previousSegmentIndex = match.segmentIndex
        }

        return TrackGuidanceProgress(matchedCoordinate: match.coordinate, distanceAlongRouteMeters: along,
                                     remainingDistanceMeters: remaining, totalDistanceMeters: totalDistanceMeters,
                                     distanceToRouteMeters: match.distanceToRoute, courseToFollowDegrees: course(atDistance: along),
                                     isOffRoute: offRoute, isAtEnd: atEnd)
    }

    public func coordinate(atFraction: Double) -> MapCoordinate {
        let distance = clampedFraction(atFraction) * totalDistanceMeters
        let segment = segment(atDistance: distance)
        return segment.coordinate(at: (distance - segment.startDistance) / segment.length)
    }

    public func course(atFraction: Double) -> Double {
        course(atDistance: clampedFraction(atFraction) * totalDistanceMeters)
    }

    private func course(atDistance distance: Double) -> Double {
        let segment = segment(atDistance: distance)
        return segment.course(at: (distance - segment.startDistance) / segment.length)
    }

    private func segment(atDistance distance: Double) -> GuidanceSegment {
        // At an interior vertex, show the course of the next segment.
        segments.first { distance < $0.startDistance + $0.length } ?? segments[segments.count - 1]
    }

    private func clampedFraction(_ fraction: Double) -> Double {
        if fraction.isNaN { return 0 }
        return min(1, max(0, fraction))
    }
}

private struct GuidanceMatch {
    let coordinate: MapCoordinate
    let distanceAlong: Double
    let distanceToRoute: Double
    let segmentIndex: Int
}

/// Each line segment is the shortest great-circle arc between its coordinates.
/// Using vectors avoids longitude discontinuities at the date line.
private struct GuidanceSegment {
    static let earthRadius = 6_371_008.8
    let start: MapCoordinate
    let end: MapCoordinate
    let startDistance: Double
    let angle: Double
    let startVector: GuidanceVector
    let endVector: GuidanceVector
    let normal: GuidanceVector
    let tangent: GuidanceVector
    var length: Double { angle * Self.earthRadius }

    init(start: MapCoordinate, end: MapCoordinate, startDistance: Double, angle: Double) {
        self.start = start
        self.end = end
        self.startDistance = startDistance
        self.angle = angle
        let a = GuidanceVector(start), b = GuidanceVector(end)
        self.startVector = a
        self.endVector = b
        self.normal = a.cross(b).normalized
        self.tangent = self.normal.cross(a)
    }

    func match(_ point: GuidanceVector, segmentIndex: Int) -> GuidanceMatch {
        var fraction = 0.0
        var closestDistance = point.angle(to: startVector)
        let endDistance = point.angle(to: endVector)
        if endDistance < closestDistance { fraction = 1; closestDistance = endDistance }
        let projectedAngle = atan2(point.dot(tangent), point.dot(startVector))
        if projectedAngle >= 0, projectedAngle <= angle {
            let projectedFraction = projectedAngle / angle
            let projectionDistance = point.angle(to: vector(at: projectedFraction))
            if projectionDistance <= closestDistance { fraction = projectedFraction; closestDistance = projectionDistance }
        }
        return GuidanceMatch(coordinate: coordinate(at: fraction), distanceAlong: startDistance + fraction * length,
                             distanceToRoute: closestDistance * Self.earthRadius, segmentIndex: segmentIndex)
    }

    func coordinate(at fraction: Double) -> MapCoordinate {
        if fraction <= 0 { return start }
        if fraction >= 1 { return end }
        let point = vector(at: fraction)
        let latitude = atan2(point.z, hypot(point.x, point.y)) * 180 / .pi
        let longitude = atan2(point.y, point.x) * 180 / .pi
        let elevation: Double?
        if let startElevation = start.elevation, let endElevation = end.elevation {
            elevation = startElevation * (1 - fraction) + endElevation * fraction
        } else { elevation = nil }
        // A normalized finite vector always yields valid latitude/longitude.
        return (try? MapCoordinate(latitude: latitude, longitude: longitude, elevation: elevation)) ?? start
    }

    func course(at fraction: Double) -> Double {
        let point = vector(at: min(1, max(0, fraction)))
        let direction = normal.cross(point)
        let longitude = atan2(point.y, point.x)
        let latitude = atan2(point.z, hypot(point.x, point.y))
        let east = GuidanceVector(x: -sin(longitude), y: cos(longitude), z: 0)
        let north = GuidanceVector(x: -sin(latitude) * cos(longitude), y: -sin(latitude) * sin(longitude), z: cos(latitude))
        let degrees = atan2(direction.dot(east), direction.dot(north)) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }

    private func vector(at fraction: Double) -> GuidanceVector {
        (startVector * cos(angle * fraction) + tangent * sin(angle * fraction)).normalized
    }
}

private struct GuidanceVector {
    let x: Double
    let y: Double
    let z: Double

    init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }

    init(_ coordinate: MapCoordinate) {
        let latitude = coordinate.latitude * .pi / 180
        let longitude = coordinate.longitude * .pi / 180
        self.init(x: cos(latitude) * cos(longitude), y: cos(latitude) * sin(longitude), z: sin(latitude))
    }

    var length: Double { sqrt(x * x + y * y + z * z) }
    var normalized: Self { self * (1 / length) }
    func dot(_ other: Self) -> Double { x * other.x + y * other.y + z * other.z }
    func cross(_ other: Self) -> Self {
        Self(x: y * other.z - z * other.y, y: z * other.x - x * other.z, z: x * other.y - y * other.x)
    }
    func angle(to other: Self) -> Double { atan2(cross(other).length, dot(other)) }
    static func + (lhs: Self, rhs: Self) -> Self { Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z) }
    static func * (lhs: Self, rhs: Double) -> Self { Self(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs) }
}
