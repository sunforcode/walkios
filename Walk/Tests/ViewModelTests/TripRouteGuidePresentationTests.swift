import XCTest
import SwiftUI
import WalkData
@testable import Walk

@MainActor
final class TripRouteGuidePresentationTests: XCTestCase {
    func testStructuredReferenceTitleAndPlacesKeepTheirSourceAndUncertainty() throws {
        let guide = PersonalTripRouteGuide(sourceReferenceDayID: "reference-day",
            title: .init(value: "翻越垭口到湖畔营地", confidence: .init(status: "pending_verification", category: .publicRouteFact, source: "原轨迹记录")),
            start: .init(value: .init(name: "原记录起点"), confidence: .init(status: "pending_verification", category: .publicRouteFact)),
            end: .init(value: nil, confidence: .init(status: "unknown", category: .publicRouteFact)))
        let projection = TripRouteGuideProjection(guide: guide)
        XCTAssertEqual(projection.fields.map(\.title), ["参考走法", "参考起点", "参考终点"])
        XCTAssertEqual(projection.fields[0].value, "翻越垭口到湖畔营地")
        XCTAssertEqual(projection.fields[0].source, "原轨迹记录")
        XCTAssertEqual(projection.fields[0].notices, ["参考走法：待核验"])
        XCTAssertEqual(projection.fields[1].value, "原记录起点")
        XCTAssertNil(projection.fields[2].value)
        XCTAssertEqual(projection.fields[2].notices, ["参考终点：信息未知"])
    }

    func testGuideUsesFrozenTextAndPreservesUncertaintyAndSource() throws {
        let guide = try fixtureGuide()
        let projection = TripRouteGuideProjection(guide: guide)
        XCTAssertEqual(projection.fields.map(\.id), ["description", "notes", "accommodation", "reference-track"])
        XCTAssertEqual(projection.fields[0].value, guide.description?.value)
        XCTAssertEqual(projection.fields[0].source, "作者历史记录")
        XCTAssertTrue(projection.fields[0].notices.contains("参考说明：待核验"))
        XCTAssertTrue(projection.fields[1].notices.contains("注意事项：信息已过期"))
        XCTAssertNil(projection.fields[2].value)
        XCTAssertTrue(projection.fields[2].notices.contains("住宿参考：信息未知"))
        XCTAssertEqual(projection.fields[3].title, "参考日行进")
        XCTAssertTrue(projection.fields[3].scopeNote?.contains("不等同于实际徒步指标") == true)
        XCTAssertTrue(projection.fields[3].value?.contains("9.2 km") == true)
        XCTAssertTrue(projection.fields[3].value?.contains("参考轨迹") == true)
    }

    func testGuideIsAnIndependentDayBlockAndDoesNotPopulateHikeMetricsOrRewriteDays() throws {
        let day = try fixtureDay()
        let blocks = TripBrowsePagePlan.blocks(for: day)
        let hike = blocks.compactMap { block -> TripDayHikeSummaryProjection? in
            if case let .hike(summary, _, _) = block { return summary }
            return nil
        }.first
        XCTAssertNotNil(hike)
        XCTAssertEqual(hike?.segment, "徒步区段待确认")
        XCTAssertNil(hike?.distance)
        XCTAssertNil(hike?.ascent)
        XCTAssertNil(hike?.duration)
        let guides = blocks.compactMap { block -> TripRouteGuideProjection? in
            if case let .routeGuide(guide) = block { return guide }
            return nil
        }
        XCTAssertEqual(guides.count, 1)
        XCTAssertEqual(guides.first?.fields.first?.value, day.routeGuide?.description?.value)
        if case .weather = blocks.last { } else { XCTFail("天气仍位于日内容末尾") }
        XCTAssertEqual(day.identity, "actual-day")
        XCTAssertEqual(day.dayNumber, 3)
        XCTAssertEqual(day.routeGuide?.sourceReferenceDayID, "reference-day-1")
        XCTAssertEqual(day.date.description, "2026-10-03")
    }

