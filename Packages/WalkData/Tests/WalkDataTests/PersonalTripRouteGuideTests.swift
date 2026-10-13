import XCTest
@testable import WalkData

final class PersonalTripRouteGuideTests: XCTestCase {
    func testExplicitReferencePlacesTitleAndElevationSurviveDecodingWithoutBecomingHikeFacts() throws {
        var guide = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(guideJSON.utf8)) as? [String: Any])
        let confidence: [String: Any] = ["status": "pending_verification", "category": "public_route_fact", "source": "原轨迹记录"]
        guide["title"] = ["value": "翻越垭口到湖畔营地", "confidence": confidence]
        guide["start"] = ["value": ["name": "原记录起点"], "confidence": confidence]
        guide["end"] = ["value": ["name": "湖畔营地"], "confidence": confidence]
        var track = try XCTUnwrap(guide["referenceTrack"] as? [String: Any])
        track["elevationProfile"] = [
            "minElevation": ["meters": 4_000], "maxElevation": ["meters": 4_600],
            "samples": [
                ["distance": ["meters": 0], "elevation": ["meters": 4_000]],
                ["distance": ["meters": 2_400], "elevation": ["meters": 4_600]],
                ["distance": ["meters": 6_800], "elevation": ["meters": 4_200]],
            ],
        ]
        guide["referenceTrack"] = track
        let day = try decodeDay(guide: String(decoding: JSONSerialization.data(withJSONObject: guide), as: UTF8.self), replaceAction: true)
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(day.routeGuide)) as? [String: Any])
        for field in ["title", "start", "end", "referenceTrack"] {
            XCTAssertEqual(encoded[field] as? NSDictionary, guide[field] as? NSDictionary, "不得丢弃明确冻结的 \(field)")
        }
        XCTAssertNil(day.actions.first?.start?.value)
        XCTAssertNil(day.actions.first?.distance?.value)
        XCTAssertNil(day.actions.first?.routeSectionSnapshot)
    }

    func testOptInActualHTTPGeneratedTripPreservesFiveGuidesWithoutClientReconstruction() throws {
        guard let path = ProcessInfo.processInfo.environment["WALK_ROUTE_GUIDE_HTTP_RESPONSE"] else {
            throw XCTSkip("需要显式提供本次真实服务生成响应")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let trip = try JSONDecoder().decode(PersonalTripDetail.self, from: data)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let originals = try XCTUnwrap(object["days"] as? [[String: Any]])
        XCTAssertEqual(trip.days.count, 5)
        XCTAssertEqual(Set(trip.days.compactMap(\.routeGuide?.sourceReferenceDayID)).count, 5)
        for (day, original) in zip(trip.days, originals) {
            let originalGuide = try XCTUnwrap(original["routeGuide"] as? [String: Any])
            let decodedGuide = try XCTUnwrap(day.routeGuide)
            for (name, actual) in [("description", decodedGuide.description), ("notes", decodedGuide.notes), ("accommodationReference", decodedGuide.accommodationReference)] {
                let originalField = originalGuide[name] as? [String: Any]
                XCTAssertEqual(actual?.value, originalField?["value"] as? String)
                XCTAssertEqual(actual?.confidence?.status, (originalField?["confidence"] as? [String: Any])?["status"] as? String)
            }
            let path = (originalGuide["referenceTrack"] as? [String: Any])?["path"] as? [[String: Any]]
            XCTAssertEqual(decodedGuide.referenceTrack?.path?.count, path?.count)
            XCTAssertTrue(day.actions.filter { $0.actionType == "hike" }.allSatisfy {
                $0.routeSectionSnapshot == nil && $0.routeSectionConfidence?.status == "unavailable"
                    && $0.distance?.value == nil && $0.estimatedDuration?.value == nil
            })
        }
    }

    func testFrozenGuidePreservesReferenceIdentityNotesMetricsPathAndConfidence() throws {
        let day = try decodeDay(guide: guideJSON)
        let guide = try XCTUnwrap(day.routeGuide)
        XCTAssertEqual(guide.sourceReferenceDayID, "source-day-7")
        XCTAssertEqual(guide.description?.value, "沿山谷抵达湖畔，原记录仅供参考。")
        XCTAssertEqual(guide.notes?.confidence?.status, "pending_verification")
        XCTAssertEqual(guide.accommodationReference?.value, "原记录营地")
        XCTAssertEqual(guide.referenceTrack?.path?.count, 2)
        XCTAssertEqual(guide.referenceTrack?.path?.first?.referenceSystem, "WGS84")
        XCTAssertEqual(guide.referenceTrack?.distance?.meters, 9240)
        XCTAssertEqual(guide.referenceTrack?.descent?.meters, 120)
        XCTAssertEqual(guide.referenceTrack?.estimatedDuration?.seconds, 15480)
        XCTAssertEqual(guide.referenceTrack?.confidence.category, .publicRouteFact)
        let encoded = try JSONEncoder().encode(day)
        let roundTrip = try JSONDecoder().decode(PersonalTripDay.self, from: encoded)
        XCTAssertEqual(roundTrip.routeGuide, guide)
    }

    func testOldDaysWithoutGuideRemainCompatibleWithoutInferringReferenceDay() throws {
        let day = try decodeDay(guide: nil)
        XCTAssertNil(day.routeGuide)
        XCTAssertEqual(day.dayNumber, 1)
        XCTAssertFalse(day.actions.isEmpty)
    }

    func testUnknownHikeSectionKeepsExplicitUnavailableStateWithoutBorrowingReferenceTrack() throws {
        let day = try decodeDay(guide: guideJSON, replaceAction: true)
        let action = try XCTUnwrap(day.actions.first)
        XCTAssertNil(action.routeSectionSnapshot)
        XCTAssertEqual(action.routeSectionConfidence?.status, "unavailable")
        XCTAssertEqual(action.routeSectionConfidence?.category, .generatedSuggestion)
        XCTAssertNil(action.distance?.value)
        XCTAssertNil(action.estimatedDuration?.value)
        XCTAssertEqual(day.routeGuide?.referenceTrack?.distance?.meters, 9240)
    }

    func testGuideTrackRequiresConfidenceAndDoesNotDiscardStatusOnlyQualifiedFields() throws {
        let guide = try JSONDecoder().decode(PersonalTripRouteGuide.self, from: Data(#"{"sourceReferenceDayId":"source","notes":{"confidence":{"status":"unavailable","category":"public_route_fact"}}}"#.utf8))
        XCTAssertNil(guide.notes?.value)
        XCTAssertEqual(guide.notes?.confidence?.status, "unavailable")
        XCTAssertThrowsError(try JSONDecoder().decode(PersonalTripRouteGuide.self, from: Data(#"{"sourceReferenceDayId":"source","referenceTrack":{"distance":{"meters":2000}}}"#.utf8)))
    }

    private func decodeDay(guide: String?, replaceAction: Bool = false) throws -> PersonalTripDay {
        let fixtures = DefaultMockFixtures.all()
        let data = try XCTUnwrap(fixtures[PersonalTripAPI.Days(tripID: "trip-yading-5d").identifier])
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let projection = try XCTUnwrap(root["data"] as? [String: Any])
        var day = try XCTUnwrap((projection["days"] as? [[String: Any]])?.first)
        if let guide { day["routeGuide"] = try JSONSerialization.jsonObject(with: Data(guide.utf8)) }
        if replaceAction {
            day["actions"] = try JSONSerialization.jsonObject(with: Data(#"[{"sequence":1,"actionType":"hike","routeSectionConfidence":{"status":"unavailable","category":"generated_suggestion"},"distance":{"confidence":{"status":"unavailable","category":"generated_suggestion"}},"estimatedDuration":{"confidence":{"status":"unavailable","category":"generated_suggestion"}}}]"#.utf8))
        }
        return try JSONDecoder().decode(PersonalTripDay.self, from: JSONSerialization.data(withJSONObject: day))
    }

    private var guideJSON: String {
        #"{"sourceReferenceDayId":"source-day-7","description":{"value":"沿山谷抵达湖畔，原记录仅供参考。","confidence":{"status":"pending_verification","category":"public_route_fact","source":"历史记录"}},"notes":{"value":"过溪水位需现场确认","confidence":{"status":"pending_verification","category":"public_route_fact"}},"accommodationReference":{"value":"原记录营地","confidence":{"status":"pending_verification","category":"public_route_fact"}},"referenceTrack":{"path":[{"latitude":28.4,"longitude":100.3,"referenceSystem":"WGS84"},{"latitude":28.5,"longitude":100.4,"referenceSystem":"WGS84"}],"distance":{"meters":9240},"ascent":{"meters":700},"descent":{"meters":120},"estimatedDuration":{"seconds":15480},"confidence":{"status":"pending_verification","category":"public_route_fact","source":"历史轨迹"}}}"#
    }
}
