import SwiftUI
import XCTest
@testable import Walk

@MainActor
final class DesignSystemTests: XCTestCase {
    func testSpacingAndRadiusTokensMatchApprovedContract() {
        XCTAssertEqual(Spacing.xs, 4)
        XCTAssertEqual(Spacing.sm, 8)
        XCTAssertEqual(Spacing.md, 12)
        XCTAssertEqual(Spacing.lg, 16)
        XCTAssertEqual(Spacing.xl, 24)
        XCTAssertEqual(Spacing.xxl, 32)
        XCTAssertEqual(Spacing.xxxl, 48)
        XCTAssertEqual(Spacing.pageHorizontal, 16)
        XCTAssertEqual(Spacing.navBarHeight, 44)

        XCTAssertEqual(Radius.none, 0)
        XCTAssertEqual(Radius.sm, 8)
        XCTAssertEqual(Radius.md, 12)
        XCTAssertEqual(Radius.lg, 16)
        XCTAssertEqual(Radius.xl, 24)
        XCTAssertEqual(Radius.full, 9_999)
    }

    func testShadowTokensMatchApprovedContract() {
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
        _ = Text("Body large").font(AppTypography.bodyLarge)
        _ = Text("Body").font(AppTypography.appBody)
        _ = Text("Caption").font(AppTypography.appCaption)
        _ = Text("Metric").font(AppTypography.metricValue)
        _ = Text("Unit").font(AppTypography.metricUnit)
    }

