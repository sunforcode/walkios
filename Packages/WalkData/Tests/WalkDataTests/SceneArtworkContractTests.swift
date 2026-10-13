import XCTest
@testable import WalkData

final class SceneArtworkContractTests: XCTestCase {
    func testRequestsKeepExplicitVersionAndAuthenticationBoundaries() {
        let route = PublicRouteAPI.Scenes(routeID: "route/中", routeVersionID: "v+1")
        XCTAssertEqual(route.path, "/public-routes/route%2F%E4%B8%AD/scenes")
        XCTAssertTrue(route.pathIsPercentEncoded)
        XCTAssertEqual(route.query, [URLQueryItem(name: "routeVersionId", value: "v+1")])
        XCTAssertEqual(route.authenticationPolicy, .none)
        XCTAssertEqual(route.responseEnvelope, .data)
        XCTAssertEqual(route.storagePolicy, .none)
        let trip = PersonalTripAPI.Scenes(tripID: "trip/1")
        XCTAssertEqual(trip.path, "/trips/trip%2F1/scenes")
        XCTAssertEqual(trip.authenticationPolicy, .required)
        XCTAssertNil(trip.offlineEligibility)
    }

    func testSceneDecodingKeepsExplicitDayIdentityAndEmptyCollection() throws {
        let route = try JSONDecoder().decode(PublicRouteScenes.self, from: Data(#"{"routeId":"r","routeVersionId":"v","sceneRevision":"s","days":[]}"#.utf8))
        XCTAssertNil(route.overview)
        XCTAssertTrue(route.isValid(routeID: "r", routeVersionID: "v", referenceDayIDs: []))
        let trip = try JSONDecoder().decode(PersonalTripScenes.self, from: Data(#"{"tripId":"t","tripRevision":"r1","routeVersionId":"v","sceneRevision":"s","days":[{"tripDayId":"day-2","image":{"mediaId":"m","imageUrl":"https://cdn.test/day-2.png","width":1448,"height":1086,"kind":"aigc"}}]}"#.utf8))
        XCTAssertEqual(trip.days.first?.tripDayID, "day-2")
        XCTAssertEqual(trip.days.first?.image.width, 1448)
        XCTAssertTrue(trip.isValid(tripID: "t", tripRevision: "r1", routeVersionID: "v", tripDayIDs: ["day-1", "day-2"]))
    }

    func testTripMappingRejectsWrongIdentityRevisionVersionUnknownAndDuplicateDays() {
        let image = SceneImage(mediaID: "m", imageURL: "https://cdn.test/m.png", width: 1448, height: 1086, kind: .aigc)
        func scenes(id: String = "t", revision: String = "r", version: String = "v", dayIDs: [String] = ["d"]) -> PersonalTripScenes {
            .init(tripID: id, tripRevision: revision, routeVersionID: version, sceneRevision: "s", overview: image, days: dayIDs.map { .init(tripDayID: $0, image: image) })
        }
        for value in [scenes(id: "other"), scenes(revision: "stale"), scenes(version: "new"), scenes(dayIDs: ["unknown"]), scenes(dayIDs: ["d", "d"])] {
            XCTAssertFalse(value.isValid(tripID: "t", tripRevision: "r", routeVersionID: "v", tripDayIDs: ["d"]))
        }
        XCTAssertTrue(scenes().isValid(tripID: "t", tripRevision: "r", routeVersionID: "v", tripDayIDs: ["d"]))
    }

    func testInvalidMediaRejectsWholeMappingRatherThanInterpretingLocalPaths() {
        for url in ["asset://YadingSceneDay1", "file:///private/image.png", "/media/image.png", "https://user:secret@cdn.test/image.png"] {
            let image = SceneImage(mediaID: "m", imageURL: url, width: 1448, height: 1086, kind: .aigc)
            let value = PublicRouteScenes(routeID: "r", routeVersionID: "v", sceneRevision: "s", overview: image, days: [])
            XCTAssertFalse(value.isValid(routeID: "r", routeVersionID: "v", referenceDayIDs: []))
        }
        XCTAssertNil(SceneImage(mediaID: "m", imageURL: "https://cdn.test/m.png", width: 0, height: 1086, kind: .aigc).remoteURL)
    }
}
