import XCTest
import WalkData
@testable import Walk

/// 天气入口可用性行为（openspec change: ui-component-restructure → app-flow）：
/// 「天气结果可用时天气入口必须呈现」——不因内部数据装配方式静默省略。
@MainActor
final class TripDetailPresentationTests: XCTestCase {
    func testWeatherEntryIsPresentedWhenWeatherResultsAreAvailable() throws {
        let fixture = try BaselineFixtureProvider.tripDetailFixture(
            for: .pageTripDetailDefaultTop
        )

        // 页面只装配 detail + days；天气摘要从冻结自然日派生。
        let presentation = TripDetailPresentation(
            detail: fixture.detail,
            days: fixture.days,
            routeVersionStatus: fixture.detail.routeVersionStatus
        )

        let weatherProjection = try XCTUnwrap(
            presentation.weatherSummaryProjection,
            "天气结果可用时必须呈现可激活的整趟天气入口，不因装配方式静默省略"
        )
        XCTAssertEqual(weatherProjection.samples.count, fixture.days.days.count)
    }

    func testWeatherEntryOmittedOnlyWhenNoDayCarriesASample() throws {
        let fixture = try BaselineFixtureProvider.tripDetailFixture(
            for: .pageTripDetailWeatherUnavailable
        )

        let presentation = TripDetailPresentation(
            detail: fixture.detail,
            days: fixture.days,
            routeVersionStatus: fixture.detail.routeVersionStatus
        )

        // 逐日样本整体不可用时，不渲染空图，入口交给页面不可用块。
        let allSamplesUnavailable = fixture.days.days.allSatisfy { day in
            day.weather.condition.value == nil
                && day.weather.temperatureRange.value == nil
                && day.weather.precipitation.value == nil
        }
        if allSamplesUnavailable {
            XCTAssertNil(presentation.weatherSummaryProjection)
        } else {
            XCTAssertNotNil(presentation.weatherSummaryProjection)
        }
    }
}
