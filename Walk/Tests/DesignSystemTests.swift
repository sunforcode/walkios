import SwiftUI
import XCTest
@testable import Walk

@MainActor
final class DesignSystemTests: XCTestCase {
    func testSpacingAndRadiusTokensMatchFlutterValues() {
        XCTAssertEqual(Spacing.xs, 4)
        XCTAssertEqual(Spacing.sm, 8)
        XCTAssertEqual(Spacing.md, 12)
        XCTAssertEqual(Spacing.lg, 16)
        XCTAssertEqual(Spacing.xl, 24)
        XCTAssertEqual(Spacing.xxl, 32)
        XCTAssertEqual(Spacing.xxxl, 48)
        XCTAssertEqual(Spacing.hero, 80)
        XCTAssertEqual(Spacing.pageHorizontal, 16)
        XCTAssertEqual(Spacing.heroHorizontal, 20)
        XCTAssertEqual(Spacing.pageVertical, 16)
        XCTAssertEqual(Spacing.componentPadding, 16)
        XCTAssertEqual(Spacing.listItemGap, 12)
        XCTAssertEqual(Spacing.sectionGap, 24)
        XCTAssertEqual(Spacing.navBarHeight, 44)

        XCTAssertEqual(Radius.none, 0)
        XCTAssertEqual(Radius.sm, 8)
        XCTAssertEqual(Radius.md, 12)
        XCTAssertEqual(Radius.lg, 16)
        XCTAssertEqual(Radius.xl, 24)
        XCTAssertEqual(Radius.full, 9_999)
    }

    func testShadowTokensMatchFlutterValues() {
        XCTAssertEqual(AppShadow.floating.opacity, 0.2)
        XCTAssertEqual(AppShadow.floating.radius, 8)
        XCTAssertEqual(AppShadow.floating.x, 0)
        XCTAssertEqual(AppShadow.floating.y, 2)
        XCTAssertEqual(AppShadow.panel.opacity, 0.3)
        XCTAssertEqual(AppShadow.panel.radius, 16)
        XCTAssertEqual(AppShadow.panel.x, 0)
        XCTAssertEqual(AppShadow.panel.y, 4)
        XCTAssertEqual(AppShadow.overlay.opacity, 0.4)
        XCTAssertEqual(AppShadow.overlay.radius, 24)
        XCTAssertEqual(AppShadow.overlay.x, 0)
        XCTAssertEqual(AppShadow.overlay.y, 8)
    }

    func testPrimaryTypographyTokensAreConstructible() {
        _ = Text("Hero").font(AppTypography.heroTitle)
        _ = Text("Hero subtitle").font(AppTypography.heroSubtitle)
        _ = Text("Display").font(AppTypography.displayTitle)
        _ = Text("Page").font(AppTypography.pageTitle)
        _ = Text("Section").font(AppTypography.sectionTitle)
        _ = Text("Card").font(AppTypography.cardTitle)
        _ = Text("Body").font(AppTypography.bodyLarge)
        _ = Text("Metric").font(AppTypography.metricValue)
        _ = Text("Unit").font(AppTypography.metricUnit)
    }

