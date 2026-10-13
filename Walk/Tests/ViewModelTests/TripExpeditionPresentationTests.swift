import XCTest
import CoreGraphics
import WalkData
@testable import Walk

@MainActor
final class TripExpeditionPresentationTests: XCTestCase {
    func testRealGuideExposesAnExplicitReferenceGroupAndReferenceElevation() throws {
        let source = try referenceGuideFixture()
        let daily = TripExpeditionPresentation(source: source, selection: .day(2))
        XCTAssertFalse(daily.isDemoScene)
        XCTAssertEqual(daily.title, "翻越垭口 · 湖畔扎营")
        XCTAssertEqual(daily.eyebrow, "参考走法 · 原记录起点 → 湖畔营地")
        XCTAssertEqual(daily.timelineTitle, "当日走法")
        XCTAssertEqual(daily.metrics.map(\.label), ["参考行进", "参考爬升", "参考下降", "参考用时"])
        XCTAssertEqual(daily.metrics.map(\.value), ["9.2 km", "700 m", "120 m", "4 小时 18 分"])
        XCTAssertEqual(daily.elevationProfile?.samples.map(\.distance.meters), [0, 2_400, 6_800], "曲线距离不得缩放到参考统计的 9.24 km")
        XCTAssertEqual(daily.elevationProfile?.samples.map(\.elevation.meters), [4_000, 4_600, 4_200])
        let scene = TripExpeditionSceneProjection(presentation: daily)
        XCTAssertEqual(scene.elevationTitle, "当日参考海拔")
        XCTAssertTrue(scene.notices.contains { $0.contains("参考行进") && $0.contains("待核验") })
        XCTAssertTrue(scene.notices.contains { $0.contains("原轨迹记录") })
        XCTAssertNil(daily.selectedDay?.actions.first?.distance?.value)
        XCTAssertNil(daily.selectedDay?.actions.first?.routeSectionSnapshot)
        XCTAssertTrue(daily.timeline.contains { $0.title == "湖畔营地" && $0.subtitle == "营地参考 · 资料待核验" })
        XCTAssertEqual(scene.elevationQualification, "参考资料 · 待核验")
        XCTAssertTrue(scene.elevationSourceDescription?.contains("原轨迹记录") == true)
    }

    func testAnyActualMetricKeepsTheActualGroupWithoutFillingReferenceNumbers() throws {
        let daily = TripExpeditionPresentation(source: try referenceGuideFixture(actualDistance: true), selection: .day(2))
        XCTAssertEqual(daily.metrics.map(\.label), ["当日徒步", "当日爬升", "当日下降", "预计徒步用时"])
        XCTAssertEqual(daily.metrics.map(\.value), ["3 km", nil, nil, nil])
    }

    func testActualPlacesWinAndMissingReferenceValuesStayUnavailable() throws {
        let actual = TripExpeditionPresentation(source: try referenceGuideFixture(actualPlaces: true), selection: .day(2))
        XCTAssertEqual(actual.eyebrow, "真实起点 → 真实终点")
        let missing = TripExpeditionPresentation(source: try referenceGuideFixture(includeProfile: false, includeReferenceDuration: false), selection: .day(2))
        XCTAssertNil(missing.elevationProfile, "不能用全程海拔或经纬度路径补参考高程")
        XCTAssertNil(missing.metrics.last?.value)
        let transport = TripExpeditionPresentation(source: try referenceGuideFixture(hasHike: false), selection: .day(2))
        XCTAssertTrue(transport.metrics.isEmpty, "交通日不能因存在参考资料就出现徒步四项")
    }

    func testRealReferenceGuideChangesOverviewScopeWithoutChangingFrozenValues() throws {
        let source = try referenceGuideFixture()
        let overview = TripExpeditionPresentation(source: source, selection: .overview)
        XCTAssertEqual(overview.metrics.first?.label, "全程轨迹")
        XCTAssertEqual(overview.metrics.last?.label, "预计行进用时")
        XCTAssertEqual(overview.elevationProfile, source.detail.trip.frozenRouteBasis.elevationProfile)
        XCTAssertEqual(TripExpeditionSceneProjection(presentation: overview).elevationTitle, "全程海拔")
        XCTAssertEqual(overview.timeline[1].subtitle, "参考走法 · 原记录起点 → 湖畔营地 · 待核验")
    }

    func testAdoptedReferencePlanKeepsTheWholeReferenceGroupAndSourceNotices() throws {
        let source = try adoptedReferenceFixture()
        let daily = TripExpeditionPresentation(source: source, selection: .day(2))
        let day = try XCTUnwrap(daily.selectedDay)
        XCTAssertFalse(daily.isDemoScene)
        XCTAssertNotEqual(day.routeGuide?.title?.value, day.actions.first?.routeSectionSnapshot?.name)
        XCTAssertEqual(daily.metrics.map(\.label), ["参考行进", "参考爬升", "参考下降", "参考用时"])
        XCTAssertEqual(daily.metrics.map(\.value), ["9.2 km", "700 m", "120 m", "4 小时 18 分"])
        XCTAssertNil(daily.elevationProfile, "来源提示应由指标分支触发，不能借海拔分支掩盖缺失")
        let notices = TripExpeditionSceneProjection(presentation: daily).notices
        XCTAssertTrue(notices.contains { $0.contains("参考行进") && $0.contains("待核验") })
        XCTAssertTrue(notices.contains { $0.contains("原轨迹记录") })
        XCTAssertTrue(notices.contains { $0.contains("不等同于实际徒步指标") })
        XCTAssertEqual(daily.selectedDay, source.days.days[1], "展示不得改写已采纳行动或可信状态")
    }

    func testAdoptedReferencePlanAcceptsTwoPointPathAndZeroMetricsWithoutInventingDescent() throws {
        let source = try adoptedReferenceFixture { hike, track in
            let path = try XCTUnwrap(track["path"] as? [[String: Any]])
            track["path"] = [path[0], path[2]]
            var snapshot = try XCTUnwrap(hike["routeSectionSnapshot"] as? [String: Any])
            snapshot["path"] = track["path"]
            hike["routeSectionSnapshot"] = snapshot
            for (field, unit) in [("distance", "meters"), ("ascent", "meters"), ("estimatedDuration", "seconds")] {
                var metric = try XCTUnwrap(hike[field] as? [String: Any])
                metric["value"] = [unit: 0]
                hike[field] = metric
                track[field] = [unit: 0]
            }
            track.removeValue(forKey: "descent")
        }
        let daily = TripExpeditionPresentation(source: source, selection: .day(2))
        XCTAssertEqual(daily.metrics.map(\.label), ["参考行进", "参考爬升", "参考下降", "参考用时"])
        XCTAssertEqual(daily.metrics.map(\.value), ["0 m", "0 m", nil, "0 分钟"])
    }

