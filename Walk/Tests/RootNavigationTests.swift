import SwiftUI
import XCTest
@testable import Walk

@MainActor
final class RootNavigationTests: XCTestCase {
    func testRootNavigationUsesFlutterDrawerPresentation() {
        XCTAssertEqual(RootNavigation.drawerWidth, 280)
        XCTAssertEqual(RootNavigation.drawerOverlayOpacity, 0.50)
        XCTAssertEqual(RootNavigation.profileDestination, .profile)
    }

    func testDrawerStyleMatchesFlutterValues() {
        assertColor(DrawerStyle.backgroundColor, red: 17, green: 17, blue: 34)
        assertColor(DrawerStyle.brandSubtitleColor, red: 255, green: 255, blue: 255, alpha: 0.50)
        XCTAssertEqual(DrawerStyle.brandTitle, "WALK")
        XCTAssertEqual(DrawerStyle.brandSubtitle, "徒步旅行助手")
        XCTAssertEqual(DrawerStyle.brandSpacing, 6)
        XCTAssertEqual(DrawerStyle.brandTitleFontSize, 42)
        XCTAssertEqual(DrawerStyle.brandTitleFontWeight, .heavy)
        XCTAssertEqual(DrawerStyle.columnCount, 3)
        XCTAssertEqual(DrawerStyle.gridGap, 8)
        XCTAssertEqual(DrawerStyle.cellAspectRatio, 1)
        XCTAssertEqual(DrawerStyle.cellBorderWidth, 0.5)
    }

    func testHomeGradientMatchesFlutterAlignmentAndStops() {
        XCTAssertEqual(HomeStyle.gradientStops.map(\.location), [0, 0.4, 1])
        XCTAssertEqual(HomeStyle.gradientStartPoint, UnitPoint(x: 0.25, y: 0))
        XCTAssertEqual(HomeStyle.gradientEndPoint, UnitPoint(x: 0.75, y: 1))
        XCTAssertEqual(HomeStyle.gradientStops.count, 3)
        assertColor(HomeStyle.gradientStops[0].color, red: 10, green: 10, blue: 26)
        assertColor(HomeStyle.gradientStops[1].color, red: 13, green: 27, blue: 42)
        assertColor(HomeStyle.gradientStops[2].color, red: 27, green: 40, blue: 56)
    }

    func testHomeUsesNeutralWeatherPlaceholderWithoutWeatherService() {
        XCTAssertEqual(HomeStyle.weatherPlaceholder, "天气 --")
        XCTAssertFalse(HomeStyle.weatherPlaceholder.contains("晴"))
        XCTAssertFalse(HomeStyle.weatherPlaceholder.contains("18℃"))
    }

    func testDrawerContainsExpectedEntriesInOrder() {
        XCTAssertEqual(
            DrawerItem.allCases.map(\.title),
            ["路线", "我的行程", "攻略", "装备", "天气", "日历", "统计", "导航", "附近"]
        )
    }

    func testOnlyImplementedDrawerEntriesHaveDestinations() {
        XCTAssertEqual(
            DrawerItem.allCases.filter(\.isAvailable),
            [.routes, .trips, .guides, .equipment]
        )
        XCTAssertNil(DrawerItem.weather.destination)
        XCTAssertNil(DrawerItem.calendar.destination)
        XCTAssertNil(DrawerItem.statistics.destination)
        XCTAssertNil(DrawerItem.navigation.destination)
        XCTAssertNil(DrawerItem.nearby.destination)
    }

    func testHomeNavigationTargetsAreTypeSafe() {
        XCTAssertEqual(RootDestination.profile, .profile)
        XCTAssertEqual(RootDestination.routeDetail("route-1"), .routeDetail("route-1"))
        XCTAssertEqual(RootDestination.navigation, .navigation)
        XCTAssertEqual(HomePresentation.routePickerTransition, .opacity)
    }

    private func assertColor(
        _ color: Color,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        alpha: CGFloat = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let uiColor = UIColor(color)
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var actualAlpha: CGFloat = 0
        XCTAssertTrue(
            uiColor.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &actualAlpha),
            file: file,
            line: line
        )
        XCTAssertEqual(actualRed, red / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualGreen, green / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualBlue, blue / 255, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualAlpha, alpha, accuracy: 0.001, file: file, line: line)
    }
}
