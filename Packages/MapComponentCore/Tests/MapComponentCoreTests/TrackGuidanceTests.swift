import Foundation
import XCTest
@testable import MapComponentCore

final class TrackGuidanceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func coordinate(_ latitude: Double, _ longitude: Double, elevation: Double? = nil) throws -> MapCoordinate {
        try MapCoordinate(latitude: latitude, longitude: longitude, elevation: elevation)
    }

    private func track(_ positions: [(Double, Double)], id: String = "route") throws -> MapTrack {
        try MapTrack(id: id, name: id, coordinates: positions.map { try coordinate($0.0, $0.1) })
    }

    private func sample(_ latitude: Double, _ longitude: Double, accuracy: Double = 5,
                        secondsFromNow: Double = 0, course: Double? = nil) throws -> GuidanceLocation {
        try GuidanceLocation(coordinate: coordinate(latitude, longitude), horizontalAccuracy: accuracy,
                             timestamp: now.addingTimeInterval(secondsFromNow), courseDegrees: course)
    }

    func testStraightMidpointReportsHorizontalLengthRemainingAndCourse() throws {
        let route = try MapTrack(id: "elevated", name: "水平距离", coordinates: [
            coordinate(0, 0, elevation: 1_000), coordinate(0, 0.01, elevation: 3_000)
        ])
        var guidance = try TrackGuidance(track: route)
        let progress = try XCTUnwrap(guidance.update(sample(0, 0.005), now: now))
        XCTAssertEqual(guidance.totalDistanceMeters, 1_111.95, accuracy: 0.1)
        XCTAssertEqual(progress.totalDistanceMeters, guidance.totalDistanceMeters)
        XCTAssertEqual(progress.distanceAlongRouteMeters, 555.975, accuracy: 0.1)
        XCTAssertEqual(progress.remainingDistanceMeters, 555.975, accuracy: 0.1)
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(progress.matchedCoordinate.latitude, 0, accuracy: 0.000001)
        XCTAssertEqual(progress.matchedCoordinate.longitude, 0.005, accuracy: 0.000001)
        XCTAssertEqual(progress.courseToFollowDegrees, 90, accuracy: 0.01)
        XCTAssertFalse(progress.isOffRoute)
        XCTAssertFalse(progress.isAtEnd)
    }

    func testNearestSegmentProjectionAndAccuracyAwareDeviation() throws {
        let route = try track([(0, 0), (0, 0.01)])
        var guidance = try TrackGuidance(track: route)
        let offRoute = try XCTUnwrap(guidance.update(sample(0.001, 0.005), now: now))
        XCTAssertEqual(offRoute.distanceToRouteMeters, 111.195, accuracy: 0.1)
        XCTAssertEqual(offRoute.fraction, 0.5, accuracy: 0.0001)
        XCTAssertTrue(offRoute.isOffRoute)
        let uncertain = try XCTUnwrap(guidance.update(sample(0.00044, 0.005, accuracy: 15), now: now))
        XCTAssertGreaterThan(uncertain.distanceToRouteMeters, 40)
        XCTAssertFalse(uncertain.isOffRoute)
        var strict = try TrackGuidance(track: route, offRouteThresholdMeters: 20)
        XCTAssertTrue(try XCTUnwrap(strict.update(sample(0.0003, 0.005), now: now)).isOffRoute)
    }

    func testBacktrackingDecreasesRouteProgress() throws {
        var guidance = try TrackGuidance(track: track([(0, 0), (0, 0.01)]))
        let forward = try XCTUnwrap(guidance.update(sample(0, 0.008), now: now))
        let back = try XCTUnwrap(guidance.update(sample(0, 0.003), now: now))
        XCTAssertEqual(forward.fraction, 0.8, accuracy: 0.0001)
        XCTAssertEqual(back.fraction, 0.3, accuracy: 0.0001)
        XCTAssertGreaterThan(back.remainingDistanceMeters, forward.remainingDistanceMeters)
    }

    func testClosedLoopStartsAtZeroAndFinishesOnlyAfterFollowingLastSegment() throws {
        var guidance = try TrackGuidance(track: track([(0, 0), (0, 0.001), (0.001, 0.001), (0.001, 0), (0, 0)]))
        let start = try XCTUnwrap(guidance.update(sample(0, 0), now: now))
        XCTAssertEqual(start.fraction, 0, accuracy: 0.0001)
        XCTAssertFalse(start.isAtEnd)
        for position in [(0.0, 0.0005), (0.0005, 0.001), (0.001, 0.0005), (0.0005, 0.0)] {
            let progress = try XCTUnwrap(guidance.update(sample(position.0, position.1), now: now))
            XCTAssertFalse(progress.isAtEnd)
        }
        let finish = try XCTUnwrap(guidance.update(sample(0, 0), now: now))
        XCTAssertEqual(finish.fraction, 1, accuracy: 0.0001)
        XCTAssertTrue(finish.isAtEnd)
        XCTAssertTrue(try XCTUnwrap(guidance.update(sample(0, 0), now: now)).isAtEnd)
    }

    func testCrossingKeepsTheBranchNearestPreviousProgress() throws {
        var guidance = try TrackGuidance(track: track([(-0.001, -0.001), (0.001, 0.001), (0.001, -0.001), (-0.001, 0.001)]))
        _ = guidance.update(try sample(-0.0005, -0.0005), now: now)
        let firstCrossing = try XCTUnwrap(guidance.update(sample(0, 0), now: now))
        XCTAssertLessThan(firstCrossing.fraction, 0.3)
        _ = guidance.update(try sample(0.0005, 0.0005), now: now)
        _ = guidance.update(try sample(0.001, 0), now: now)
        _ = guidance.update(try sample(0.001, -0.001), now: now)
        let laterCrossing = try XCTUnwrap(guidance.update(sample(0, 0), now: now))
        XCTAssertGreaterThan(laterCrossing.fraction, 0.7)
        XCTAssertGreaterThan(laterCrossing.distanceAlongRouteMeters, firstCrossing.distanceAlongRouteMeters)
    }

    private func endpointCrossingTrack() throws -> MapTrack {
        try track([(0, -0.001), (0, 0.001), (0.01, 0.001), (0.01, 0), (0, 0)])
    }

    func testEndpointCrossingCannotFinishWhileWalkingTheEarlySegment() throws {
        var guidance = try TrackGuidance(track: endpointCrossingTrack())
        let start = try XCTUnwrap(guidance.update(sample(0, -0.0001, accuracy: 10, course: 90), now: now))
        XCTAssertEqual(start.distanceAlongRouteMeters, 100.075, accuracy: 0.1)
        let crossing = try XCTUnwrap(guidance.update(sample(0.00006, 0, accuracy: 10, secondsFromNow: 1), now: now))
        XCTAssertEqual(crossing.distanceAlongRouteMeters, 111.195, accuracy: 0.1)
        XCTAssertLessThan(crossing.fraction, 0.1)
        XCTAssertFalse(crossing.isAtEnd)
        let continued = try XCTUnwrap(guidance.update(sample(0, 0.0001, accuracy: 10, secondsFromNow: 2), now: now))
        XCTAssertGreaterThan(continued.distanceAlongRouteMeters, crossing.distanceAlongRouteMeters)
        XCTAssertLessThan(continued.fraction, 0.1)
    }

    func testReturningFromOffRouteRetainsTheEarlyBranchAtAnEndpointCrossing() throws {
        var guidance = try TrackGuidance(track: endpointCrossingTrack())
        _ = guidance.update(try sample(0, -0.0001, accuracy: 10, course: 90), now: now)
        let offRoute = try XCTUnwrap(guidance.update(sample(-0.001, 0, accuracy: 10, secondsFromNow: 1), now: now))
        XCTAssertTrue(offRoute.isOffRoute)
        let returned = try XCTUnwrap(guidance.update(sample(0.00006, 0, accuracy: 10, secondsFromNow: 2), now: now))
        XCTAssertLessThan(returned.fraction, 0.1)
        XCTAssertFalse(returned.isAtEnd)
        XCTAssertFalse(returned.isOffRoute)
    }

    func testEndpointCrossingConsidersAccuracyOfTheContinuityAnchor() throws {
        var guidance = try TrackGuidance(track: endpointCrossingTrack())
        _ = guidance.update(try sample(0, -0.0001, accuracy: 20), now: now)
        let crossing = try XCTUnwrap(guidance.update(sample(0.00006, 0, accuracy: 2, secondsFromNow: 1), now: now))
        XCTAssertLessThan(crossing.fraction, 0.1)
        XCTAssertFalse(crossing.isAtEnd)
    }

    func testNearbyFixCannotJumpToNonadjacentEndpointWithSmallReportedAccuracy() throws {
        var guidance = try TrackGuidance(track: endpointCrossingTrack())
        _ = guidance.update(try sample(0, -0.0001, accuracy: 1), now: now)
        let crossing = try XCTUnwrap(guidance.update(sample(0.00015, 0, accuracy: 1, secondsFromNow: 1), now: now))
        XCTAssertLessThan(crossing.fraction, 0.1)
        XCTAssertFalse(crossing.isAtEnd)
        XCTAssertEqual(crossing.distanceToRouteMeters, 16.679, accuracy: 0.1)
    }

    func testAccurateFixesCanAdvanceAroundAnAdjacentCorner() throws {
        var guidance = try TrackGuidance(track: track([(0, 0), (0, 0.001), (0.001, 0.001)]))
        _ = guidance.update(try sample(0, 0.0009, accuracy: 0), now: now)
        let next = try XCTUnwrap(guidance.update(sample(0.0001, 0.001, accuracy: 0, secondsFromNow: 1), now: now))
        XCTAssertEqual(next.distanceAlongRouteMeters, 122.315, accuracy: 0.1)
        XCTAssertEqual(next.distanceToRouteMeters, 0, accuracy: 0.01)
    }

    func testUnusableGPSSamplesAreIgnoredWithoutChangingMatchingHistory() throws {
        var guidance = try TrackGuidance(track: track([(0, 0), (0, 0.01)]))
        _ = guidance.update(try sample(0, 0.002), now: now)
        for accuracy in [-1.0, .nan, .infinity, 50.01] {
            XCTAssertNil(guidance.update(try sample(0, 0.009, accuracy: accuracy), now: now))
        }
        XCTAssertNil(guidance.update(try sample(0, 0.009, secondsFromNow: -15.01), now: now))
        XCTAssertNil(guidance.update(try sample(0, 0.009, secondsFromNow: 5.01), now: now))
        XCTAssertNil(guidance.update(try GuidanceLocation(coordinate: coordinate(0, 0.009), horizontalAccuracy: 5,
                                                        timestamp: Date(timeIntervalSince1970: .nan)), now: now))
        var boundaryGuidance = try TrackGuidance(track: guidance.track)
        XCTAssertNotNil(boundaryGuidance.update(try sample(0, 0.002, accuracy: 50, secondsFromNow: -15), now: now))
        XCTAssertNotNil(boundaryGuidance.update(try sample(0, 0.002, secondsFromNow: 5, course: .nan), now: now))
        XCTAssertNil(guidance.update(try sample(0, 0.009, secondsFromNow: -1), now: now))
    }

    func testDuplicateCoordinatesAreSkippedAndAnEntirelyStationaryTrackIsRejected() throws {
        let route = try track([(0, 0), (0, 0), (0, 0.001), (0, 0.001), (0, 0.002), (0, 0.002)])
        var guidance = try TrackGuidance(track: route)
        XCTAssertEqual(guidance.totalDistanceMeters, 222.39, accuracy: 0.1)
        XCTAssertEqual(try XCTUnwrap(guidance.update(sample(0, 0.001), now: now)).fraction, 0.5, accuracy: 0.0001)
        XCTAssertThrowsError(try TrackGuidance(track: track([(0, 0), (0, 0), (0, 0)])))
        XCTAssertThrowsError(try TrackGuidance(track: route, offRouteThresholdMeters: -.infinity))
        XCTAssertThrowsError(try TrackGuidance(track: route, offRouteThresholdMeters: 0))
    }

    func testSamplingAndMatchingAcrossDateLineUsesShortHorizontalArc() throws {
        var guidance = try TrackGuidance(track: track([(0, 179.999), (0, -179.999)]))
        XCTAssertEqual(guidance.totalDistanceMeters, 222.39, accuracy: 0.1)
        let midpoint = guidance.coordinate(atFraction: 0.5)
        XCTAssertEqual(abs(midpoint.longitude), 180, accuracy: 0.000001)
        let progress = try XCTUnwrap(guidance.update(sample(0, 180), now: now))
        XCTAssertEqual(progress.fraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(progress.distanceToRouteMeters, 0, accuracy: 0.01)
        XCTAssertEqual(guidance.course(atFraction: 0.5), 90, accuracy: 0.01)
    }

    func testEndRequiresNearEndpointAndCannotBeReportedOffRoute() throws {
        var guidance = try TrackGuidance(track: track([(0, 0), (0, 0.005), (0, 0.01)]))
        let beforeStart = try XCTUnwrap(guidance.update(sample(0, -0.001), now: now))
        XCTAssertEqual(beforeStart.fraction, 0, accuracy: 0.0001)
        _ = guidance.update(try sample(0, 0.005), now: now)
        let farAway = try XCTUnwrap(guidance.update(sample(0.001, 0.01), now: now))
        XCTAssertTrue(farAway.isOffRoute)
        XCTAssertFalse(farAway.isAtEnd)
        let justAfterEnd = try XCTUnwrap(guidance.update(sample(0, 0.01005), now: now))
        XCTAssertEqual(justAfterEnd.fraction, 1, accuracy: 0.0001)
        XCTAssertTrue(justAfterEnd.isAtEnd)
        XCTAssertEqual(guidance.coordinate(atFraction: -1).longitude, 0, accuracy: 0.000001)
        XCTAssertEqual(guidance.coordinate(atFraction: 2).longitude, 0.01, accuracy: 0.000001)
    }

    func testOpenTrackMayStartAtItsEndpointAndCourseTurnsAtVertices() throws {
        var guidance = try TrackGuidance(track: track([(0, 0), (0, 0.001), (0.001, 0.001)]))
        XCTAssertTrue(try XCTUnwrap(guidance.update(sample(0.001, 0.001), now: now)).isAtEnd)
        XCTAssertEqual(guidance.course(atFraction: 0.25), 90, accuracy: 0.01)
        XCTAssertEqual(guidance.course(atFraction: 0.75), 0, accuracy: 0.01)
        XCTAssertEqual(guidance.coordinate(atFraction: .nan), guidance.track.coordinates[0])
        XCTAssertEqual(guidance.coordinate(atFraction: .infinity), guidance.track.coordinates.last)
    }

    func testShortTrackDoesNotReportArrivalWhileStillAtItsStart() throws {
        var guidance = try TrackGuidance(track: track([(0, 0), (0, 0.00005)]))
        let start = try XCTUnwrap(guidance.update(sample(0, 0), now: now))
        XCTAssertFalse(start.isAtEnd)
        let end = try XCTUnwrap(guidance.update(sample(0, 0.00005), now: now))
        XCTAssertTrue(end.isAtEnd)
    }

    func testDistinctTracksHaveIndependentStateAndNeverCreateConnectingSegments() throws {
        let first = try track([(0, 0), (0, 0.002)], id: "first")
        let second = try track([(1, 1), (1, 1.002)], id: "second")
        var firstGuidance = try TrackGuidance(track: first)
        var secondGuidance = try TrackGuidance(track: second)
        _ = firstGuidance.update(try sample(0, 0.0018), now: now)
        let secondProgress = try XCTUnwrap(secondGuidance.update(sample(1, 1.0005), now: now))
        XCTAssertEqual(secondGuidance.track.id, "second")
        XCTAssertEqual(secondProgress.fraction, 0.25, accuracy: 0.0001)
        XCTAssertLessThan(secondGuidance.totalDistanceMeters, 225)
        XCTAssertEqual(try XCTUnwrap(firstGuidance.update(sample(0, 0.001), now: now)).fraction, 0.5, accuracy: 0.0001)
    }
}