    func testAdoptedReferencePlanRejectsMismatchedMissingAndShortPaths() throws {
        for invalid in ["middle", "order", "referenceSystem", "empty", "single", "missingTrackPath", "missingSnapshotPath", "missingSnapshot"] {
            let source = try adoptedReferenceFixture { hike, track in
                var snapshot = try XCTUnwrap(hike["routeSectionSnapshot"] as? [String: Any])
                var path = try XCTUnwrap(track["path"] as? [[String: Any]])
                switch invalid {
                case "middle": path[1]["latitude"] = 30.015; snapshot["path"] = path
                case "order": snapshot["path"] = Array(path.reversed())
                case "referenceSystem": path[1]["referenceSystem"] = "GCJ02"; snapshot["path"] = path
                case "empty": track["path"] = []; snapshot["path"] = []
                case "single": track["path"] = [path[0]]; snapshot["path"] = [path[0]]
                case "missingTrackPath": track.removeValue(forKey: "path")
                case "missingSnapshotPath": snapshot.removeValue(forKey: "path")
                default: break
                }
                hike["routeSectionSnapshot"] = invalid == "missingSnapshot" ? nil : snapshot
            }
            assertActualReferencePlanGroup(source, invalid)
        }
    }

    func testAdoptedReferencePlanRequiresEveryMetricValueAndExactReferenceEquality() throws {
        for (field, unit) in [("distance", "meters"), ("ascent", "meters"), ("estimatedDuration", "seconds")] {
            for invalid in ["different", "missingMetric", "missingValue", "missingReference"] {
                let source = try adoptedReferenceFixture { hike, track in
                    var metric = try XCTUnwrap(hike[field] as? [String: Any])
                    switch invalid {
                    case "different":
                        let reference = try XCTUnwrap(track[field] as? [String: Any])
                        let value = try XCTUnwrap(reference[unit] as? NSNumber)
                        metric["value"] = [unit: value.doubleValue + 0.000_001]
                    case "missingValue": metric.removeValue(forKey: "value")
                    case "missingReference": track.removeValue(forKey: field)
                    default: break
                    }
                    hike[field] = invalid == "missingMetric" ? nil : metric
                }
                assertActualReferencePlanGroup(source, "\(field): \(invalid)")
            }
        }
    }

    func testAdoptedReferencePlanRejectsEqualNegativeAndNonFiniteMetrics() throws {
        for (field, unit) in [("distance", "meters"), ("ascent", "meters"), ("estimatedDuration", "seconds")] {
            for value in [-1.0, "Infinity", "-Infinity", "NaN"] as [Any] {
                let source = try adoptedReferenceFixture { hike, track in
                    var metric = try XCTUnwrap(hike[field] as? [String: Any])
                    metric["value"] = [unit: value]
                    hike[field] = metric
                    track[field] = [unit: value]
                }
                assertActualReferencePlanGroup(source, "\(field): \(value)")
            }
        }
    }

    func testAdoptedReferencePlanRequiresPendingPublicRouteConfidenceForAllThreeMetricsAndTrack() throws {
        for target in ["distance", "ascent", "estimatedDuration", "track"] {
            for invalid in ["confirmed", "generatedSuggestion", "missingCategory", "missingMetricConfidence"] {
                if target == "track", invalid == "missingMetricConfidence" { continue }
                let source = try adoptedReferenceFixture { hike, track in
                    var confidence: [String: Any] = ["status": "pending_verification", "category": "public_route_fact", "source": "原轨迹记录"]
                    switch invalid {
                    case "confirmed": confidence["status"] = "confirmed"
                    case "generatedSuggestion": confidence["category"] = "generated_suggestion"
                    case "missingCategory": confidence.removeValue(forKey: "category")
                    default: break
                    }
                    if target == "track" {
                        track["confidence"] = confidence
                    } else {
                        var metric = try XCTUnwrap(hike[target] as? [String: Any])
                        metric["confidence"] = invalid == "missingMetricConfidence" ? nil : confidence
                        hike[target] = metric
                    }
                }
                assertActualReferencePlanGroup(source, "\(target): \(invalid)")
            }
        }
    }

    func testAdoptedReferencePlanDoesNotFallbackForMultipleHikes() throws {
        let source = try adoptedReferenceFixture(hikeCount: 2)
        assertActualReferencePlanGroup(source, "多个完整匹配的 hike 仍不得使用单日参考整组")
        let daily = TripExpeditionPresentation(source: source, selection: .day(2))
        XCTAssertEqual(daily.metrics.map(\.value), ["18.5 km", "1400 m", nil, "8 小时 36 分"])
    }

    func testAdoptedReferencePlanRejectsSnapshotWithRouteSectionConfidence() throws {
        let source = try adoptedReferenceFixture { hike, track in
            hike["routeSectionConfidence"] = track["confidence"]
        }
        assertActualReferencePlanGroup(source, "snapshot 与 routeSectionConfidence 并存不能假定合法")
    }

    func testAdoptedReferencePlanRequiresStartAndEndValuesToFullyMatchSnapshotPlaces() throws {
        for endpoint in ["start", "end"] {
            for invalid in ["missingPlace", "missingValue", "differentName", "differentPosition"] {
                let source = try adoptedReferenceFixture { hike, _ in
                    var qualified = try XCTUnwrap(hike[endpoint] as? [String: Any])
                    var place = try XCTUnwrap(qualified["value"] as? [String: Any])
                    switch invalid {
                    case "differentName": place["name"] = "另一个地点"
                    case "differentPosition":
                        var position = try XCTUnwrap(place["position"] as? [String: Any])
                        position["longitude"] = 100.5
                        place["position"] = position
                    default: break
                    }
                    qualified["value"] = invalid == "missingValue" ? nil : place
                    hike[endpoint] = invalid == "missingPlace" ? nil : qualified
                }
                assertActualReferencePlanGroup(source, "\(endpoint): \(invalid)")
            }
        }
    }