    func testCanonicalColorsMatchFlutterRGBAValues() {
        assertColor(AppColors.bgBase, red: 10, green: 10, blue: 26)
        assertColor(AppColors.bgMap, red: 13, green: 27, blue: 42)
        assertColor(AppColors.bgGradientEnd, red: 27, green: 40, blue: 56)
        assertColor(AppColors.bgPanel, red: 26, green: 26, blue: 46)
        assertColor(AppColors.bgDrawer, red: 17, green: 17, blue: 34)
        assertColor(AppColors.brandStart, red: 59, green: 130, blue: 246)
        assertColor(AppColors.brandEnd, red: 99, green: 102, blue: 241)
        assertColor(AppColors.interactiveAccent, red: 100, green: 200, blue: 255)
        assertColor(AppColors.success, red: 76, green: 175, blue: 80)
        assertColor(AppColors.warning, red: 255, green: 183, blue: 77)
        assertColor(AppColors.error, red: 255, green: 100, blue: 100)
        assertColor(AppColors.statusCompleted, red: 192, green: 132, blue: 252)
        assertColor(AppColors.textSecondary, red: 255, green: 255, blue: 255, alpha: 0.70)
        assertColor(AppColors.surfaceCard, red: 255, green: 255, blue: 255, alpha: 0.06)
        assertColor(AppColors.surfaceInput, red: 255, green: 255, blue: 255, alpha: 0.04)
        assertColor(AppColors.interactiveAccentBackground, red: 100, green: 200, blue: 255, alpha: 0.12)
        assertColor(AppColors.statusPlanningBackground, red: 245, green: 158, blue: 11, alpha: 0.15)
        assertColor(AppColors.sheetBackground, red: 255, green: 255, blue: 255)
        assertColor(AppColors.sheetTextSecondary, red: 136, green: 136, blue: 136)
        assertColor(AppColors.sheetDivider, red: 0, green: 0, blue: 0, alpha: 0.06)
    }

    func testSharedPrimitivesAreConstructible() {
        _ = WalkPanel { Text("Panel") }
        _ = WalkPill { Text("Pill") }
        _ = GlassIconButton(systemName: "xmark", action: {})
        _ = UtilityPageContainer { Text("Utility") }
        _ = ImmersivePageContainer { Text("Immersive") }
        _ = LoadingView()
        _ = StatCardView(title: "Trips", value: "12")
    }

    func testStatusViewsProvideTheirOwnDarkContainers() {
        _ = ErrorView(message: "Error").body
        _ = EmptyStateView(title: "Empty").body
    }

    func testRouteCardHeightUsesViewportRatioAndClampsToFlutterBounds() {
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 500), 400)
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 800), 576)
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 1_200), 680)
    }

    func testRouteDetailStartsWithExplicitEmptyTrackState() {
        let viewModel = RouteDetailViewModel(service: EmptyRouteDetailServiceStub())

        XCTAssertTrue(viewModel.mapCoordinates.isEmpty)
        XCTAssertFalse(viewModel.hasMissingTrack)
    }

    private final class EmptyRouteDetailServiceStub: RouteDetailServicing {
        func getRouteDetailResponse(id: String) async throws -> RouteDetailResponse {
            throw APIClientError.mockNotFound(id)
        }

        func setFavorite(routeID: String, isFavorite: Bool) async throws {}
    }

    func testTripStatusColorsMatchFlutterRGBAValues() {
        assertColor(TripStatus.planning.color, red: 251, green: 191, blue: 36)
        assertColor(TripStatus.planning.backgroundColor, red: 245, green: 158, blue: 11, alpha: 0.15)
        assertColor(TripStatus.inProgress.color, red: 74, green: 222, blue: 128)
        assertColor(TripStatus.inProgress.backgroundColor, red: 34, green: 197, blue: 94, alpha: 0.12)
        assertColor(TripStatus.completed.color, red: 192, green: 132, blue: 252)
        assertColor(TripStatus.completed.backgroundColor, red: 168, green: 85, blue: 247, alpha: 0.12)
        assertColor(TripStatus.cancelled.color, red: 248, green: 113, blue: 113)
        assertColor(TripStatus.cancelled.backgroundColor, red: 239, green: 68, blue: 68, alpha: 0.10)
    }

    func testTripLayoutMatchesFlutterDimensions() {
        XCTAssertEqual(TripLayout.listCoverHeight, 120)
        XCTAssertEqual(TripLayout.detailMapHeight, 220)
        XCTAssertEqual(TripLayout.detailCoverHeight, 260)
        XCTAssertEqual(TripLayout.cardCornerRadius, 16)
    }

    func testTripDetailCoordinatesFollowBuildConfigurationPolicy() {
        #if DEBUG
        XCTAssertEqual(
            TripDetailViewModel.fallbackCoordinates.map(\.latitude),
            MockData.wutaiShanCoordinates.map(\.latitude)
        )
        #else
        XCTAssertTrue(TripDetailViewModel.fallbackCoordinates.isEmpty)
        #endif
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