    func testAppTypographyUsesApprovedContractCanonicalNames() throws {
        let source = try productionSource(at: "DesignSystem/Theme/Font+App.swift")

        XCTAssertTrue(source.contains("static let appBody = Font.system(size: 15, weight: .regular)"))
        XCTAssertTrue(source.contains("static let appCaption = Font.system(size: 13, weight: .regular)"))
        XCTAssertFalse(regexMatches(#"static let body\s*="#, in: source))
        XCTAssertFalse(regexMatches(#"static let caption\s*="#, in: source))
        XCTAssertFalse(regexMatches(#"AppTypography\.body\b"#, in: source))
        XCTAssertFalse(regexMatches(#"AppTypography\.caption\b"#, in: source))
    }

    func testFeatureSourcesUseTypographyTokensOnly() throws {
        let violations = try violations(in: "Features") { source in
            var found: [String] = []
            if regexMatches(#"\.system\(size:"#, in: source) {
                found.append("raw .system(size:) font; use AppTypography tokens or Font.ornament")
            }
            let bannedNames = "hero|display|page|section|card|nav|button|largeTitle|title|title2|headline|body|callout|subheadline|footnote|caption|caption2"
            if regexMatches("\\.font\\(\\.(" + bannedNames + ")\\b", in: source) {
                found.append("legacy font alias in .font(...); use canonical token names")
            }
            if regexMatches(#"AppTypography\.(body|caption)\b"#, in: source) {
                found.append("legacy AppTypography body/caption name; use appBody/appCaption")
            }
            return found
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testDesignSystemComponentsUseRegisteredTypographyOnly() throws {
        let violations = try violations(in: "DesignSystem/Components") { source in
            var found: [String] = []
            if regexMatches(#"\.system\(size:"#, in: source) {
                found.append("raw .system(size:) font; use AppTypography tokens or Font.ornament")
            }
            if regexMatches(#"\.font\(\.(body|caption|caption2)\b"#, in: source) {
                found.append("SwiftUI body/caption font; use canonical app token")
            }
            return found
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))

        let errorView = try productionSource(at: "DesignSystem/Components/ErrorView.swift")
        XCTAssertTrue(errorView.contains(".font(.ornament(48, weight: .regular))"))
        XCTAssertFalse(errorView.contains(".system(size: 48)"))
    }

    func testFeatureSourcesUseRadiusTokensOnly() throws {
        let violations = try violations(in: "Features") { source in
            regexMatches(#"cornerRadius:\s*\d"#, in: source)
                ? ["hardcoded cornerRadius; use Radius.* or Capsule"]
                : []
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testFeatureSourcesUseSemanticNonTripStatusColors() throws {
        let violations = try violations(in: "Features") { source in
            guard source.contains("AppColors.statusCancelled"),
                  !source.contains("struct TripStatusBadge: View") else {
                return []
            }
            return ["general error or destructive UI uses trip-cancelled color; use AppColors.danger"]
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testStatusBadgeHasSingleImplementation() throws {
        let featureRoot = try XCTUnwrap(walkRoot().appendingPathComponent("Features"))
        let fileManager = FileManager.default
        var declarations: [String] = []
        guard let enumerator = fileManager.enumerator(at: featureRoot, includingPropertiesForKeys: nil) else {
            return
        }
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            if let range = source.range(of: #"struct \w*StatusBadge\b"#, options: .regularExpression) {
                declarations.append("\(fileURL.lastPathComponent): \(source[range])")
            }
        }

        XCTAssertEqual(declarations, ["TripStatusBadge.swift: struct TripStatusBadge"])
    }

    private func walkRoot() throws -> URL {
        let testFileURL = URL(fileURLWithPath: #filePath)
        return testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func violations(
        in relativeDirectory: String,
        check: (String) -> [String]
    ) throws -> [String] {
        let directory = try XCTUnwrap(walkRoot().appendingPathComponent(relativeDirectory))
        let fileManager = FileManager.default
        var violations: [String] = []
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            return violations
        }
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            for violation in check(source) {
                violations.append("\(fileURL.lastPathComponent): \(violation)")
            }
        }
        return violations
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
        assertColor(AppColors.statusProgress, red: 74, green: 222, blue: 128)
        assertColor(AppColors.statusProgressBackground, red: 34, green: 197, blue: 94, alpha: 0.12)
        assertColor(AppColors.statusCompleted, red: 192, green: 132, blue: 252)
        assertColor(AppColors.statusCompletedBackground, red: 168, green: 85, blue: 247, alpha: 0.12)
        assertColor(AppColors.statusCancelled, red: 248, green: 113, blue: 113)
        assertColor(AppColors.statusCancelledBackground, red: 239, green: 68, blue: 68, alpha: 0.10)
        assertColor(AppColors.info, red: 96, green: 165, blue: 250)
        assertColor(AppColors.infoBackground, red: 59, green: 130, blue: 246, alpha: 0.15)
        assertColor(AppColors.warning, red: 255, green: 183, blue: 77)
        assertColor(AppColors.warningBackground, red: 255, green: 183, blue: 77, alpha: 0.12)
        assertColor(AppColors.danger, red: 248, green: 113, blue: 113)
        assertColor(AppColors.dangerBackground, red: 239, green: 68, blue: 68, alpha: 0.10)
        assertColor(AppColors.mapRoute, red: 139, green: 214, blue: 173)
        assertColor(AppColors.mapStart, red: 74, green: 222, blue: 128)
        assertColor(AppColors.mapEnd, red: 248, green: 113, blue: 113)
        assertColor(AppColors.mapWaypoint, red: 96, green: 165, blue: 250)
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
        _ = WalkPanel(variant: .default) { Text("Panel") }
        _ = WalkPanel(surface: .glass) { Text("Glass panel") }
        _ = WalkPill { Text("Pill") }
        _ = InfoTag(title: "已确认", tone: .info)
        _ = NoticeView(message: "信息待核验", tone: .warning)
        _ = UnavailableStateView(
            title: "结果不可用",
            message: "请稍后查看",
            icon: "exclamationmark.circle",
            actionTitle: "重试",
            action: {}
        )
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

    func testTextInputUsesApprovedTypographySurfaceAndRadius() throws {
        let source = try productionSource(at: "Features/Profile/ProfileEntryPages.swift")
        XCTAssertTrue(source.contains(".font(.appBody)"))
        XCTAssertTrue(source.contains(".background(AppColors.surfaceInput, in: RoundedRectangle(cornerRadius: Radius.md))"))
        XCTAssertFalse(source.contains("var prefix:"))
    }

    func testHomePilotComponentsHaveSingleProductionOwners() throws {
        let home = try productionSource(at: "Features/Home/HomeView.swift")
        XCTAssertFalse(home.contains("struct MetricItem:"))
        XCTAssertFalse(home.contains("struct MetricGroup<"))
        XCTAssertFalse(home.contains("struct WeatherSummary:"))
        XCTAssertFalse(home.contains("private struct FocusTripContent:"))
        XCTAssertTrue(home.contains("FocusTripSummary("))

        let metricItem = try productionSource(at: "DesignSystem/Components/MetricItem.swift")
        XCTAssertTrue(metricItem.contains("case `default`"))
        XCTAssertTrue(metricItem.contains("case inlineCompact"))
        XCTAssertTrue(metricItem.contains("case gridCompact"))
        XCTAssertFalse(metricItem.contains("minimumScaleFactor"))

        let metricGroup = try productionSource(at: "DesignSystem/Components/MetricGroup.swift")
        XCTAssertTrue(metricGroup.contains("dynamicTypeSize"))
        XCTAssertTrue(metricGroup.contains("ViewThatFits"))
        XCTAssertTrue(metricGroup.contains("MetricItem(model:"))

        let weather = try productionSource(at: "Features/Home/Components/WeatherSummary.swift")
        XCTAssertFalse(weather.contains("lineLimit(1)"))

        let focus = try productionSource(at: "Features/Home/Components/FocusTripSummary.swift")
        XCTAssertTrue(focus.contains("MetricGroup("))
        XCTAssertTrue(focus.contains("WeatherSummary("))
    }

    func testHomePilotFixtureCarriesApprovedDefaultBaselineValues() throws {
        let fixtures = try productionSource(at: "Preview Content/HomePreviewFixtures.swift")

        XCTAssertTrue(fixtures.contains("routeName: \"云岭环线\""))
        XCTAssertTrue(fixtures.contains("start: \"云栈口\""))
        XCTAssertTrue(fixtures.contains("end: \"云栈口\""))
        XCTAssertTrue(fixtures.contains("value: \"12.1\", unit: \"km\""))
        XCTAssertTrue(fixtures.contains("value: \"600\", unit: \"m\""))
        XCTAssertTrue(fixtures.contains("value: \"约 5 h 20 min\""))
        XCTAssertTrue(fixtures.contains("conclusion: \"16°·多云\""))
        XCTAssertTrue(fixtures.contains("impact: \"山脊4级风\""))
    }

    func testRootUsesTheProductionPrimaryTabBar() throws {
        let root = try productionSource(at: "App/RootView.swift")
        let tabBar = try productionSource(at: "DesignSystem/Components/PrimaryTabBar.swift")
        XCTAssertTrue(root.contains("PrimaryTabBar("))
        XCTAssertTrue(root.contains("shell.path(for: shell.selectedTab).isEmpty"))
        XCTAssertTrue(root.contains(".toolbar(.hidden, for: .tabBar)"))
        XCTAssertTrue(tabBar.contains("ForEach(items)"))
        XCTAssertTrue(tabBar.contains("static let height: CGFloat = 64"))
        XCTAssertTrue(tabBar.contains("static let cornerRadius: CGFloat = 22"))
        XCTAssertTrue(tabBar.contains("accessibilityAddTraits"))
    }

    func testHomePilotUsesRegisteredVisualTokens() throws {
        let colors = try productionSource(at: "DesignSystem/Theme/Color+App.swift")
        let typography = try productionSource(at: "DesignSystem/Theme/Font+App.swift")
        let shadows = try productionSource(at: "DesignSystem/Theme/Shadow.swift")
        XCTAssertTrue(colors.contains("static let surfaceNavigation"))
        XCTAssertTrue(colors.contains("static let borderNavigation"))
        XCTAssertTrue(colors.contains("static let interactionOnPrimary"))
        XCTAssertTrue(colors.contains("static let sceneForestHighlight"))
        XCTAssertTrue(colors.contains("static let sceneForestMiddle"))
        XCTAssertTrue(colors.contains("static let sceneMountainFront"))
        XCTAssertTrue(colors.contains("static let sceneMountainMiddle"))
        XCTAssertTrue(typography.contains("static let tabLabel"))
        XCTAssertTrue(typography.contains("static let metricValue"))
        XCTAssertTrue(typography.contains("static let metricCompactValue"))
        XCTAssertTrue(typography.contains("static let metricGridValue"))
        XCTAssertTrue(typography.contains("static let weatherConclusion"))
        XCTAssertTrue(typography.contains("static let weatherImpact"))
        XCTAssertTrue(shadows.contains("static let navigation"))
        XCTAssertTrue(shadows.contains("static let interactionGlow"))
    }

    func testHomePilotPreviewsInstantiateProductionViews() throws {
        let metricItem = try productionSource(at: "DesignSystem/Components/MetricItem.swift")
        let metricGroup = try productionSource(at: "DesignSystem/Components/MetricGroup.swift")
        let weather = try productionSource(at: "Features/Home/Components/WeatherSummary.swift")
        let focus = try productionSource(at: "Features/Home/Components/FocusTripSummary.swift")
        let home = try productionSource(at: "Features/Home/HomeView.swift")
        let tabBar = try productionSource(at: "DesignSystem/Components/PrimaryTabBar.swift")

        XCTAssertTrue(metricItem.contains("#Preview"))
        XCTAssertTrue(metricItem.contains("MetricItem("))
        XCTAssertTrue(metricGroup.contains("#Preview"))
        XCTAssertTrue(metricGroup.contains("MetricGroup("))
        XCTAssertTrue(weather.contains("#Preview"))
        XCTAssertTrue(weather.contains("WeatherSummary("))
        XCTAssertTrue(focus.contains("#Preview"))
        XCTAssertTrue(focus.contains("FocusTripSummary("))
        XCTAssertEqual(occurrences(of: "#Preview", in: home), 7)
        XCTAssertTrue(home.contains("HomeView("))
        XCTAssertTrue(tabBar.contains("#Preview"))
        XCTAssertTrue(tabBar.contains("PrimaryTabBar("))
    }

    func testStandardNavigationPagesUseSharedRootBackgroundContainer() throws {
        let equipmentSource = try productionSource(at: "Features/Equipment/EquipmentListView.swift")

        XCTAssertTrue(equipmentSource.contains("UtilityPageContainer"))
    }

    func testRouteCardHeightFillsViewportMinusRegisteredVerticalSpacing() {
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 500), 484)
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 800), 784)
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 1_200), 1_184)
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

    func testPersonalTripStatusBadgeColorsMatchApprovedContract() {
        assertColor(PersonalTripStatus.planned.badgeForegroundColor, red: 251, green: 191, blue: 36)
        assertColor(PersonalTripStatus.planned.badgeBackgroundColor, red: 245, green: 158, blue: 11, alpha: 0.15)
        assertColor(PersonalTripStatus.inProgress.badgeForegroundColor, red: 74, green: 222, blue: 128)
        assertColor(PersonalTripStatus.inProgress.badgeBackgroundColor, red: 34, green: 197, blue: 94, alpha: 0.12)
        assertColor(PersonalTripStatus.completed.badgeForegroundColor, red: 192, green: 132, blue: 252)
        assertColor(PersonalTripStatus.completed.badgeBackgroundColor, red: 168, green: 85, blue: 247, alpha: 0.12)
        assertColor(PersonalTripStatus.cancelled.badgeForegroundColor, red: 248, green: 113, blue: 113)
        assertColor(PersonalTripStatus.cancelled.badgeBackgroundColor, red: 239, green: 68, blue: 68, alpha: 0.10)
    }

    func testTripStatusBadgeShapeAndInputMatchApprovedContract() throws {
        let source = try productionSource(at: "Features/Trips/TripStatusBadge.swift")

        XCTAssertTrue(source.contains("private let status: PersonalTripStatus"))
        XCTAssertTrue(source.contains("init(status: PersonalTripStatus)"))
        XCTAssertTrue(source.contains("RoundedRectangle(cornerRadius: Radius.md, style: .continuous)"))
        XCTAssertFalse(source.contains("Capsule()"))
        XCTAssertFalse(source.contains("init(status: some StatusBadgeModel)"))
    }

    func testTripLayoutMatchesApprovedContract() {
        XCTAssertEqual(TripLayout.listCoverSize, 52)
        XCTAssertEqual(TripLayout.compactListCoverSize, 48)
        XCTAssertEqual(TripLayout.detailCoverHeight, 275)
    }

    func testTripDetailDoesNotUseMockTrackFallback() throws {
        let source = try productionSource(at: "Features/Trips/TripDetailViewModel.swift")

        // PAGE-TRIP-DETAIL 不渲染轨迹地图，路线指标由 TripRouteMetricsSummary 承载距离/爬升/预计用时；
        // ViewModel 不得引入 MockData 或 fallbackCoordinates 补造轨迹。
        XCTAssertFalse(source.contains("MockData"))
        XCTAssertFalse(source.contains("fallbackCoordinates"))
    }

    // MARK: - 结构规范守卫（S1-S6，ios-structure-binding.md）
    // 规则：已合规项强制；存量差距以白名单锁定并防倒退，待规划改造清零。

    func testFeatureSourcesUseUnifiedVerticalLists() throws {
        let scope = try featureFiles()
        var counts: [String: Int] = [:]
        let pattern = #"(?<![\w.])\bList\s*[({]"#
        for (name, source) in scope {
            let n = countMatches(pattern, in: source)
            if n > 0 { counts[name] = n }
        }
        XCTAssertTrue(counts.isEmpty, "S2：Feature 内纵向列表统一使用 ScrollView + LazyVStack\n\(counts)")
    }

    func testFeatureSourcesNeverAddNewBackgroundGradients() throws {
        let scope = try featureFiles()
        var files: [String] = []
        for (name, source) in scope
        where source.contains("LinearGradient(") || source.contains("RadialGradient(") {
            files.append(name)
        }
        XCTAssertEqual(
            Set(files),
            Set(["HomeView.swift", "RouteDiscoveryView.swift", "TripRowView.swift"]),
            "S1：Feature 内自建渐变仅允许登记文件（获批氛围元素与图片可读性覆盖层），禁止新增"
        )
    }

    func testSafeAreaInsetHandlingLivesInSharedPageContainers() throws {
        let scope = try featureFiles()
        var files: [String] = []
        for (name, source) in scope where source.contains("safeAreaInsets") || source.contains("systemInsets") {
            files.append(name)
        }
        XCTAssertTrue(
            files.isEmpty,
            "S4：Feature 不得读取或接收系统区域 inset 后自行计算避让\n" + files.joined(separator: "\n")
        )

        let sharedPrimitives = try productionSource(at: "DesignSystem/Components/SharedPrimitives.swift")
        XCTAssertTrue(sharedPrimitives.contains(".ignoresSafeArea()"), "页面壳负责将沉浸式背景延伸到系统区域")
        let routeDetail = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        XCTAssertTrue(routeDetail.contains("ImmersivePageContainer"), "路线详情复用统一沉浸式页面壳")
    }

    func testFeatureLazyVStackSpacingsUseRegisteredTokens() throws {
        let scope = try featureFiles()
        var violations: [String] = []
        let pattern = #"LazyVStack\((?:(?!\))).)*spacing:\s*([A-Za-z0-9_.]+)"#
        for (name, source) in scope {
            for value in matches(pattern, in: source)
            where value != "0" && !value.hasPrefix("Spacing.") {
                violations.append("\(name): spacing: \(value)")
            }
        }
        XCTAssertTrue(
            violations.isEmpty,
            "S2：LazyVStack spacing 必须为已登记 Spacing token 或 0（含 RouteDiscoveryView 分页流）\n" + violations.joined(separator: "\n")
        )
    }

    func testFeatureSourcesDoNotDeclareParallelPageOrStatusComponents() throws {
        let scope = try featureFiles()
        var violations: [String] = []
        let pattern = #"struct\s+\w*(?:PageContainer|LoadingView|EmptyStateView|ErrorView|UnavailableStateView|NoticeView|InfoTag)\b"#
        for (name, source) in scope where regexMatches(pattern, in: source) {
            violations.append(name)
        }
        XCTAssertTrue(
            violations.isEmpty,
            "S3/S6：Feature 内不得声明与 DesignSystem 平行的页面壳或状态组件\n" + violations.joined(separator: "\n")
        )
    }

    func testImmersivePagesHideSystemNavigationBar() throws {
        let home = try productionSource(at: "Features/Home/HomeView.swift")
        let root = try productionSource(at: "App/RootView.swift")
        XCTAssertTrue(home.contains(".toolbar(.hidden, for: .navigationBar)"))
        XCTAssertTrue(root.contains(".toolbar(.hidden, for: .navigationBar)"))
    }

    func testRootViewIsTheSingleShellImplementation() throws {
        let root = try productionSource(at: "App/RootView.swift")
        XCTAssertTrue(root.contains("TabView(selection:"))
        XCTAssertEqual(occurrences(of: "NavigationStack(", in: root), 1, "NavigationStack 只允许一个实现点（tabStack 封装，三个 tab 复用）")
        XCTAssertTrue(root.contains("NavigationStack(path: pathBinding(for: tab))"))
        XCTAssertFalse(
            regexMatches(#"struct\s+\w+Shell\s*:\s*View"#, in: root),
            "RootView 是唯一实现 shell，Feature 内不得再自建页面壳"
        )
    }

    func testSharedShellAndPanelKeepCanonicalStructure() throws {
        let source = try productionSource(at: "DesignSystem/Components/SharedPrimitives.swift")
        XCTAssertTrue(source.contains("enum WalkPanelSurface"))
        XCTAssertTrue(source.contains("case primary"))
        XCTAssertTrue(source.contains("case glass"))
        XCTAssertTrue(source.contains("init(surface: WalkPanelSurface = .primary"))
        XCTAssertTrue(source.contains(".padding(Spacing.lg)")) // WalkPanel 内边距
        XCTAssertTrue(source.contains(".background(surface.color)")) // WalkPanel 表面变体
        XCTAssertTrue(source.contains("cornerRadius: Radius.lg")) // WalkPanel 圆角
        XCTAssertTrue(source.contains(".appShadow(AppShadow.panel)")) // WalkPanel 阴影
        XCTAssertTrue(source.contains("RadialGradient(")) // ImmersivePageContainer 背景
        XCTAssertTrue(source.contains("AppColors.pageOuter, AppColors.pageMiddle, AppColors.pageBase")) // 渐变 token 顺序
    }

    // MARK: 批次 1 —— PAGE-ROUTES / PAGE-ROUTE-LIST / PAGE-SEARCH

    func testRouteDiscoveryKeepsUnavailableEmptyStateAndSearchScope() throws {
        let discovery = try productionSource(at: "Features/Routes/RouteDiscoveryView.swift")
        XCTAssertTrue(discovery.contains("暂时无法加载路线"), "路线列表不可用空态")
        XCTAssertTrue(discovery.contains("只搜索 Walk 当前提供的徒步路线"), "搜索范围说明")
        XCTAssertTrue(discovery.contains("搜索路线名称或地区"), "搜索输入占位")
    }

    func testRouteBrowsePagesUseProductionComponentsWithoutResolvingMediaReferences() throws {
        let source = try productionSource(at: "Features/Routes/RouteDiscoveryView.swift")
        let collectionStart = try XCTUnwrap(source.range(of: "struct RouteCollectionView: View"))
        let searchStart = try XCTUnwrap(source.range(of: "struct RouteSearchView: View"))
        let discoverySource = String(source[..<collectionStart.lowerBound])
        let collectionSource = String(source[collectionStart.lowerBound..<searchStart.lowerBound])
        let searchSource = String(source[searchStart.lowerBound...])

        XCTAssertTrue(discoverySource.contains("RouteBusinessComponents.RouteScene("))
        XCTAssertTrue(discoverySource.contains("RouteSceneProjection("))
        XCTAssertTrue(discoverySource.contains("routeID: route.routeId"))
        XCTAssertTrue(discoverySource.contains("name: route.name"))
        XCTAssertTrue(discoverySource.contains("region: route.region"))
        XCTAssertTrue(discoverySource.contains("difficulty: route.difficulty"))
        XCTAssertTrue(discoverySource.contains("route.distance"))
        XCTAssertTrue(discoverySource.contains("route.ascent"))
        XCTAssertTrue(discoverySource.contains("route.estimatedDuration"))
        XCTAssertTrue(discoverySource.contains("RouteDeterministicImageSurface(style: .forest)"))
        XCTAssertFalse(discoverySource.contains("RouteScenePage"))
        XCTAssertFalse(discoverySource.contains("RouteSceneButtonStyle"))
        XCTAssertFalse(discoverySource.contains("Button {"), "RouteScene 自身拥有唯一选择入口")

        XCTAssertTrue(collectionSource.contains("RouteBusinessComponents.RouteListRow("))
        XCTAssertTrue(collectionSource.contains("projection: .browse("))
        XCTAssertTrue(collectionSource.contains("RouteBrowseRowProjection("))
        XCTAssertTrue(collectionSource.contains("routeID: route.routeId"))
        XCTAssertTrue(collectionSource.contains("name: route.name"))
        XCTAssertTrue(collectionSource.contains("region: route.region"))
        XCTAssertTrue(collectionSource.contains("difficulty: route.difficulty"))
        XCTAssertTrue(collectionSource.contains("distance: route.distance.map"))
        XCTAssertTrue(collectionSource.contains("ascent: route.ascent.map"))
        XCTAssertTrue(collectionSource.contains("estimatedDuration: route.estimatedDuration.map"))
        XCTAssertTrue(collectionSource.contains("RouteDeterministicImageSurface(style: .forest)"))
        XCTAssertFalse(collectionSource.contains("RouteListCompactRow"))
        XCTAssertFalse(collectionSource.contains("route.cover"), "MediaReference 未解析时不得进入 browse 视觉")
        XCTAssertFalse(collectionSource.contains("Button {"), "RouteListRow 自身拥有唯一选择入口")

        XCTAssertEqual(occurrences(of: "coverAvailable: false", in: discoverySource + collectionSource), 2)
        XCTAssertTrue(searchSource.contains("RouteBusinessComponents.SearchRouteResultRow("), "搜索页使用生产 SearchRouteResultRow")
        XCTAssertTrue(searchSource.contains("SearchRouteResultRowProjection("), "搜索页构造 SearchRouteResultRowProjection")
        XCTAssertTrue(searchSource.contains("routeID: route.routeId"), "搜索行绑定路线 ID")
        XCTAssertFalse(searchSource.contains("RouteListCompactRow"), "搜索页不再保留私有 RouteListCompactRow")
        XCTAssertFalse(searchSource.contains("RouteBusinessComponents.RouteListRow("), "搜索页不得使用 RouteListRow.search")
    }

    // MARK: 批次 2/3 —— PAGE-LOGIN / TRIP-DETAIL / TRIPS / TRIP-DAY / TRIP-WEATHER / TRIP-EQUIPMENT

    func testLoginEstablishesWalkAccountAfterFirstVerification() throws {
        let login = try productionSource(at: "Features/Profile/LoginView.swift")
        XCTAssertTrue(login.contains("首次验证通过后直接建立 Walk 账号"), "登录页说明建立账号方式")
        XCTAssertTrue(login.contains("WalkPanel(surface: .glass)"), "认证面板使用 WalkPanel 的 glass 表面变体")
        XCTAssertTrue(login.contains("GlassIconButton(systemName: \"xmark\", action: cancelAuthentication)"), "认证面板提供会退出当前页面的关闭按钮")
        XCTAssertTrue(login.contains("@Environment(\\.dismiss) private var dismiss"), "登录页持有系统导航退出能力")
        XCTAssertTrue(login.contains("private func cancelAuthentication()"), "关闭动作统一清理认证意图并退出页面")
        XCTAssertTrue(login.contains("dismiss()"), "关闭动作必须真正移除登录页")
        XCTAssertFalse(login.contains("prefix: \"+86\""), "登录输入不得把国际手机号固定为 +86 前缀")
        XCTAssertTrue(login.contains(".toolbar(.hidden, for: .navigationBar)"), "登录页使用自身认证结构而非叠加系统导航头")
    }

    func testTripCreationDoesNotRejectPastDatesLocally() throws {
        let createTrip = try productionSource(at: "Features/Trips/CreateTripView.swift")
        XCTAssertFalse(
            createTrip.contains("in: BusinessCalendar.startOfToday()..."),
            "日期可用性必须由共享合同判定，客户端不得自行禁用过去日期"
        )
    }

    func testTripDetailKeepsBlockedRouteVersionAndMetricsInExistingRegion() throws {
        let detail = try productionSource(at: "Features/Trips/TripDetailView.swift")

        XCTAssertFalse(detail.contains("private struct TripRouteSummaryCard: View"), "不再保留私有聚合 TripRouteSummaryCard")
        XCTAssertFalse(detail.contains("routeMetrics(route)"))
        XCTAssertFalse(detail.contains("var versionContent"))
        XCTAssertTrue(detail.contains("TripBusinessComponents.TripRouteVersionCard("), "使用生产 TripRouteVersionCard")
        XCTAssertTrue(detail.contains("TripBusinessComponents.TripRouteMetricsSummary("), "使用生产 TripRouteMetricsSummary")
        XCTAssertTrue(detail.contains("TripBusinessComponents.TripRouteSummaryCard("), "使用生产路线入口 TripRouteSummaryCard")
        XCTAssertTrue(detail.contains("routeVersionProjection("), "页面构造版本投影")
        XCTAssertTrue(detail.contains("routeMetricsProjection("), "页面构造指标投影")
        XCTAssertTrue(detail.contains("routeEntryProjection("), "页面构造路线入口投影")
    }

    func testTripListEmptyStatePointsToRouteDiscovery() throws {
        let list = try productionSource(at: "Features/Trips/TripListView.swift")
        XCTAssertTrue(list.contains("先查找一条路线并生成个人行程"), "空态引导查找路线")
    }

    func testTripListUsesApprovedPageStatesAndSpacing() throws {
        let list = try productionSource(at: "Features/Trips/TripListView.swift")
        XCTAssertTrue(list.contains(".padding(.top, Spacing.lg)"), "滚动内容顶部距固定导航头 lg")
        XCTAssertTrue(list.contains("variant: .default"), "全局空态使用 EmptyState.default")
        XCTAssertTrue(list.contains("variant: .page"), "加载失败使用 ErrorView.page")
        XCTAssertFalse(list.contains("variant: .section"), "PAGE-TRIPS 全局状态不得使用 Section 变体")
    }

    func testTripDayKeepsServerActionAndPointOrderAndEdgeHint() throws {
        let day = try productionSource(at: "Features/Trips/TripDayWeatherViews.swift")
        XCTAssertTrue(day.contains("ForEach(presentation.presentationItems)"), "行动按后端 sequence 原序展示")
        XCTAssertTrue(day.contains("ForEach(presentation.pointItems)"), "点位按单一 sequence 流展示")
        XCTAssertFalse(day.contains("departureTransportActions"), "客户端不推断去程交通槽位")
        XCTAssertFalse(day.contains("groupedPoints"), "客户端不按类别重排点位")
        XCTAssertTrue(day.contains("滚动到边界后继续同方向滑动，切换相邻日期"), "日分页边界滑动提示")
        XCTAssertTrue(day.contains("spacing: Spacing.md"), "内部滚动区行距使用 canonical md token")
        XCTAssertFalse(day.contains("Spacing.listItemGap"), "禁止旧 listItemGap alias")
    }

    func testTripWeatherDoesNotMapForecastPeriodsIntoLegacyDailyCards() throws {
        let source = try productionSource(at: "Features/Trips/TripDayWeatherViews.swift")
        XCTAssertFalse(source.contains("TripBusinessComponents.DailyWeatherCard("), "新 Forecast periods 尚无已批准的逐日卡片映射")
        XCTAssertFalse(source.contains("TripWeatherDayComponentPresentation(day:"), "不得从 Forecast periods 生成旧四字段摘要")
        XCTAssertTrue(source.contains("trip_weather_projection_unavailable"), "后端暂不可用错误使用稳定错误码判断")
        XCTAssertFalse(source.contains("private struct DailyTripWeatherCard"), "不建立页面私有逐日天气卡")
        XCTAssertFalse(source.contains("private struct WeatherOverview"), "不建立页面私有天气概况")
        XCTAssertFalse(source.contains("importantImpacts"), "不得从天气关联推导整趟重要影响")
    }

    func testTripEquipmentFollowsSectionedSpec() throws {
        let equipment = try productionSource(at: "Features/Trips/TripEquipment.swift")
        // PAGE-TRIP-EQUIPMENT 权威：固定导航用 UtilityNavigationHeader（非 .navigationTitle），
        // 清单不可用用 ErrorView.page（非 UnavailableStateView），保存失败经 InlineEquipmentEditor.saveError。
        XCTAssertTrue(equipment.contains("UtilityNavigationHeader("), "固定导航头")
        XCTAssertTrue(equipment.contains("title: \"行程装备\""), "导航头标题")
        XCTAssertTrue(equipment.contains("本次装备清单为空"), "空态")
        XCTAssertTrue(equipment.contains("新增本次装备"), "次级操作新增")
        XCTAssertTrue(equipment.contains("管理我的装备"), "次级操作管理")
        XCTAssertTrue(equipment.contains("重新核对已有状态"), "重新核对")
        XCTAssertTrue(equipment.contains("当前行程为只读"), "只读替换文案")
        // 四项概况指标由 TripEquipmentOverview 组件拥有（PAGE-TRIP-EQUIPMENT 禁止 Page 直接拥有概况内部指标），
        // 文案权威在组件 spec，断言改查组件源码而非页面源码。
        let overview = try productionSource(at: "DesignSystem/BusinessComponents/Trip/TripEquipmentOverview.swift")
        XCTAssertTrue(overview.contains("label: \"装备条目\""), "四指标格条目数")
        XCTAssertTrue(overview.contains("预计总重量"), "四指标格完整重量")
        XCTAssertTrue(overview.contains("label: \"未确认已有\""), "四指标格未确认")
        XCTAssertTrue(equipment.contains("ErrorView("), "清单不可用使用 ErrorView.page")
        XCTAssertTrue(equipment.contains("title: \"无法显示行程装备\""), "清单不可用有明确文案")
        XCTAssertTrue(equipment.contains("Task { await viewModel.load() }"), "清单不可用提供重试")
        XCTAssertTrue(equipment.contains("saveError: viewModel.errorMessage"), "保存失败经 InlineEquipmentEditor.saveError 接收后端失败原因")
    }

    // MARK: 批次 4a —— PAGE-ME / PAGE-MY-EQUIPMENT / PAGE-EQUIPMENT-EDIT

    func testProfileFollowsPageStructureSpec() throws {
        let profile = try productionSource(at: "Features/Profile/ProfileView.swift")
        XCTAssertTrue(profile.contains("登录后管理行程与徒步装备"), "游客态页面头 caption 摘要")
        XCTAssertTrue(profile.contains("你的徒步记录，都在这里"), "游客态 EmptyState 主文案")
        XCTAssertEqual(occurrences(of: "onNavigate(.tripList)", in: profile), 1, "行程日历是唯一 tripList 入口")
        XCTAssertTrue(profile.contains("AvatarButton"), "登录态页面头使用 AvatarButton 通用组件")
        XCTAssertTrue(profile.contains("ErrorView"), "登录态分节失败使用 ErrorView.section")
        XCTAssertTrue(profile.contains("viewModel.retryCalendar()"), "行程日历 Section 提供独立重试")
        XCTAssertTrue(profile.contains("viewModel.retryEquipment()"), "装备 Section 提供独立重试")
        // 按 PAGE-ME 权威，查看入口、脱敏账号与关于行由 TripCalendarCard / AccountMenuSheet 组件拥有，不在页面。
        let calendarCard = try productionSource(at: "DesignSystem/BusinessComponents/Trip/TripCalendarCard.swift")
        XCTAssertTrue(calendarCard.contains("查看全部"), "行程日历查看入口在 TripCalendarCard 组件内")
        let accountMenu = try productionSource(at: "DesignSystem/BusinessComponents/AccountEquipment/AccountMenuSheet.swift")
        XCTAssertTrue(accountMenu.contains("maskedPhone"), "脱敏账号摘要在 AccountMenuSheet 组件内")
        XCTAssertTrue(accountMenu.contains("关于 Walk"), "关于行文案在 AccountMenuSheet 组件内")
    }

    func testEquipmentListFollowsPageStructureSpec() throws {
        let list = try productionSource(at: "Features/Equipment/EquipmentListView.swift")
        XCTAssertTrue(list.contains("长期个人资产"), "页题区引导语")
        XCTAssertTrue(list.contains("装备与清单"), "页题区标题")
        XCTAssertTrue(list.contains("个人装备记录实际拥有数量和可选单件重量；清单按清单内数量汇总预计总重量。"), "页题区说明")
        // PAGE-MY-EQUIPMENT 权威页签为 SegmentedControl 通用组件，非原生 .pickerStyle(.segmented)；
        // 装备行未填写重量文案属 EquipmentListRow 组件，重命名文案属 InlineListNameEditor 组件。
        XCTAssertTrue(list.contains("SegmentedControl("), "装备/清单页签使用 SegmentedControl 组件")
        let equipmentRow = try productionSource(at: "DesignSystem/BusinessComponents/AccountEquipment/EquipmentListRow.swift")
        XCTAssertTrue(equipmentRow.contains("重量未填写"), "装备行未填写重量文案在组件内")
        let listNameEditor = try productionSource(at: "DesignSystem/BusinessComponents/AccountEquipment/InlineListNameEditor.swift")
        XCTAssertTrue(listNameEditor.contains("重命名装备清单"), "清单行内重命名文案在组件内")
        XCTAssertTrue(list.contains("新增个人装备"), "装备页签底部固定主按钮")
        XCTAssertTrue(list.contains("创建装备清单"), "清单页签底部固定主按钮")
        XCTAssertTrue(list.contains("尚未维护个人装备"), "装备空态")
        XCTAssertTrue(list.contains("还没有装备清单"), "清单空态")
        XCTAssertFalse(
            regexMatches(#"NavigationLink\s*\{[^}]*EquipmentListDetailView"#, in: list),
            "清单详情不得再以 push 页实现，改为行内展开"
        )
    }

    func testEquipmentEditFollowsPageStructureSpec() throws {
        let edit = try productionSource(at: "Features/Equipment/AddEquipmentView.swift")
        XCTAssertTrue(edit.contains("新增个人装备"))
        XCTAssertTrue(edit.contains("编辑个人装备"))
        XCTAssertTrue(edit.contains("写入长期个人资产"))
        XCTAssertTrue(edit.contains("新增一件装备"))
        XCTAssertTrue(edit.contains("更新装备"))
        XCTAssertTrue(edit.contains("只维护装备名称、实际拥有数量和可选的单件重量。"))
        XCTAssertTrue(edit.contains("请输入装备名称"))
        XCTAssertTrue(edit.contains("请输入大于零的克重"))
        XCTAssertFalse(edit.contains("if #available(iOS 17.0"), "iOS 16 也必须展示装备名称输入")
        XCTAssertTrue(edit.contains("删除后会从用户装备清单移除，但不会修改已经生成的行程装备。"))
        XCTAssertTrue(edit.contains("\"保存\""), "底部固定主按钮保存")
        XCTAssertTrue(edit.contains(".safeAreaInset(edge: .bottom"))
    }

    func testEntryFormPageSupportsPageHeadingWithoutBreakingSharedForm() throws {
        let pages = try productionSource(at: "Features/Profile/ProfileEntryPages.swift")
        XCTAssertTrue(pages.contains("guide: String? = nil"), "引导语参数可选")
        XCTAssertTrue(pages.contains("pageTitle: String? = nil"), "页内标题参数可选")
        XCTAssertTrue(pages.contains("fieldSpacing: CGFloat = Spacing.lg"), "字段间距参数可配置")
    }

    // MARK: 批次 4b —— PAGE-ROUTE-DETAIL 结构差距修正

    func testRouteDetailKeepsMapLayerWhenMainTrackUnavailable() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        XCTAssertFalse(source.contains("if !viewModel.hasUnavailableTrack"), "主轨迹不可用时仍保留地图底层")
        XCTAssertTrue(source.contains("RouteMapView("), "地图底层持续存在且不伪造轨迹")
        XCTAssertTrue(source.contains("NoticeView(message: trackUnavailableText"), "地图区域使用 Notice 表达主轨迹不可用")
    }

    func testRouteDetailSummaryUsesHeroTitleAndCanonicalSpacing() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        let summary = try productionSource(at: "DesignSystem/BusinessComponents/Route/RouteSummary.swift")
        XCTAssertTrue(summary.contains(".font(.heroTitle)"), "路线概要名称使用 hero 级标题")
        XCTAssertTrue(source.contains("spacing: Spacing.md"), "信息列表条目行间距使用 canonical md token")
        XCTAssertFalse(source.contains("Spacing.listItemGap"), "禁止旧 listItemGap alias")
    }

    func testRouteMapDetailSheetHasDismissControl() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        XCTAssertTrue(source.contains("systemName: \"xmark\""), "点位详情浮层提供关闭按钮")
        XCTAssertTrue(source.contains("关闭详情"), "关闭按钮可访问标签")
        XCTAssertTrue(source.contains("@Environment(\\.dismiss)"), "浮层可自行关闭")
    }

    func testSpacingSourceUsesApprovedContractCanonicalNames() throws {
        let source = try productionSource(at: "DesignSystem/Theme/Spacing.swift")
        let forbiddenAliases = ["pageVertical", "componentPadding", "listItemGap", "sectionGap"]

        XCTAssertFalse(source.contains("static let hero:"))
        XCTAssertFalse(source.contains("static let heroHorizontal"))
        for alias in forbiddenAliases {
            XCTAssertFalse(source.contains("static let \(alias)"), "禁止声明旧 spacing alias：\(alias)")
        }

        let violations = try violations(in: "Features") { featureSource in
            forbiddenAliases.compactMap { alias in
                featureSource.contains("Spacing.\(alias)") ? "legacy Spacing.\(alias); use canonical token" : nil
            }
        }
        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    private func featureFiles() throws -> [(name: String, source: String)] {
        let featureRoot = try XCTUnwrap(walkRoot().appendingPathComponent("Features"))
        let fileManager = FileManager.default
        var result: [(name: String, source: String)] = []
        guard let enumerator = fileManager.enumerator(at: featureRoot, includingPropertiesForKeys: nil) else {
            return result
        }
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            result.append((fileURL.lastPathComponent, try String(contentsOf: fileURL, encoding: .utf8)))
        }
        return result
    }

    private func matches(_ pattern: String, in source: String) -> [String] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard match.numberOfRanges > 1, let valueRange = Range(match.range(at: 1), in: source) else { return nil }
            return String(source[valueRange])
        }
    }

    private func countMatches(_ pattern: String, in source: String) -> Int {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return 0 }
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.numberOfMatches(in: source, range: range)
    }

    private func occurrences(of literal: String, in source: String) -> Int {
        source.components(separatedBy: literal).count - 1
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
