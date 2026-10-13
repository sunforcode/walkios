import XCTest
import UIKit
import WalkData
@testable import Walk

@MainActor
final class YadingMockPresentationTests: XCTestCase {
    func testOverviewAndFiveDaysResolveDistinctBundledArtwork() throws {
        let source = try fixture()
        let overview = TripExpeditionPresentation(source: source, selection: .overview, demoScenesEnabled: true)
        XCTAssertEqual(overview.assetName, "YadingSceneOverview")
        XCTAssertEqual(overview.timeline.count, 5)
        XCTAssertTrue(overview.timeline.allSatisfy { $0.subtitle != nil })
        XCTAssertEqual(overview.timelineTitle, "全程概览")
        XCTAssertEqual(overview.metrics.first?.label, "全程轨迹", "全程原记录包含首日接驳，不能称全程徒步")
        XCTAssertEqual(overview.elevationProfile, source.detail.trip.frozenRouteBasis.elevationProfile)
        try assertLocalOverlay(overview, names: source.days.days.flatMap(placeNames))
        var dailyNames = [Set<String>]()
        for number in 1...5 {
            let scene = TripExpeditionPresentation(source: source, selection: .day(number), demoScenesEnabled: true)
            XCTAssertEqual(scene.assetName, "YadingSceneDay\(number)")
            XCTAssertEqual(scene.title, source.days.days[number - 1].primaryStage)
            let hike = try XCTUnwrap(source.days.days[number - 1].actions.first { $0.actionType == "hike" })
            let section = try XCTUnwrap(hike.routeSectionSnapshot)
            let itinerary = "\(section.start.name) → \(section.end.name)"
            XCTAssertEqual(scene.eyebrow, itinerary)
            XCTAssertEqual(scene.timelineTitle, "当日走法")
            let day = source.days.days[number - 1]
            let points = scene.timeline.filter { $0.id.contains("-point-") }
            XCTAssertEqual(points.map(\.id), (day.points ?? []).sorted { $0.sequence < $1.sequence }
                .map { "\(day.identity)-point-\($0.sequence)" })
            for point in day.points ?? [] {
                if let detail = point.details?.value, !detail.isEmpty {
                    XCTAssertFalse(points.compactMap(\.subtitle).contains { $0.contains(detail) })
                }
            }
            try assertLocalOverlay(scene, names: placeNames(source.days.days[number - 1]))
            let names = Set(scene.landmarks.map(\.title))
            XCTAssertFalse(dailyNames.contains(names), "不同日必须使用各自关键点，不能重复套用同一组节点")
            dailyNames.append(names)
            XCTAssertEqual(scene.source, source, "艺术叠加不得改写行程和轨迹事实")
            let image = try XCTUnwrap(UIImage(named: scene.assetName))
            XCTAssertEqual(image.size.width / image.size.height, 4.0 / 3.0, accuracy: 0.001)
        }
        XCTAssertNotNil(UIImage(named: overview.assetName))
    }

    func testYadingArtworkCannotLeakIntoRealMode() throws {
        let source = try fixture()
        let remote = remoteScenes(source)
        for selection in selections {
            let scene = TripExpeditionPresentation(source: source, selection: selection, demoScenesEnabled: false)
            assertNoLocalOverlay(scene)
            XCTAssertEqual(scene.artwork, .unavailable)
            if case .day = selection { XCTAssertNil(scene.elevationProfile) }
            let real = TripExpeditionPresentation(source: source, selection: selection, demoScenesEnabled: false, remoteScenes: remote)
            assertNoLocalOverlay(real)
            let image = real.selectedDay.flatMap { day in remote.days.first { $0.tripDayID == day.identity }?.image } ?? remote.overview
            XCTAssertEqual(real.artwork, .remoteURL(try XCTUnwrap(image?.remoteURL)), "真实服务图片保留，但绝不能带入本地示意节点")
        }
    }

    func testMockSixScenesNeverSelectInjectedRemoteImages() throws {
        let source = try fixture()
        for selection in selections {
            let scene = TripExpeditionPresentation(source: source, selection: selection,
                                                   demoScenesEnabled: true, remoteScenes: remoteScenes(source))
            XCTAssertTrue(scene.isDemoScene)
            XCTAssertEqual(scene.artwork, .bundledAsset(scene.assetName), "离线 Mock 只能选本地艺术图，不能发起远程图片加载")
            let projection = TripExpeditionSceneProjection(presentation: scene)
            XCTAssertEqual(projection.artwork, .bundledAsset(scene.assetName))
            XCTAssertEqual(projection.landmarks, scene.landmarks)
            XCTAssertEqual(projection.routePath, scene.routePath)
        }
    }