    /// Opt-in 本地候选解码与投影证据；候选文件只从工作区读取，不作为 App 或测试包资源。
    func testLocalBeijingFiveDayCandidateDecodesAndProjectsWithoutChangingContent() throws {
        var repositoryURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        while repositoryURL.lastPathComponent != "walkios", repositoryURL.path != "/" {
            repositoryURL.deleteLastPathComponent()
        }
        guard repositoryURL.lastPathComponent == "walkios" else {
            throw XCTSkip("当前源码路径无法定位候选文件工作区")
        }
        let candidateURL = repositoryURL.deletingLastPathComponent()
            .appendingPathComponent("output/trip-correction-20260930/beijing-five-day-candidate-detail.json")
        guard FileManager.default.fileExists(atPath: candidateURL.path) else {
            throw XCTSkip("未提供本地五日行程候选文件")
        }
        let decoded = try APIJSONDecoder.make().decode(PersonalTripDetail.self, from: Data(contentsOf: candidateURL))
        let days = PersonalTripDays(
            tripID: decoded.trip.identity, revision: decoded.revision,
            startDate: decoded.trip.startDate, endDate: decoded.trip.endDate,
            totalDayCount: decoded.trip.totalDayCount, hikingDayCount: decoded.trip.hikingDayCount,
            days: decoded.days
        )
        let source = TripDetailPresentation(detail: decoded, days: days, routeVersionStatus: decoded.routeVersionStatus)
        let overview = TripExpeditionPresentation(source: source, selection: .overview)
        let orderedDays = decoded.days.sorted { $0.dayNumber < $1.dayNumber }
        XCTAssertEqual(decoded.days.count, 5)
        XCTAssertEqual(decoded.trip.totalDayCount, 5)
        XCTAssertEqual(orderedDays.map(\.dayNumber), [1, 2, 3, 4, 5])
        XCTAssertEqual(Set(decoded.days.map(\.identity)).count, 5)
        XCTAssertEqual(days.tripID, decoded.trip.identity)
        XCTAssertEqual(days.revision, decoded.revision)
        XCTAssertEqual(days.totalDayCount, decoded.days.count)
        XCTAssertEqual(days.hikingDayCount, decoded.days.filter { $0.hikingDayNumber != nil }.count)
        XCTAssertEqual(days.startDate, try XCTUnwrap(orderedDays.first).date)
        XCTAssertEqual(days.endDate, try XCTUnwrap(orderedDays.last).date)
        XCTAssertEqual(overview.calendarDays.map(\.identity), orderedDays.map(\.identity))
        XCTAssertEqual(overview.calendarDays.map(\.date), orderedDays.map(\.date))
        XCTAssertEqual(overview.timeline.map(\.id), orderedDays.map(\.identity))
        XCTAssertEqual(decoded.days.reduce(0) { $0 + ($1.points?.count ?? 0) }, 33)

        var projectedPointCount = 0
        for day in orderedDays {
            let daily = TripExpeditionPresentation(source: source, selection: .day(day.dayNumber))
            let track = try XCTUnwrap(day.routeGuide?.referenceTrack)
            XCTAssertFalse(daily.isDemoScene)
            XCTAssertEqual(daily.metrics.map(\.label), ["参考行进", "参考爬升", "参考下降", "参考用时"])
            XCTAssertTrue(daily.metrics.allSatisfy { $0.value != nil })
            let descent = try XCTUnwrap(track.descent?.meters)
            XCTAssertTrue(descent.isFinite && descent >= 0)
            XCTAssertNotNil(daily.metrics.first { $0.id == "descent" }?.value)
            let profile = try XCTUnwrap(daily.elevationProfile)
            XCTAssertEqual(profile, track.elevationProfile)
            XCTAssertGreaterThanOrEqual(profile.samples.count, 2)
            XCTAssertEqual(daily.elevationTitle, "当日参考海拔")
            let pointItems = daily.timeline.filter { $0.id.hasPrefix("\(day.identity)-point-") }
            projectedPointCount += pointItems.count
            XCTAssertEqual(pointItems.count, day.points?.count ?? 0)
            XCTAssertEqual(Set(pointItems.map(\.id)), Set((day.points ?? []).map { "\(day.identity)-point-\($0.sequence)" }))
            XCTAssertEqual(daily.selectedDay?.identity, day.identity)
            XCTAssertEqual(daily.selectedDay?.date, day.date)
            XCTAssertEqual(daily.selectedDay, day, "投影不得改变行动、点位、参考资料或可信状态")
            XCTAssertEqual(daily.source, source)
        }
        XCTAssertEqual(projectedPointCount, 33)
        XCTAssertEqual(source.detail, decoded)
        XCTAssertEqual(source.days.days, decoded.days)
        XCTAssertEqual(source.routeVersionStatus, decoded.routeVersionStatus)
    }

    private func assertActualReferencePlanGroup(_ source: TripDetailPresentation, _ message: String,
                                               file: StaticString = #filePath, line: UInt = #line) {
        let daily = TripExpeditionPresentation(source: source, selection: .day(2))
        XCTAssertEqual(daily.metrics.map(\.label), ["当日徒步", "当日爬升", "当日下降", "预计徒步用时"], message, file: file, line: line)
        XCTAssertNil(daily.metrics.first { $0.id == "descent" }?.value, message, file: file, line: line)
        XCTAssertTrue(daily.referenceInformationNotices.isEmpty, message, file: file, line: line)
    }

