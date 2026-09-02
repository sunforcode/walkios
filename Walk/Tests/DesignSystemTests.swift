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

    func testCanonicalColorsMatchGreenBlackThemeContract() {
        assertColor(AppColors.pageBase, red: 4, green: 12, blue: 8)
        assertColor(AppColors.pageMiddle, red: 7, green: 19, blue: 15)
        assertColor(AppColors.pageOuter, red: 13, green: 31, blue: 24)
        assertColor(AppColors.surfacePrimary, red: 16, green: 35, blue: 27)
        assertColor(AppColors.surfaceElevated, red: 23, green: 49, blue: 38)
        assertColor(AppColors.surfaceGlass, red: 255, green: 255, blue: 255, alpha: 0.12)
        assertColor(AppColors.surfaceInput, red: 255, green: 255, blue: 255, alpha: 0.04)
        assertColor(AppColors.surfaceDivider, red: 255, green: 255, blue: 255, alpha: 0.04)
        assertColor(AppColors.surfaceOverlay, red: 0, green: 0, blue: 0, alpha: 0.50)
        assertColor(AppColors.surfaceToast, red: 0, green: 0, blue: 0, alpha: 0.80)
        assertColor(AppColors.textPrimary, red: 255, green: 255, blue: 255)
        assertColor(AppColors.textSecondary, red: 184, green: 194, blue: 189)
        assertColor(AppColors.textWeak, red: 143, green: 154, blue: 149)
        assertColor(AppColors.interactionPrimary, red: 139, green: 214, blue: 173)
        assertColor(AppColors.interactionBackground, red: 139, green: 214, blue: 173, alpha: 0.12)
        assertColor(AppColors.interactionFocus, red: 139, green: 214, blue: 173, alpha: 0.30)
        assertColor(AppColors.borderPrimary, red: 113, green: 135, blue: 123)
        assertColor(AppColors.borderStrong, red: 143, green: 163, blue: 153)
        assertColor(AppColors.shadowCard, red: 0, green: 0, blue: 0, alpha: 0.25)
        assertColor(AppColors.shadowOverlay, red: 0, green: 0, blue: 0, alpha: 0.40)
        assertColor(AppColors.statusPlanning, red: 251, green: 191, blue: 36)
        assertColor(AppColors.statusPlanningBackground, red: 245, green: 158, blue: 11, alpha: 0.15)
        assertColor(AppColors.statusConfirmed, red: 96, green: 165, blue: 250)
        assertColor(AppColors.statusConfirmedBackground, red: 59, green: 130, blue: 246, alpha: 0.15)
        assertColor(AppColors.statusProgress, red: 74, green: 222, blue: 128)
        assertColor(AppColors.statusProgressBackground, red: 34, green: 197, blue: 94, alpha: 0.12)
        assertColor(AppColors.statusCompleted, red: 192, green: 132, blue: 252)
        assertColor(AppColors.statusCompletedBackground, red: 168, green: 85, blue: 247, alpha: 0.12)
        assertColor(AppColors.statusCancelled, red: 248, green: 113, blue: 113)
        assertColor(AppColors.statusCancelledBackground, red: 239, green: 68, blue: 68, alpha: 0.10)
        assertColor(AppColors.warning, red: 255, green: 183, blue: 77)
        assertColor(AppColors.mapRoute, red: 139, green: 214, blue: 173)
        assertColor(AppColors.mapStart, red: 74, green: 222, blue: 128)
        assertColor(AppColors.mapEnd, red: 248, green: 113, blue: 113)
        assertColor(AppColors.mapWaypoint, red: 192, green: 132, blue: 252)
        assertColor(AppColors.mapPOI, red: 255, green: 183, blue: 77)
        assertColor(AppColors.sheetBackground, red: 0, green: 0, blue: 0, alpha: 0)
        assertColor(AppColors.sheetTextPrimary, red: 255, green: 255, blue: 255)
        assertColor(AppColors.sheetTextSecondary, red: 186, green: 205, blue: 194)
        assertColor(AppColors.sheetTextWeak, red: 151, green: 177, blue: 162)
        assertColor(AppColors.sheetTextTag, red: 210, green: 226, blue: 217)
        assertColor(AppColors.sheetDivider, red: 255, green: 255, blue: 255, alpha: 0.12)
        assertColor(AppColors.sheetDragHandle, red: 255, green: 255, blue: 255, alpha: 0.35)
        assertColor(AppColors.sheetTagBackground, red: 255, green: 255, blue: 255, alpha: 0.08)
        assertColor(AppColors.sheetCardBackground, red: 255, green: 255, blue: 255, alpha: 0.06)
        assertColor(AppColors.sheetSectionBackground, red: 20, green: 48, blue: 36)
        XCTAssertNotEqual(UIColor(AppColors.interactionPrimary), UIColor(AppColors.statusProgress))
    }

    func testThemeTextContrastMeetsContract() {
        let darkBackgrounds = [
            AppColors.pageBase,
            AppColors.pageMiddle,
            AppColors.pageOuter,
            AppColors.surfacePrimary,
            AppColors.surfaceElevated
        ]
        for background in darkBackgrounds {
            XCTAssertGreaterThanOrEqual(contrastRatio(AppColors.textPrimary, background), 4.5)
            XCTAssertGreaterThanOrEqual(contrastRatio(AppColors.textSecondary, background), 4.5)
            XCTAssertGreaterThanOrEqual(contrastRatio(AppColors.textWeak, background), 4.5)
            XCTAssertGreaterThanOrEqual(contrastRatio(AppColors.interactionPrimary, background), 3.0)
        }
        for surface in [AppColors.surfacePrimary, AppColors.surfaceElevated] {
            XCTAssertGreaterThanOrEqual(contrastRatio(AppColors.borderPrimary, surface), 3.0)
            XCTAssertGreaterThanOrEqual(contrastRatio(AppColors.borderStrong, surface), 3.0)
        }
        XCTAssertGreaterThanOrEqual(contrastRatio(AppColors.sheetTextPrimary, AppColors.sheetBackground), 4.5)
        XCTAssertGreaterThanOrEqual(contrastRatio(AppColors.sheetTextSecondary, AppColors.sheetBackground), 4.5)
        XCTAssertGreaterThanOrEqual(contrastRatio(AppColors.sheetTextWeak, AppColors.sheetBackground), 4.5)
        XCTAssertGreaterThanOrEqual(contrastRatio(AppColors.sheetTextTag, AppColors.sheetBackground), 4.5)
    }

    func testProductionUISourcesDoNotUseLegacyThemeEntries() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoots = ["App", "DesignSystem", "Features"].map { walkRoot.appendingPathComponent($0) }
        let prohibitedEverywhere = [
            "Color.groupedBackground", "Color.cardBackground", "Color.surfaceBackground",
            "Color.background", "Color.accent", "Color.primary", "AppColors.bgBase",
            "AppColors.bgMap", "AppColors.bgGradientEnd", "AppColors.bgPanel",
            "AppColors.bgDrawer", "AppColors.interactiveAccent", "AppColors.surfaceCard",
            "AppColors.routeOuter", "AppColors.routeMiddle", "AppColors.routeInner",
            "AppColors.accent", "AppColors.detailSheet"
        ]
        let prohibitedOutsideTokenDefinition = [
            #"\bColor\s*\("#,
            #"\bColor\.(white|black|clear|red|blue|green|orange|purple|pink|yellow|gray)\b"#,
            #"\bUIColor\.system[A-Z][A-Za-z0-9_]*\b"#,
            #"\.(ultraThin|thin|regular|thick|ultraThick)Material\b"#,
            #"\.(foregroundStyle|foregroundColor|tint|background|fill|stroke)\(\s*\.(primary|secondary|red|blue|green|orange|purple|pink|yellow|gray|black|white|clear)\b"#
        ]
        let fileManager = FileManager.default
        var violations: [String] = []

        for root in sourceRoots {
            guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
                let source = try String(contentsOf: fileURL, encoding: .utf8)
                let isTokenDefinition = fileURL.lastPathComponent == "Color+App.swift"
                for token in prohibitedEverywhere where source.contains(token) {
                    violations.append("\(fileURL.lastPathComponent): \(token)")
                }
                if !isTokenDefinition {
                    for pattern in prohibitedOutsideTokenDefinition where regexMatches(pattern, in: source) {
                        violations.append("\(fileURL.lastPathComponent): \(pattern)")
                    }
                }
                if fileURL.lastPathComponent != "RouteDetailView.swift", source.contains("AppColors.sheet") {
                    violations.append("\(fileURL.lastPathComponent): light reading token outside RouteDetailView")
                }
            }
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testPageHeroHeaderUsesThreeLineTextBudget() {
        XCTAssertEqual(PageHeroHeader.titleLineLimit, 2)
        XCTAssertEqual(PageHeroHeader.subtitleLineLimit, 1)
        _ = PageHeroHeader(title: "标题", subtitle: "副标题")
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

    func testHomeTripUsesBackgroundHitLayerBehindForegroundControls() throws {
        let source = try productionSource(at: "Features/Home/HomeView.swift")

        let hitLayer = try XCTUnwrap(source.range(of: ".onTapGesture(perform: onOpenTrip)"))
        let foreground = try XCTUnwrap(source.range(
            of: "VStack(alignment: .leading, spacing: Spacing.md)",
            range: hitLayer.upperBound..<source.endIndex
        ))
        XCTAssertLessThan(hitLayer.lowerBound, foreground.lowerBound)
        XCTAssertFalse(source.contains("Button(action: onOpenTrip)"))
    }

    func testStandardNavigationPagesUseSharedRootBackgroundContainer() throws {
        let equipmentSource = try productionSource(at: "Features/Equipment/EquipmentListView.swift")

        XCTAssertTrue(equipmentSource.contains("UtilityPageContainer"))
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

    func testRouteDetailHasNoIndependentMapStateAndListCanHighlightMap() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertFalse(source.contains("RouteDetailDrawerState"))
        XCTAssertFalse(source.contains("mapOnly"))
        XCTAssertFalse(source.contains("RouteDetailMapRecoveryZone"))
        XCTAssertTrue(source.contains("onSelectItem"))
        XCTAssertTrue(source.contains("togglePointHighlight"))
        XCTAssertTrue(source.contains("highlightedAnnotationIDs"))
    }

    func testRouteDetailSummaryUsesIconLedMetricPanelWithoutRepeatedLabels() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertTrue(source.contains("RouteDetailMetricPanel"))
        XCTAssertTrue(source.contains("metric.systemImage"))
        XCTAssertFalse(source.contains("Text(metric.0)"))
        XCTAssertFalse(source.contains("查看路线"))
    }

    func testRouteDetailKeepsEligibilityAwareGenerationActionOutsideScrollableContent() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertTrue(source.contains("RouteGenerationPrimaryAction"))
        XCTAssertTrue(source.contains("presentation.generationAction"))
        XCTAssertTrue(source.contains(".disabled(!action.isEnabled)"))
        XCTAssertTrue(source.contains("onGenerateTrip(routeId)"))
    }

    func testRouteDetailOverlayUsesFullScreenContinuousScrollWithoutDrawerState() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertTrue(source.contains("RouteDetailScrollOverlay"))
        XCTAssertTrue(source.contains(".frame(height: topSpacerHeight)"))
        XCTAssertFalse(source.contains("drawerState"))
        XCTAssertFalse(source.contains("overlayOffset"))
        XCTAssertFalse(source.contains("RouteDetailSheetPhysics"))
        XCTAssertFalse(source.contains("isScrollEnabled"))
        XCTAssertFalse(source.contains("case expanded"))
    }

    func testRouteDetailUsesOneFullScreenScrollOverlay() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertTrue(source.contains("RouteDetailScrollOverlay"))
        XCTAssertTrue(source.contains("topSpacerHeight"))
        XCTAssertTrue(source.contains(".frame(height: topSpacerHeight)"))
        XCTAssertFalse(source.contains("private struct RouteDetailDrawer: View"))
        XCTAssertFalse(source.contains("isScrollEnabled"))
        XCTAssertFalse(source.contains("case expanded"))
    }

    func testRouteSummaryMetricsUseOneSolidDarkGreenSection() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertTrue(source.contains("RouteDetailMetricPanel"))
        XCTAssertTrue(source.contains(".background(AppColors.sheetSectionBackground)"))
        XCTAssertFalse(source.contains("sheetSectionBorder"))
        XCTAssertFalse(source.contains("RouteDetailMetricCard"))
    }

    func testExpandedGroupsUseSolidSectionsWithTransparentGaps() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")

        XCTAssertTrue(source.contains("RouteDetailSectionContainer"))
        XCTAssertTrue(source.contains(".background(AppColors.sheetSectionBackground)"))
        XCTAssertTrue(source.contains("VStack(alignment: .leading, spacing: Spacing.xl)"))
        XCTAssertFalse(source.contains(".stroke(AppColors.sheetSectionBorder"))
        XCTAssertFalse(source.contains(".background(AppColors.sheetCardBackground)"))
    }

    private final class EmptyRouteDetailServiceStub: RouteDetailServicing {
        func getRouteDetail(id: String) async throws -> PublicRouteDetail {
            throw APIClientError.mockNotFound(id)
        }
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
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

    func testTripDetailDoesNotUseMockTrackFallback() throws {
        let source = try productionSource(at: "Features/Trips/TripDetailViewModel.swift")

        XCTAssertFalse(source.contains("MockData"))
        XCTAssertFalse(source.contains("fallbackCoordinates"))
        XCTAssertTrue(source.contains("frozenRouteBasis.mainTrackPath"))
    }

    private func regexMatches(_ pattern: String, in source: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
        return expression.firstMatch(
            in: source,
            range: NSRange(source.startIndex..<source.endIndex, in: source)
        ) != nil
    }

    private func contrastRatio(_ first: Color, _ second: Color) -> CGFloat {
        let firstLuminance = relativeLuminance(first)
        let secondLuminance = relativeLuminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05) / (min(firstLuminance, secondLuminance) + 0.05)
    }

    private func relativeLuminance(_ color: Color) -> CGFloat {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(red) + 0.7152 * linearize(green) + 0.0722 * linearize(blue)
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