    func testWrongRouteVersionOrDayIdentityDoesNotReuseCalibratedScene() throws {
        let wrongVersion = try fixture { detail, _ in
            var reference = detail["routeReference"] as! [String: Any]
            reference["adoptedRouteVersionId"] = "different-version"
            detail["routeReference"] = reference
        }
        let wrongDay = try fixture { detail, days in
            var entries = days["days"] as! [[String: Any]]
            entries[2]["identity"] = "another-day"
            days["days"] = entries
            detail["days"] = entries
        }
        for source in [wrongVersion, wrongDay] {
            for selection in selections {
                let scene = TripExpeditionPresentation(source: source, selection: selection, demoScenesEnabled: true)
                assertNoLocalOverlay(scene)
                if case .day = selection { XCTAssertNil(scene.elevationProfile) }
            }
            let overview = TripExpeditionPresentation(source: source, selection: .overview, demoScenesEnabled: true)
            XCTAssertEqual(overview.metrics.first?.label, "全程轨迹", "图片映射降级不能改变混合记录的里程口径")
        }
    }

    func testWrongTripOrRouteIdentityCannotReuseLocalOverlay() throws {
        for changedIdentity in ["trip", "route"] {
            let source = try fixture { detail, days in
                if changedIdentity == "trip" {
                    var trip = detail["trip"] as! [String: Any]
                    trip["identity"] = "unrelated-trip"
                    detail["trip"] = trip
                    days["tripId"] = "unrelated-trip"
                } else {
                    var reference = detail["routeReference"] as! [String: Any]
                    reference["routeId"] = "unrelated-route"
                    detail["routeReference"] = reference
                }
            }
            for selection in selections {
                assertNoLocalOverlay(TripExpeditionPresentation(source: source, selection: selection, demoScenesEnabled: true))
            }
        }
    }

    func testChangedFullPathCannotReuseLocalOverlayEvenWhenDailySubsequencesStillMatch() throws {
        let source = try fixture { detail, days in
            var trip = detail["trip"] as! [String: Any]
            var basis = trip["frozenRouteBasis"] as! [String: Any]
            let main = basis["mainTrackPath"] as! [[String: Any]]
            // 只改完整轨迹的中间点，并对齐该点所在日；首尾、长度和分日关系不变。
            let target = main[main.count / 2]
            let shifted = (target["latitude"] as! Double) + 0.001
            func changed(_ path: [[String: Any]]) -> [[String: Any]] {
                path.map { point in
                    guard point["latitude"] as? Double == target["latitude"] as? Double,
                          point["longitude"] as? Double == target["longitude"] as? Double else { return point }
                    var point = point
                    point["latitude"] = shifted
                    return point
                }
            }
            basis["mainTrackPath"] = changed(main)
            trip["frozenRouteBasis"] = basis
            detail["trip"] = trip
            let entries = (days["days"] as! [[String: Any]]).map { original in
                var day = original
                day["actions"] = (day["actions"] as! [[String: Any]]).map { original in
                    var action = original
                    if var section = action["routeSectionSnapshot"] as? [String: Any], let path = section["path"] as? [[String: Any]] {
                        section["path"] = changed(path)
                        action["routeSectionSnapshot"] = section
                    }
                    return action
                }
                return day
            }
            days["days"] = entries
            detail["days"] = entries
        }
        for selection in selections {
            assertNoLocalOverlay(TripExpeditionPresentation(source: source, selection: selection, demoScenesEnabled: true))
        }
    }

    func testMissingDisplayedKeyPointRejectsYadingMapping() throws {
        for (index, name) in ["过河", "4900垭口", "4700垭口", "蝴蝶石", "松多垭口"].enumerated() {
            var removedCount = 0
            let source = try fixture { detail, days in
                var entries = days["days"] as! [[String: Any]]
                let points = entries[index]["points"] as! [[String: Any]]
                let remaining = points.filter { !(($0["name"] as? String)?.contains(name) ?? false) }
                removedCount = points.count - remaining.count
                entries[index]["points"] = remaining
                days["days"] = entries
                detail["days"] = entries
            }
            XCTAssertGreaterThan(removedCount, 0, "反例必须实际删除所展示关键点：\(name)")
            let scene = TripExpeditionPresentation(source: source, selection: .day(index + 1), demoScenesEnabled: true)
            assertNoLocalOverlay(scene)
        }
    }