    private func adoptedReferenceFixture(
        hikeCount: Int = 1,
        mutate: (inout [String: Any], inout [String: Any]) throws -> Void = { _, _ in }
    ) throws -> TripDetailPresentation {
        let source = try referenceGuideFixture(includeProfile: false)
        var day = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source.days.days[1])) as? [String: Any])
        var guide = try XCTUnwrap(day["routeGuide"] as? [String: Any])
        var track = try XCTUnwrap(guide["referenceTrack"] as? [String: Any])
        let path: [[String: Any]] = (0...2).map {
            ["latitude": 30.0 + Double($0) * 0.01, "longitude": 100.0, "referenceSystem": "WGS84"]
        }
        let start: [String: Any] = ["name": "已采纳起点", "position": path[0]]
        let end: [String: Any] = ["name": "已采纳终点", "position": path[2]]
        let confidence: [String: Any] = ["status": "pending_verification", "category": "public_route_fact", "source": "已采纳的参考计划"]
        let actions = try XCTUnwrap(day["actions"] as? [[String: Any]])
        var hike = try XCTUnwrap(actions.first)
        hike.removeValue(forKey: "routeSectionConfidence")
        hike["routeSectionSnapshot"] = ["name": "已采纳范围", "start": start, "end": end, "path": path]
        hike["start"] = ["value": start, "confidence": confidence]
        hike["end"] = ["value": end, "confidence": confidence]
        for field in ["distance", "ascent", "estimatedDuration"] {
            hike[field] = ["value": try XCTUnwrap(track[field]), "confidence": confidence]
        }
        track["path"] = path
        try mutate(&hike, &track)
        day["actions"] = (1...hikeCount).map { sequence in
            var action = hike
            action["sequence"] = sequence
            return action
        }
        guide["referenceTrack"] = track
        day["routeGuide"] = guide
        let decoder = JSONDecoder()
        // 仅在测试中注入非有限 Double，确保门控不依赖 DTO 预先校验。
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        var days = source.days.days
        days[1] = try decoder.decode(PersonalTripDay.self, from: JSONSerialization.data(withJSONObject: day))
        return TripDetailPresentation(detail: source.detail,
            days: PersonalTripDays(tripID: source.days.tripID, revision: source.days.revision,
                                   startDate: source.days.startDate, endDate: source.days.endDate,
                                   totalDayCount: source.days.totalDayCount, hikingDayCount: source.days.hikingDayCount, days: days),
            routeVersionStatus: source.routeVersionStatus)
    }

    private func referenceGuideFixture(actualDistance: Bool = false, actualPlaces: Bool = false,
                                       includeProfile: Bool = true, includeReferenceDuration: Bool = true,
                                       hasHike: Bool = true) throws -> TripDetailPresentation {
        let source = try fixture()
        let confidence: [String: Any] = ["status": "pending_verification", "category": "public_route_fact", "source": "原轨迹记录"]
        let unavailable: [String: Any] = ["confidence": ["status": "unavailable", "category": "generated_suggestion"]]
        var day = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(source.days.days[1])) as? [String: Any])
        var hike: [String: Any] = ["sequence": 1, "actionType": "hike", "routeSectionConfidence": unavailable["confidence"]!,
                                  "start": unavailable, "end": unavailable, "distance": unavailable, "ascent": unavailable, "estimatedDuration": unavailable]
        if actualDistance { hike["distance"] = ["value": ["meters": 3_000], "confidence": confidence] }
        if actualPlaces {
            hike["start"] = ["value": ["name": "真实起点"], "confidence": confidence]
            hike["end"] = ["value": ["name": "真实终点"], "confidence": confidence]
        }
        day["actions"] = hasHike ? [hike] : []
        day["primaryStage"] = "翻越垭口 · 湖畔扎营"
        day["points"] = [["sequence": 1, "category": "camp", "type": "营地参考", "name": "湖畔营地",
                          "details": ["value": "原记录营地，当前条件待核验。", "confidence": confidence]]]
        var track: [String: Any] = ["distance": ["meters": 9_240], "ascent": ["meters": 700], "descent": ["meters": 120], "confidence": confidence]
        if includeReferenceDuration { track["estimatedDuration"] = ["seconds": 15_480] }
        if includeProfile {
            track["elevationProfile"] = ["minElevation": ["meters": 4_000], "maxElevation": ["meters": 4_600],
                                         "samples": [["distance": ["meters": 0], "elevation": ["meters": 4_000]],
                                                     ["distance": ["meters": 2_400], "elevation": ["meters": 4_600]],
                                                     ["distance": ["meters": 6_800], "elevation": ["meters": 4_200]]]]
        }
        day["routeGuide"] = ["sourceReferenceDayId": "reference-day-1", "title": ["value": "翻越垭口到湖畔营地", "confidence": confidence],
                             "start": ["value": ["name": "原记录起点"], "confidence": confidence],
                             "end": ["value": ["name": "湖畔营地"], "confidence": confidence], "referenceTrack": track]
        var days = source.days.days
        days[1] = try JSONDecoder().decode(PersonalTripDay.self, from: JSONSerialization.data(withJSONObject: day))
        return TripDetailPresentation(detail: source.detail,
            days: PersonalTripDays(tripID: source.days.tripID, revision: source.days.revision,
                                   startDate: source.days.startDate, endDate: source.days.endDate,
                                   totalDayCount: source.days.totalDayCount, hikingDayCount: source.days.hikingDayCount, days: days),
            routeVersionStatus: source.routeVersionStatus)
    }

    func testOverviewEntersFirstAvailableDayAndRepeatedDateDoesNotAdvance() throws {
        let source = try fixture()
        var selection = TripExpeditionSelection.overview

        XCTAssertTrue(selection.enterFirstDay(in: Array(source.days.days.reversed())))
        XCTAssertEqual(selection, .day(1))
        XCTAssertFalse(selection.selectDay(1, availableDays: source.days.days))
        XCTAssertEqual(selection, .day(1))
        XCTAssertFalse(selection.selectDay(99, availableDays: source.days.days))
        XCTAssertEqual(selection, .day(1))
    }

    func testDaySwipeUsesDayOrderHasBoundariesAndCanReturnToOverview() throws {
        let source = try fixture()
        var selection = TripExpeditionSelection.day(1)

        XCTAssertFalse(selection.move(by: -1, in: source.days.days))
        XCTAssertTrue(selection.move(by: 1, in: Array(source.days.days.reversed())))
        XCTAssertEqual(selection, .day(2))
        XCTAssertTrue(selection.move(by: 1, in: source.days.days))
        XCTAssertFalse(selection.move(by: 1, in: source.days.days))
        XCTAssertEqual(selection, .day(3))
        XCTAssertTrue(selection.showOverview())
        XCTAssertEqual(selection, .overview)
        XCTAssertFalse(selection.showOverview())
    }

    func testEmptyDaysDoNotCreateADayOrNavigationTarget() throws {
        var selection = TripExpeditionSelection.overview
        XCTAssertFalse(selection.enterFirstDay(in: []))
        XCTAssertFalse(selection.move(by: 1, in: []))
        XCTAssertEqual(selection, .overview)
    }

    func testDemoAssetsRequireExplicitFlagAndMatchingSample() throws {
        let source = try fixture()
        let production = TripExpeditionPresentation(source: source, selection: .day(2))
        XCTAssertFalse(production.isDemoScene)
        XCTAssertEqual(production.assetName, "TripExpeditionCover")
        XCTAssertTrue(production.routePath.isEmpty)
        XCTAssertTrue(production.landmarks.isEmpty)
        XCTAssertNil(production.elevationProfile)
        XCTAssertNotNil(production.elevationUnavailableText)

        let expected = ["TripSceneArrival", "TripSceneValley", "TripScenePass"]
        for (index, assetName) in expected.enumerated() {
            let demo = TripExpeditionPresentation(source: source, selection: .day(index + 1), demoScenesEnabled: true)
            XCTAssertTrue(demo.isDemoScene)
            XCTAssertEqual(demo.assetName, assetName)
        }
    }

    func testDemoFlagDoesNotApplySampleMappingToDifferentTripOrMissingDays() throws {
        let source = try fixture()
        let changedDays = PersonalTripDays(
            tripID: "another-trip",
            revision: source.days.revision,
            startDate: source.days.startDate,
            endDate: source.days.endDate,
            totalDayCount: 2,
            hikingDayCount: 1,
            days: Array(source.days.days.prefix(2))
        )
        let changed = TripDetailPresentation(detail: source.detail, days: changedDays, routeVersionStatus: source.routeVersionStatus)
        let scene = TripExpeditionPresentation(source: changed, selection: .day(2), demoScenesEnabled: true)
        XCTAssertFalse(scene.isDemoScene)
        XCTAssertEqual(scene.assetName, "TripExpeditionCover")
        XCTAssertNil(scene.elevationProfile)
    }

    func testOverviewKeepsFrozenProfileAndAllNaturalDays() throws {
        let source = try fixture()
        let scene = TripExpeditionPresentation(source: source, selection: .overview)
        XCTAssertNil(scene.selectedDay)
        XCTAssertEqual(scene.elevationProfile, source.detail.trip.frozenRouteBasis.elevationProfile)
        XCTAssertEqual(scene.timeline.count, 3)
        XCTAssertEqual(scene.timeline.map(\.time), ["25", "26", "27"], "总览日期列只显示日号，月份由分段月标承载")
        XCTAssertTrue(scene.timeline[0].subtitle?.hasPrefix("成都东站 → 老榆林") == true)
        let lastDay = try XCTUnwrap(source.days.days.last)
        let returnEndpoint = try XCTUnwrap(lastDay.actions.last?.destination?.value?.name)
        XCTAssertTrue(scene.timeline[2].subtitle?.contains(returnEndpoint) == true, "全程一句起讫仍包含最后返程地点")
        XCTAssertEqual(scene.timelineTitle, "全程概览")
        XCTAssertEqual(scene.metrics.count, 4)
        XCTAssertEqual(scene.eyebrow, "8月25–8月27日")
        XCTAssertEqual(scene.metrics.last?.id, "duration", "主标题下显示冻结路线的预计徒步时间")
    }

    func testOverviewDurationUsesFrozenRouteInsteadOfDailyActionSum() throws {
        let source = try fixture()
        let overview = TripExpeditionPresentation(source: source, selection: .overview)
        let changedDailyActions = TripExpeditionPresentation(source: try twoHikeFixture(), selection: .overview)

        XCTAssertEqual(source.detail.trip.frozenRouteBasis.estimatedDuration.seconds, 259_200)
        XCTAssertEqual(overview.metrics.first(where: { $0.id == "duration" })?.value, "72 小时")
        XCTAssertEqual(changedDailyActions.metrics, overview.metrics,
                       "增减自然日行动不应改写冻结路线的全程指标")
    }

    func testDailyMetricsKeepFourSlotsWithoutInventingDescentOrIncludingTransfers() throws {
        let source = try fixture()
        let arrival = TripExpeditionPresentation(source: source, selection: .day(1))
        XCTAssertTrue(arrival.metrics.isEmpty, "交通日不展示虚构的徒步距离或爬升下降")

        let valley = TripExpeditionPresentation(source: source, selection: .day(2))
        XCTAssertEqual(valley.metrics.map(\.id), ["distance", "ascent", "descent", "duration"])
        XCTAssertEqual(valley.metrics.map(\.value), ["12.5 km", "700 m", nil, "5 小时"])

        let pass = TripExpeditionPresentation(source: source, selection: .day(3))
        XCTAssertEqual(pass.metrics.map(\.id), ["distance", "ascent", "descent", "duration"])
        XCTAssertEqual(pass.metrics.map(\.value), ["30 km", "1600 m", nil, "12 小时 45 分"],
                       "徒步用时不得混入当天接驳或次日返程的预计时间")
        XCTAssertNotNil(source.detail.trip.frozenRouteBasis.descent,
                        "即使全程下降存在，也不得填充到当天缺失的下降字段")
    }

    func testDemoDailyProfilesAreRebasedAndTransportDayHasNoHikingProfile() throws {
        let source = try fixture()
        let arrival = TripExpeditionPresentation(source: source, selection: .day(1), demoScenesEnabled: true)
        XCTAssertNil(arrival.elevationProfile)
        XCTAssertTrue(arrival.metrics.isEmpty)

        let valley = TripExpeditionPresentation(source: source, selection: .day(2), demoScenesEnabled: true)
        let valleyProfile = try XCTUnwrap(valley.elevationProfile)
        XCTAssertEqual(valleyProfile.samples.first?.distance.meters, 0)
        XCTAssertEqual(valleyProfile.samples.last?.distance.meters, 12_500)
        XCTAssertEqual(valleyProfile.maxElevation.meters, 3_520)

        let pass = TripExpeditionPresentation(source: source, selection: .day(3), demoScenesEnabled: true)
        let passProfile = try XCTUnwrap(pass.elevationProfile)
        XCTAssertEqual(passProfile.samples.first?.distance.meters, 0)
        XCTAssertEqual(passProfile.samples.last?.distance.meters, 30_000)
        XCTAssertEqual(passProfile.maxElevation.meters, 4_850)
    }

    func testProfileSliceInterpolatesEndpointsAndRejectsOutOfRange() throws {
        let profile = FrozenRouteElevationProfile(
            minElevation: RouteElevation(meters: 100),
            maxElevation: RouteElevation(meters: 300),
            samples: [
                FrozenRouteElevationSample(distance: RouteDistance(meters: 0), elevation: RouteElevation(meters: 100)),
                FrozenRouteElevationSample(distance: RouteDistance(meters: 1_000), elevation: RouteElevation(meters: 300)),
                FrozenRouteElevationSample(distance: RouteDistance(meters: 2_000), elevation: RouteElevation(meters: 100)),
            ]
        )
        let result = try XCTUnwrap(TripExpeditionPresentation.slice(profile, from: 250, to: 1_500))
        XCTAssertEqual(result.samples.map(\.distance.meters), [0, 750, 1_250])
        XCTAssertEqual(result.samples.map(\.elevation.meters), [150, 300, 200])
        XCTAssertNil(TripExpeditionPresentation.slice(profile, from: 0, to: 2_500))
        XCTAssertNil(TripExpeditionPresentation.slice(profile, from: 500, to: 500))
    }

    func testDailyTimelineKeepsQualifiedTimeAsOneSubtitleAndOriginalDetailsIntact() throws {
        let source = try fixture()
        let arrival = TripExpeditionPresentation(source: source, selection: .day(1))
        XCTAssertEqual(arrival.eyebrow, "成都东站 → 康定客运站 → 老榆林")
        XCTAssertNil(arrival.timeline.first?.time, "带起讫的整句不是精确时间列")
        XCTAssertTrue(arrival.timeline.first?.subtitle?.hasPrefix("07:15 成都东站出发") == true)
        let complete = TripDayPresentation(day: source.days.days[0])
        XCTAssertTrue(complete.presentationItems.flatMap(\.details).contains { $0.contains("10:48") })

        let valley = TripExpeditionPresentation(source: source, selection: .day(2))
        XCTAssertEqual(valley.eyebrow, "老榆林 → 下日乌且营地")
        XCTAssertEqual(valley.timeline.first?.title, "老榆林")
        XCTAssertEqual(valley.timeline.last?.title, "下日乌且营地")
        XCTAssertNil(valley.timeline.first?.time, "摘要不能补造起点时刻")
        XCTAssertTrue(TripDayPresentation(day: source.days.days[1]).presentationItems.flatMap(\.details)
            .contains { $0.contains("08:00 前出发") }, "完整行动仍保留所有说明")
        let alternative = try XCTUnwrap(valley.timeline.first { $0.title.contains("备选") })
        XCTAssertTrue(alternative.subtitle?.contains("初步") == true)

        let pass = TripExpeditionPresentation(source: source, selection: .day(3))
        XCTAssertTrue(pass.timeline.compactMap(\.subtitle).contains { $0.contains("待核验") })
        XCTAssertTrue(pass.timeline.contains { $0.title.contains("草科客栈") })
        XCTAssertEqual(pass.source, source)
    }

    func testCompactSummaryDoesNotCopyLongNotesOrPointDetails() throws {
        let source = try fixture()
        for day in source.days.days {
            let scene = TripExpeditionPresentation(source: source, selection: .day(day.dayNumber))
            let subtitles = scene.timeline.compactMap(\.subtitle)
            for action in day.actions {
                for note in action.transferNotes?.value ?? [] where !note.isEmpty {
                    XCTAssertFalse(subtitles.contains(note), "不将完整行动说明当成副标题")
                }
            }
            for point in day.points ?? [] {
                if let detail = point.details?.value, !detail.isEmpty {
                    XCTAssertFalse(subtitles.contains { $0.contains(detail) }, "节点摘要不拷贝攻略详情")
                }
            }
            XCTAssertEqual(scene.selectedDay, day)
            XCTAssertEqual(scene.source, source, "精简只作用于摘要，不清除来源或原始资料")
        }
    }

    func testUnknownSelectedDayFallsBackToOverview() throws {
        let source = try fixture()
        let scene = TripExpeditionPresentation(source: source, selection: .day(99), demoScenesEnabled: true)
        XCTAssertNil(scene.selectedDay)
        XCTAssertEqual(scene.assetName, "TripSceneOverview")
        XCTAssertEqual(scene.timeline.count, source.days.days.count)
    }

    func testMultipleHikesCoverTheWholeDayInSequenceWithoutRepeatedSharedEndpoint() throws {
        let source = try twoHikeFixture()
        let daily = TripExpeditionPresentation(source: source, selection: .day(2))
        let overview = TripExpeditionPresentation(source: source, selection: .overview)

        XCTAssertEqual(daily.subtitle, "老榆林 → 下日乌且营地 → 草科")
        XCTAssertEqual(daily.eyebrow, "老榆林 → 下日乌且营地 → 草科")
        XCTAssertEqual(daily.metrics.first?.value, "42.5 km")
        XCTAssertEqual(daily.metrics.first(where: { $0.id == "ascent" })?.value, "2300 m")
        XCTAssertEqual(daily.metrics.first(where: { $0.id == "duration" })?.value, "17 小时 45 分")
        XCTAssertEqual(source.days.days[1].actions.first { $0.sequence == 1 }?.start?.confidence?.status, "verified")
        XCTAssertEqual(source.days.days[1].actions.first { $0.sequence == 2 }?.end?.confidence?.status, "verified")
        XCTAssertEqual(overview.timeline[1].subtitle, "老榆林 → 草科", "已核验起讫不能被改成待核验")
        XCTAssertEqual(daily.timeline.filter { $0.id.contains("-action-") }.map(\.id),
                       ["\(source.days.days[1].identity)-action-1", "\(source.days.days[1].identity)-action-2"])
        XCTAssertEqual(daily.timeline.first { $0.id.contains("-point-") }?.sectionLabel, "当日点位")
    }

    func testMultipleHikesRetainKnownEndpointsWhenALaterStartIsMissing() throws {
        let source = try twoHikeFixture(missingSecondStart: true)
        let daily = TripExpeditionPresentation(source: source, selection: .day(2))
        XCTAssertEqual(daily.subtitle, "老榆林 → 下日乌且营地 → 草科")
        XCTAssertEqual(daily.eyebrow, "老榆林 → 下日乌且营地 → 草科")
    }

    func testIncompleteHikeMetricsDoNotPresentPartialSumsAndKeepFieldConfidence() throws {
        for missingMetric in MissingHikeMetric.allCases {
            let source = try twoHikeFixture(missingMetric: missingMetric)
            let daily = TripExpeditionPresentation(source: source, selection: .day(2))
            let second = try XCTUnwrap(daily.selectedDay?.actions.first(where: { $0.sequence == 2 }))
            let metrics = Dictionary(uniqueKeysWithValues: daily.metrics.map { ($0.id, $0) })

            XCTAssertNil(metrics[missingMetric.rawValue]?.value,
                         "\(missingMetric.rawValue) 缺少后一徒步段时，不能显示前一段的值作为完整合计")
            XCTAssertNil(metrics["descent"]?.value)
            if missingMetric != .distance { XCTAssertEqual(metrics["distance"]?.value, "42.5 km") }
            if missingMetric != .ascent { XCTAssertEqual(metrics["ascent"]?.value, "2300 m") }
            if missingMetric != .duration { XCTAssertEqual(metrics["duration"]?.value, "17 小时 45 分") }

            let field: String
            let confidence: InformationConfidence?
            switch missingMetric {
            case .distance:
                field = "距离"
                confidence = second.distance?.confidence
            case .ascent:
                field = "爬升"
                confidence = second.ascent?.confidence
            case .duration:
                field = "预计耗时"
                confidence = second.estimatedDuration?.confidence
            }
            XCTAssertEqual(confidence?.status, "missing")
            XCTAssertTrue(TripDayPresentation(day: try XCTUnwrap(daily.selectedDay)).presentationItems
                .flatMap(\.statusNotices).contains { $0.message == "\(field)：信息缺失" },
                "完整每日投影不能丢掉对应行动字段的缺失状态")
            XCTAssertEqual(daily.source, source)
        }
    }

    func testTimelineMonthLabelsAppearOnlyAtFirstDayAndMonthBoundaries() throws {
        let source = try fixture(dates: [
            LocalDate(year: 2026, month: 8, day: 31),
            LocalDate(year: 2026, month: 9, day: 1),
            LocalDate(year: 2026, month: 9, day: 2),
        ])
        let scene = TripExpeditionPresentation(source: source, selection: .overview)
        XCTAssertEqual(scene.eyebrow, "8月31–9月2日")
        XCTAssertEqual(scene.timeline.map(\.time), ["31", "1", "2"])
        XCTAssertEqual(scene.timeline.map { scene.timelineMonthLabel(for: $0) }, ["8月", "9月", nil])
        XCTAssertEqual(scene.timelineAccessibilityDate(for: scene.timeline[1]), "2026年9月1日")
    }

    func testYearBoundaryRetainsYearAndDailyHeadingUsesActualEndpoints() throws {
        let source = try fixture(dates: [
            LocalDate(year: 2026, month: 12, day: 31),
            LocalDate(year: 2027, month: 1, day: 1),
            LocalDate(year: 2027, month: 1, day: 2),
        ])
        let overview = TripExpeditionPresentation(source: source, selection: .overview)
        XCTAssertEqual(overview.eyebrow, "2026年12月31日–2027年1月2日")
        XCTAssertEqual(overview.timeline.map { overview.timelineMonthLabel(for: $0) }, ["2026年12月", "2027年1月", nil])
        let daily = TripExpeditionPresentation(source: source, selection: .day(2))
        XCTAssertEqual(daily.timelineTitle, "当日走法")
        XCTAssertTrue(daily.timeline.allSatisfy { daily.timelineMonthLabel(for: $0) == nil })
    }

    func testSingleDayOverviewShowsDateOnceWithoutDuplicateRange() throws {
        let source = try fixture(dates: [LocalDate(year: 2026, month: 8, day: 25)])
        let overview = TripExpeditionPresentation(source: source, selection: .overview)
        XCTAssertEqual(overview.dateText, "8月25日")
        XCTAssertEqual(overview.eyebrow, "8月25日")
        XCTAssertEqual(overview.timeline.count, 1)
    }

    func testQualifiedTimesAreNeverPresentedAsExactColumnTimes() throws {
        let scene = TripExpeditionPresentation(source: try fixture(), selection: .day(1))
        let exact = TripTimelineSummaryProjection(id: "time", time: "08:30", title: "出发")
        var qualified = exact
        qualified.time = "08:30 前出发"
        XCTAssertEqual(scene.timelineColumnTime(for: exact), "08:30")
        XCTAssertNil(scene.timelineColumnTime(for: qualified))
        XCTAssertEqual(qualified.time, "08:30 前出发")
    }

    func testSameNamedPointDoesNotEraseEndpointRoleOrConfidence() throws {
        for alternative in [false, true] {
            let source = try fixture(dayAt: 1) { day in
                var actions = try XCTUnwrap(day["actions"] as? [[String: Any]])
                var end = try XCTUnwrap(actions[0]["end"] as? [String: Any])
                end["confidence"] = ["status": "pending_verification"]
                actions[0]["end"] = end
                day["actions"] = actions
                let points = try XCTUnwrap(day["points"] as? [[String: Any]])
                var camp = points[1]
                camp["sequence"] = 1
                camp["isAlternative"] = alternative
                day["points"] = [camp]
            }
            let day = source.days.days[1]
            let scene = TripExpeditionPresentation(source: source, selection: .day(2))
            let endpoint = try XCTUnwrap(scene.timeline.first { $0.id == "\(day.identity)-action-1-end" })
            XCTAssertEqual(endpoint.title, "下日乌且营地")
            XCTAssertEqual(endpoint.subtitle, "终点 · 待核验")
            let point = try XCTUnwrap(scene.timeline.first { $0.id == "\(day.identity)-point-1" })
            XCTAssertEqual(point.title, alternative ? "下日乌且营地 · 备选" : "下日乌且营地")
            XCTAssertEqual(scene.selectedDay, day)
            XCTAssertEqual(TripExpeditionPresentation(source: source, selection: .overview).timeline[1].subtitle,
                           "老榆林 → 下日乌且营地 · 待核验")
        }
    }

    func testTransportTitleKeepsPlaceConfidenceSeparateFromVerifiedMode() throws {
        let source = try fixture(dayAt: 0) { day in
            var actions = try XCTUnwrap(day["actions"] as? [[String: Any]])
            var origin = try XCTUnwrap(actions[0]["origin"] as? [String: Any])
            origin["confidence"] = ["status": "pending_verification"]
            actions[0]["origin"] = origin
            day["actions"] = actions
        }
        let scene = TripExpeditionPresentation(source: source, selection: .day(1))
        XCTAssertEqual(scene.timeline.first?.title, "成都东站（待核验） → 康定客运站")
        XCTAssertEqual(scene.selectedDay?.actions.first?.mode?.confidence?.status, "verified")
        XCTAssertEqual(scene.source, source)
    }

    private func fixture(dayAt index: Int, mutate: (inout [String: Any]) throws -> Void) throws -> TripDetailPresentation {
        let source = try fixture()
        var days = source.days.days
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(days[index])) as? [String: Any])
        try mutate(&json)
        days[index] = try APIJSONDecoder.make().decode(PersonalTripDay.self, from: JSONSerialization.data(withJSONObject: json))
        return TripDetailPresentation(detail: source.detail,
            days: PersonalTripDays(tripID: source.days.tripID, revision: source.days.revision,
                                   startDate: source.days.startDate, endDate: source.days.endDate,
                                   totalDayCount: source.days.totalDayCount, hikingDayCount: source.days.hikingDayCount, days: days),
            routeVersionStatus: source.routeVersionStatus)
    }

    private func fixture(dates: [LocalDate]) throws -> TripDetailPresentation {
        let source = try fixture()
        let changed = zip(source.days.days, dates).map { day, date in
            PersonalTripDay(identity: day.identity, dayNumber: day.dayNumber, date: date,
                            primaryStage: day.primaryStage, hikingDayNumber: day.hikingDayNumber,
                            actions: day.actions, weather: day.weather, points: day.points)
        }
        let days = PersonalTripDays(tripID: source.days.tripID, revision: source.days.revision,
                                   startDate: try XCTUnwrap(dates.first), endDate: try XCTUnwrap(dates.last),
                                   totalDayCount: changed.count, hikingDayCount: changed.filter { $0.hikingDayNumber != nil }.count,
                                   days: Array(changed.reversed()))
        return TripDetailPresentation(detail: source.detail, days: days, routeVersionStatus: source.routeVersionStatus)
    }

    private enum MissingHikeMetric: String, CaseIterable {
        case distance, ascent, duration
    }

    private func twoHikeFixture(
        missingSecondStart: Bool = false,
        missingMetric: MissingHikeMetric? = nil
    ) throws -> TripDetailPresentation {
        let source = try fixture()
        let day = source.days.days[1]
        let second = source.days.days[2].actions[0]
        let following = PersonalTripAction(
            sequence: 2,
            actionType: second.actionType,
            origin: second.origin,
            destination: second.destination,
            mode: second.mode,
            keyTimes: second.keyTimes,
            estimatedDuration: missingMetric == .duration
                ? QualifiedDuration(value: nil, confidence: InformationConfidence(status: "missing"))
                : second.estimatedDuration,
            transferNotes: second.transferNotes,
            routeSectionSnapshot: second.routeSectionSnapshot,
            start: missingSecondStart ? nil : second.start,
            end: second.end,
            distance: missingMetric == .distance
                ? QualifiedDistance(value: nil, confidence: InformationConfidence(status: "missing"))
                : second.distance,
            ascent: missingMetric == .ascent
                ? QualifiedElevationGain(value: nil, confidence: InformationConfidence(status: "missing"))
                : second.ascent
        )
        let changedDay = PersonalTripDay(
            identity: day.identity,
            dayNumber: day.dayNumber,
            date: day.date,
            primaryStage: day.primaryStage,
            hikingDayNumber: day.hikingDayNumber,
            actions: [following, day.actions[0]],
            weather: day.weather,
            points: day.points
        )
        let days = PersonalTripDays(
            tripID: source.days.tripID,
            revision: source.days.revision,
            startDate: source.days.startDate,
            endDate: source.days.endDate,
            totalDayCount: source.days.totalDayCount,
            hikingDayCount: source.days.hikingDayCount,
            days: [source.days.days[0], changedDay, source.days.days[2]]
        )
        return TripDetailPresentation(detail: source.detail, days: days, routeVersionStatus: source.routeVersionStatus)
    }

    private func fixture() throws -> TripDetailPresentation {
        let fixtures = DefaultMockFixtures.personalTripFixtures()
        let detailData = try XCTUnwrap(fixtures[PersonalTripAPI.Detail(tripID: "trip-1").identifier])
        let daysData = try XCTUnwrap(fixtures[PersonalTripAPI.Days(tripID: "trip-1").identifier])
        let detail = try APIJSONDecoder.decode(PersonalTripDetail.self, from: detailData, envelope: .data)
        let days = try APIJSONDecoder.decode(PersonalTripDays.self, from: daysData, envelope: .data)
        return TripDetailPresentation(detail: detail, days: days, routeVersionStatus: detail.routeVersionStatus)
    }
}