    func testUnavailableHikeSectionHasItsOwnNoticeEvenWithNoValues() throws {
        let day = try fixtureDay()
        let action = try XCTUnwrap(day.actions.first)
        let presentation = TripActionPresentation(action: action)
        XCTAssertTrue(presentation.statusNotices.map(\.message).contains("徒步路段：信息不可用"))
        XCTAssertTrue(presentation.details.isEmpty)
        let component = try String(contentsOf: URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Features/Trips/Components/TripDayArrangement.swift"), encoding: .utf8)
        XCTAssertTrue(component.contains("!rows.isEmpty || !notices.isEmpty"), "仅有不确定提示时也应渲染，不依赖已知行动值")
    }

    func testAbsentGuideDoesNotCreateReferenceContent() throws {
        let fixtures = DefaultMockFixtures.all(bundle: .main)
        let data = try XCTUnwrap(fixtures[PersonalTripAPI.Days(tripID: "trip-yading-5d").identifier])
        let days = try APIJSONDecoder.decode(PersonalTripDays.self, from: data, envelope: .data)
        for day in days.days {
            XCTAssertNil(day.routeGuide)
            XCTAssertFalse(TripBrowsePagePlan.blocks(for: day).contains { if case .routeGuide = $0 { return true }; return false })
        }
    }

    func testLongGuideCanExpandBeyondOneScreenInTheProductionDayContent() throws {
        let guide = TripDayArrangementProjection.referenceGuideLong
        let page = TripBrowsePage(tripDayID: "long-day", dayNumber: 1, date: "10月1日",
                                 primaryStage: "长攻略阅读", blocks: guide.blocks, hasContent: true)
        let regular = UIHostingController(rootView: TripBrowsePageView(page: page).environment(\.dynamicTypeSize, .large))
        let accessible = UIHostingController(rootView: TripBrowsePageView(page: page).environment(\.dynamicTypeSize, .accessibility2))
        let proposal = CGSize(width: 390, height: CGFloat.greatestFiniteMagnitude)
        let regularHeight = regular.sizeThatFits(in: proposal).height
        let accessibleHeight = accessible.sizeThatFits(in: proposal).height
        XCTAssertGreaterThan(regularHeight, 844, "日内容应按完整攻略增长，交给已有内层CollectionView滚动")
        XCTAssertGreaterThan(accessibleHeight, regularHeight, "可访问字号不能通过裁切或压缩保持单屏高度")
    }

    private func fixtureGuide() throws -> PersonalTripRouteGuide {
        try JSONDecoder().decode(PersonalTripRouteGuide.self, from: Data(guideJSON.utf8))
    }

    private func fixtureDay() throws -> PersonalTripDay {
        let missing = InformationConfidence(status: "unavailable", category: .generatedSuggestion)
        let weather = InformationConfidence(status: "unavailable", category: .dynamicExternalInformation)
        return PersonalTripDay(identity: "actual-day", dayNumber: 3, date: LocalDate(year: 2026, month: 10, day: 3), primaryStage: "混合接驳与进山", hikingDayNumber: 1,
            actions: [.init(sequence: 1, actionType: "hike", origin: nil, destination: nil, mode: nil, keyTimes: nil, estimatedDuration: .init(value: nil, confidence: missing), transferNotes: nil, routeSectionSnapshot: nil, start: .init(value: nil, confidence: missing), end: .init(value: nil, confidence: missing), distance: .init(value: nil, confidence: missing), ascent: .init(value: nil, confidence: missing), routeSectionConfidence: missing)],
            weather: .init(condition: .init(value: nil, confidence: weather), temperatureRange: .init(value: nil, confidence: weather), precipitation: .init(value: nil, confidence: weather), wind: .init(value: nil, confidence: weather), placeContext: .init(value: nil, confidence: weather), routeSectionContext: nil, source: nil, updatedAt: nil), points: nil, routeGuide: try fixtureGuide())
    }

    private var guideJSON: String {
        #"{"sourceReferenceDayId":"reference-day-1","description":{"value":"原记录包含接驳与湖畔扎营，路况和营地均需核验。","confidence":{"status":"pending_verification","category":"public_route_fact","source":"作者历史记录"}},"notes":{"value":"历史费用和道路开放情况不能视为当前信息。","confidence":{"status":"stale","category":"public_route_fact"}},"accommodationReference":{"confidence":{"status":"unknown","category":"public_route_fact"}},"referenceTrack":{"path":[{"latitude":28.4,"longitude":100.3,"referenceSystem":"WGS84"},{"latitude":28.5,"longitude":100.4,"referenceSystem":"WGS84"}],"distance":{"meters":9240},"ascent":{"meters":700},"descent":{"meters":120},"estimatedDuration":{"seconds":15480},"confidence":{"status":"pending_verification","category":"public_route_fact","source":"参考日历史记录"}}}"#
    }
}