    func testEachDailyProfileUsesItsActualTrackSubsequenceAndStartsAtZero() throws {
        let source = try fixture()
        let basis = source.detail.trip.frozenRouteBasis
        let full = try XCTUnwrap(basis.elevationProfile)
        XCTAssertEqual(full.samples.count, basis.mainTrackPath.count)
        var previousEnd = -1
        for day in source.days.days {
            let hike = try XCTUnwrap(day.actions.first { $0.actionType == "hike" })
            let path = try XCTUnwrap(hike.routeSectionSnapshot?.path)
            let first = try XCTUnwrap(path.first)
            let start = try XCTUnwrap(basis.mainTrackPath.indices.first {
                $0 > previousEnd && basis.mainTrackPath[$0] == first
            })
            let end = start + path.count - 1
            XCTAssertEqual(Array(basis.mainTrackPath[start...end]), path)
            let scene = TripExpeditionPresentation(source: source, selection: .day(day.dayNumber), demoScenesEnabled: true)
            let profile = try XCTUnwrap(scene.elevationProfile)
            XCTAssertEqual(profile.samples.count, path.count)
            XCTAssertEqual(profile.samples.first?.distance.meters, 0)
            XCTAssertEqual(profile.samples.map(\.elevation), Array(full.samples[start...end]).map(\.elevation))
            XCTAssertEqual(try XCTUnwrap(profile.samples.last).distance.meters,
                           full.samples[end].distance.meters - full.samples[start].distance.meters, accuracy: 0.001)
            XCTAssertEqual(profile.minElevation.meters, try XCTUnwrap(profile.samples.map(\.elevation.meters).min()))
            XCTAssertEqual(profile.maxElevation.meters, try XCTUnwrap(profile.samples.map(\.elevation.meters).max()))
            XCTAssertNil(scene.metrics.first { $0.id == "descent" }?.value,
                         "当前行动合同没有下降，不能从艺术图或全程下降补数")
            previousEnd = end
        }
    }

    func testChangedDailyPathCannotKeepAnUnrelatedElevationProfile() throws {
        let source = try fixture { detail, days in
            var entries = days["days"] as! [[String: Any]]
            var actions = entries[2]["actions"] as! [[String: Any]]
            let index = actions.firstIndex { ($0["actionType"] as? String) == "hike" }!
            var section = actions[index]["routeSectionSnapshot"] as! [String: Any]
            var path = section["path"] as! [[String: Any]]
            path.remove(at: path.count / 2)
            section["path"] = path
            actions[index]["routeSectionSnapshot"] = section
            entries[2]["actions"] = actions
            days["days"] = entries
            detail["days"] = entries
        }
        let scene = TripExpeditionPresentation(source: source, selection: .day(3), demoScenesEnabled: true)
        XCTAssertNil(scene.elevationProfile)
        for selection in selections {
            assertNoLocalOverlay(TripExpeditionPresentation(source: source, selection: selection, demoScenesEnabled: true))
        }
    }

    private var selections: [TripExpeditionSelection] { [.overview] + (1...5).map { .day($0) } }

    private func placeNames(_ day: PersonalTripDay) -> [String] {
        (day.points ?? []).compactMap(\.name) + day.actions.flatMap { action in
            [action.start?.value?.name, action.end?.value?.name,
             action.routeSectionSnapshot?.start.name, action.routeSectionSnapshot?.end.name].compactMap { $0 }
        }
    }