final class TripExpeditionSceneGeometryTests: XCTestCase {
    func testArtworkCoversEveryEdgeWithoutStretchingAcrossCanvasSizes() {
        let sizes = [
            CGSize(width: 320, height: 568), CGSize(width: 390, height: 844),
            CGSize(width: 430, height: 932), CGSize(width: 844, height: 390),
            CGSize(width: 1024, height: 768), CGSize(width: 390, height: 440),
        ]
        for size in sizes {
            for ratio in [CGFloat(4.0 / 3.0), CGFloat(852.0 / 1846.0)] {
                let layout = TripExpeditionSceneGeometry(size: size, imageAspectRatio: ratio)
                XCTAssertEqual(layout.artRect.width / layout.artRect.height, ratio, accuracy: 0.0001)
                XCTAssertEqual(layout.artRect.midX, size.width / 2, accuracy: 0.0001)
                XCTAssertEqual(layout.artRect.midY, size.height / 2, accuracy: 0.0001)
                XCTAssertLessThanOrEqual(layout.artRect.minX, 0.0001)
                XCTAssertLessThanOrEqual(layout.artRect.minY, 0.0001)
                XCTAssertGreaterThanOrEqual(layout.artRect.maxX, size.width - 0.0001)
                XCTAssertGreaterThanOrEqual(layout.artRect.maxY, size.height - 0.0001)
                XCTAssertTrue(abs(layout.artRect.width - size.width) < 0.0001
                    || abs(layout.artRect.height - size.height) < 0.0001)
            }
        }
    }

