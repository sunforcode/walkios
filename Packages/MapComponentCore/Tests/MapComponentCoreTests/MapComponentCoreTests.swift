import XCTest
@testable import MapComponentCore

final class MapComponentCoreTests: XCTestCase {
    private func coordinate(_ latitude: Double = 45.906, _ longitude: Double = 6.94) throws -> MapCoordinate {
        try MapCoordinate(latitude: latitude, longitude: longitude)
    }

    func testCoordinateRejectsInvalidRangesAndNonFiniteValues() {
        for pair in [(91.0, 0.0), (-91, 0), (0, 181), (0, -181), (.nan, 0), (0, .infinity)] {
            XCTAssertThrowsError(try coordinate(pair.0, pair.1))
        }
        XCTAssertThrowsError(try MapCoordinate(latitude: 0, longitude: 0, elevation: .nan))
        XCTAssertNoThrow(try coordinate(90, 180))
    }

    func testTrackNeedsTwoPositionsAndNonemptyIdentity() throws {
        XCTAssertThrowsError(try MapTrack(id: "one", name: "", coordinates: [coordinate()]))
        XCTAssertThrowsError(try MapTrack(id: " ", name: "", coordinates: [coordinate(), coordinate(46, 7)]))
    }

    func testHeatmapWeightsMustBeFiniteAndNonnegative() throws {
        for weight in [-1.0, .nan, .infinity] {
            XCTAssertThrowsError(try MapHeatPoint(id: "heat", coordinate: coordinate(), weight: weight))
        }
        XCTAssertNoThrow(try MapHeatPoint(id: "heat", coordinate: coordinate(), weight: 0))
    }

    func testDuplicateSceneIdentitiesAreRejected() throws {
        let point = try MapPoint(id: "same", name: "water", coordinate: coordinate())
        XCTAssertThrowsError(try MapScene(points: [point, point]))
        let track = try MapTrack(id: "same", name: "route", coordinates: [coordinate(), coordinate(46, 7)])
        XCTAssertThrowsError(try MapScene(tracks: [track], points: [point]))
    }

    func testCustomPointStyleValidatesColor() {
        XCTAssertThrowsError(try MapPinStyle(colorHex: "red; invalid", symbolName: "drop.fill"))
        XCTAssertThrowsError(try MapPinStyle(colorHex: "#12345G", symbolName: "drop.fill"))
        XCTAssertThrowsError(try MapPinStyle(colorHex: "#123456", symbolName: ""))
        XCTAssertNoThrow(try MapPinStyle(colorHex: "#489CFF", symbolName: "drop.fill"))
    }

    func testImportsChineseTrackAndPointPreservingLongitudeOrderAndAltitude() throws {
        let scene = try parse("""
        <Placemark><name>测试线路</name><LineString><coordinates>
          6.94,45.906,3800 6.95,45.907,3810
        </coordinates></LineString></Placemark>
        <Placemark><name><![CDATA[测试水源 & 补给]]></name><Point><coordinates>6.945,45.9065,3805</coordinates></Point></Placemark>
        """)
        XCTAssertEqual(scene.tracks.count, 1)
        XCTAssertEqual(scene.points.count, 1)
        let track = try XCTUnwrap(scene.tracks.first)
        XCTAssertEqual(track.name, "测试线路")
        XCTAssertEqual(track.coordinates.map(\.longitude), [6.94, 6.95])
        XCTAssertEqual(track.coordinates.map(\.latitude), [45.906, 45.907])
        XCTAssertEqual(track.coordinates.map(\.elevation), [3800, 3810])
        XCTAssertEqual(scene.points.first?.name, "测试水源 & 补给")
    }

    func testMultiGeometryKeepsDisconnectedTracksSeparateAndIdentityStable() throws {
        let body = """
        <Folder><name>folder is not track name</name><Placemark><name>two legs</name><MultiGeometry>
          <LineString><coordinates>6,45 7,46</coordinates></LineString>
          <LineString><coordinates>8,47 9,48</coordinates></LineString>
        </MultiGeometry></Placemark></Folder>
        """
        let scene = try parse(body)
        XCTAssertEqual(scene.tracks.count, 2)
        XCTAssertEqual(scene.tracks.first?.coordinates.count, 2)
        XCTAssertEqual(scene.tracks.last?.coordinates.first?.longitude, 8)
        XCTAssertEqual(Set(scene.tracks.map(\.id)).count, 2)
        XCTAssertEqual(scene, try parse(body))
    }

    func testGxTrackAndNamespacePrefixesAreSupported() throws {
        let scene = try parse("""
        <Placemark><name>recorded</name><gx:Track>
          <when>2026-10-08T01:00:00Z</when><gx:coord>6.94 45.906 3800</gx:coord>
          <when>2026-10-08T01:01:00Z</when><gx:coord>6.95 45.907 3810</gx:coord>
        </gx:Track></Placemark>
        """)
        XCTAssertEqual(scene.tracks.first?.coordinates.count, 2)
        XCTAssertEqual(scene.tracks.first?.coordinates.last?.elevation, 3810)
    }

    func testCoordinateWithoutAltitudeKeepsAltitudeMissing() throws {
        let scene = try parse("<Placemark><LineString><coordinates>6,45 7,46</coordinates></LineString></Placemark>")
        XCTAssertNil(try XCTUnwrap(scene.tracks.first).coordinates.first?.elevation)
    }

    func testInvalidCoordinateRejectsWholeDocumentInsteadOfDroppingVertex() {
        XCTAssertThrowsError(try parse("<Placemark><LineString><coordinates>6,45 nonsense 7,46</coordinates></LineString></Placemark>"))
        XCTAssertThrowsError(try parse("<Placemark><LineString><coordinates>6,45 7,96</coordinates></LineString></Placemark>"))
        XCTAssertThrowsError(try parse("<Placemark><Point><coordinates>6,45 7,46</coordinates></Point></Placemark>"))
    }

    func testMalformedEmptyAndNonKMLDocumentsAreRejected() {
        for xml in ["", "<kml>", "<kml/>", "<html/>"] {
            XCTAssertThrowsError(try KMLImporter().parse(Data(xml.utf8)))
        }
    }

    func testExternalEntitiesAndUnsupportedGeometryAreRejected() {
        let xml = "<!DOCTYPE kml [<!ENTITY file SYSTEM 'file:///etc/passwd'>]><kml><name>&file;</name></kml>"
        XCTAssertThrowsError(try KMLImporter().parse(Data(xml.utf8)))
        XCTAssertThrowsError(try parse("<Placemark><Polygon><outerBoundaryIs><LinearRing><coordinates>6,45 7,46 6,45</coordinates></LinearRing></outerBoundaryIs></Polygon></Placemark>"))
    }

    func testPointOnlyDocumentIsValid() throws {
        let scene = try parse("<Placemark><name>camp</name><Point><coordinates>6,45</coordinates></Point></Placemark>")
        XCTAssertTrue(scene.tracks.isEmpty)
        XCTAssertEqual(scene.points.count, 1)
    }

    private func parse(_ body: String) throws -> MapScene {
        let xml = "<kml xmlns='http://www.opengis.net/kml/2.2' xmlns:gx='http://www.google.com/kml/ext/2.2'><Document>\(body)</Document></kml>"
        return try KMLImporter().parse(Data(xml.utf8))
    }
}