    private func assertLocalOverlay(_ scene: TripExpeditionPresentation, names: [String],
                                    file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertTrue(scene.isDemoScene, file: file, line: line)
        XCTAssertEqual(scene.artwork, .bundledAsset(scene.assetName), file: file, line: line)
        XCTAssertGreaterThanOrEqual(scene.landmarks.count, 3, "每张既有艺术图至少叠加三个关键节点，不锁定数量或坐标", file: file, line: line)
        XCTAssertGreaterThanOrEqual(scene.routePath.count, 3, file: file, line: line)
        XCTAssertEqual(Set(scene.landmarks.map(\.id)).count, scene.landmarks.count, file: file, line: line)
        let forbidden = ["老榆林", "日乌且溪", "下日乌且营地", "日乌且垭口", "草科"]
        var previousIndex = -1
        for landmark in scene.landmarks {
            XCTAssertFalse(landmark.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, file: file, line: line)
            XCTAssertTrue(names.contains { $0.contains(landmark.title) }, "关键点名称必须来自当前亚丁范围：\(landmark.title)", file: file, line: line)
            XCTAssertFalse(forbidden.contains { landmark.title.contains($0) }, "不能借用贡嘎样例节点", file: file, line: line)
            XCTAssertTrue(landmark.x.isFinite && (0...1).contains(landmark.x), file: file, line: line)
            XCTAssertTrue(landmark.y.isFinite && (0...1).contains(landmark.y), file: file, line: line)
            let point = TripExpeditionScenePoint(x: landmark.x, y: landmark.y)
            let index = try XCTUnwrap(scene.routePath.indices.first { $0 > previousIndex && scene.routePath[$0] == point },
                                     "示意路径须依次连接全部节点，不锁定美术坐标", file: file, line: line)
            previousIndex = index
        }
        for point in scene.routePath {
            XCTAssertTrue(point.x.isFinite && (0...1).contains(point.x), file: file, line: line)
            XCTAssertTrue(point.y.isFinite && (0...1).contains(point.y), file: file, line: line)
        }
        let projection = TripExpeditionSceneProjection(presentation: scene)
        XCTAssertEqual(projection.landmarks, scene.landmarks, file: file, line: line)
        XCTAssertEqual(projection.routePath, scene.routePath, file: file, line: line)
    }

    private func assertNoLocalOverlay(_ scene: TripExpeditionPresentation,
                                      file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(scene.isDemoScene, file: file, line: line)
        XCTAssertEqual(scene.assetName, "TripExpeditionCover", file: file, line: line)
        XCTAssertTrue(scene.routePath.isEmpty, file: file, line: line)
        XCTAssertTrue(scene.landmarks.isEmpty, file: file, line: line)
        let projection = TripExpeditionSceneProjection(presentation: scene)
        XCTAssertTrue(projection.routePath.isEmpty, file: file, line: line)
        XCTAssertTrue(projection.landmarks.isEmpty, file: file, line: line)
    }

    private func remoteScenes(_ source: TripDetailPresentation) -> PersonalTripScenes {
        func image(_ id: String) -> SceneImage {
            .init(mediaID: id, imageURL: "https://scene.example.invalid/\(id).png", width: 1448, height: 1086, kind: .aigc)
        }
        return .init(tripID: source.detail.trip.identity, tripRevision: source.detail.revision,
                     routeVersionID: source.detail.routeReference.adoptedRouteVersionID, sceneRevision: "remote-test",
                     overview: image("overview"), days: source.days.days.map { .init(tripDayID: $0.identity, image: image($0.identity)) })
    }

    private func fixture(
        mutate: (inout [String: Any], inout [String: Any]) -> Void = { _, _ in }
    ) throws -> TripDetailPresentation {
        let fixtures = DefaultMockFixtures.all(bundle: .main)
        let detailData = try XCTUnwrap(fixtures[PersonalTripAPI.Detail(tripID: "trip-yading-5d").identifier])
        let daysData = try XCTUnwrap(fixtures[PersonalTripAPI.Days(tripID: "trip-yading-5d").identifier])
        var detailJSON = (try JSONSerialization.jsonObject(with: detailData) as! [String: Any])["data"] as! [String: Any]
        var daysJSON = (try JSONSerialization.jsonObject(with: daysData) as! [String: Any])["data"] as! [String: Any]
        mutate(&detailJSON, &daysJSON)
        let detail = try APIJSONDecoder.decode(PersonalTripDetail.self, from: JSONSerialization.data(withJSONObject: ["data": detailJSON]), envelope: .data)
        let days = try APIJSONDecoder.decode(PersonalTripDays.self, from: JSONSerialization.data(withJSONObject: ["data": daysJSON]), envelope: .data)
        return TripDetailPresentation(detail: detail, days: days, routeVersionStatus: detail.routeVersionStatus)
    }
}