    func testRouteUsesTheSameFillTransformWithoutMovingCroppedAnchors() {
        let layout = TripExpeditionSceneGeometry(size: CGSize(width: 390, height: 844))
        for (x, y) in [(0.15, 0.70), (0.39, 0.53), (0.64, 0.28), (0.84, 0.65)] {
            let point = layout.point(x: x, y: y)
            XCTAssertEqual((point.x - layout.artRect.minX) / layout.artRect.width, x, accuracy: 0.0001)
            XCTAssertEqual((point.y - layout.artRect.minY) / layout.artRect.height, y, accuracy: 0.0001)
        }
        XCTAssertLessThan(layout.point(x: 0, y: 0.5).x, layout.canvasRect.minX)
        XCTAssertGreaterThan(layout.point(x: 1, y: 0.5).x, layout.canvasRect.maxX)
        XCTAssertEqual(layout.point(x: 0.5, y: 0.5), CGPoint(x: 195, y: 422))
    }

    func testLandscapeCanvasCropsVerticallyInsteadOfLeavingSideBars() {
        let layout = TripExpeditionSceneGeometry(size: CGSize(width: 844, height: 390))
        XCTAssertEqual(layout.artRect.width, 844)
        XCTAssertLessThan(layout.artRect.minY, 0)
        XCTAssertGreaterThan(layout.artRect.maxY, 390)
        XCTAssertEqual(layout.artRect.midY, 195)
    }

    func testVisibleLabelsStayWithinTheForegroundViewport() {
        let layout = TripExpeditionSceneGeometry(size: CGSize(width: 390, height: 844))
        let viewport = CGRect(x: 0, y: 300, width: 390, height: 280)
        let labelSize = CGSize(width: 112, height: 36)
        for (x, y) in [(0.35, 0.4), (0.5, 0.5), (0.65, 0.67)] {
            let center = layout.labelCenter(x: x, y: y, labelSize: labelSize, viewport: viewport)
            XCTAssertGreaterThanOrEqual(center.x - labelSize.width / 2, viewport.minX)
            XCTAssertLessThanOrEqual(center.x + labelSize.width / 2, viewport.maxX)
            XCTAssertGreaterThanOrEqual(center.y - labelSize.height / 2, viewport.minY)
            XCTAssertLessThanOrEqual(center.y + labelSize.height / 2, viewport.maxY)
        }
    }

    func testZeroAndInvalidGeometryStaysFinite() {
        for size in [CGSize.zero, CGSize(width: 20, height: 0), CGSize(width: -1, height: 40)] {
            let layout = TripExpeditionSceneGeometry(size: size)
            XCTAssertEqual(layout.artRect, .zero)
            XCTAssertTrue(layout.point(x: 0.5, y: 0.5).x.isFinite)
            XCTAssertTrue(layout.labelCenter(x: 1, y: 1, labelSize: CGSize(width: 112, height: 36)).y.isFinite)
        }
        for ratio in [CGFloat.zero, -1, .infinity, .nan] {
            let layout = TripExpeditionSceneGeometry(size: CGSize(width: 20, height: 40), imageAspectRatio: ratio)
            XCTAssertEqual(layout.artRect.width / layout.artRect.height, 4.0 / 3.0, accuracy: 0.0001)
            XCTAssertGreaterThanOrEqual(layout.artRect.width, 20)
            XCTAssertGreaterThanOrEqual(layout.artRect.height, 40)
        }
    }
}
