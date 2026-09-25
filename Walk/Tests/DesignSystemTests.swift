import SwiftUI
import XCTest
import WalkData
import WalkDesignSystem
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
        let source = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Theme/Font+App.swift")

        XCTAssertTrue(source.contains("static let appBody = Font.system(size: 15, weight: .regular)"))
        XCTAssertTrue(source.contains("static let appCaption = Font.system(size: 13, weight: .regular)"))
        XCTAssertFalse(regexMatches(#"static let body\s*="#, in: source))
        XCTAssertFalse(regexMatches(#"static let caption\s*="#, in: source))
        XCTAssertFalse(regexMatches(#"AppTypography\.body\b"#, in: source))
        XCTAssertFalse(regexMatches(#"AppTypography\.caption\b"#, in: source))
    }

    func testModalBottomSheetCoversBottomSafeArea() throws {
        let source = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/ModalBottomSheet.swift")

        XCTAssertTrue(
            source.contains(".ignoresSafeArea(edges: .bottom)"),
            "Sheet 表面须忽略底部安全区，贴齐屏幕底边不留间距"
        )
    }

    /// tokens.md「使用限制」：页面和组件只消费 Token，不得出现裸值。
    /// 只拦截数值字面量颜色；数据携带的颜色（如分段 `colorHex`）不属于样式裸值。
    func testFeatureSourcesUseColorTokensOnly() throws {
        let violations = try allFeatureSources().compactMap { name, source -> String? in
            regexMatches(#"\b(UI)?Color\(\s*red:"#, in: source) ? "\(name): raw numeric color; use AppColors token" : nil
        }
        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testFeatureSourcesUseTypographyTokensOnly() throws {
        // W5：Token 约束覆盖业务组件目录，不沿用页面级规则的组件豁免。
        let violations = try allFeatureSources().flatMap { name, source -> [String] in
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
            return found.map { "\(name): \($0)" }
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))
    }

    func testDesignSystemComponentsUseRegisteredTypographyOnly() throws {
        let violations = try violations(in: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components") { source in
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

        let errorView = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/ErrorView.swift")
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
            // Features/*/Components/ 是业务组件（由组件目录与基线体系治理），不参与页面级规则扫描
            if fileURL.path.contains("/Features/") && fileURL.path.contains("/Components/") { continue }
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            if let range = source.range(of: #"struct \w*StatusBadge\b"#, options: .regularExpression) {
                declarations.append("\(fileURL.lastPathComponent): \(source[range])")
            }
        }

        XCTAssertEqual(declarations, ["TripStatusBadge.swift: struct TripStatusBadge"])
    }

    func testUtilityNavigationHeaderIsUnifiedFloatingCarrier() throws {
        let source = try productionSource(
            at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/UtilityNavigationHeader.swift"
        )

        XCTAssertTrue(
            source.contains("public let title: String?"),
            "标题可选：同页 PageTitleBlock 拥有唯一主标题时导航承载省略标题"
        )
        XCTAssertFalse(source.contains("surfaceHeader"), "统一悬浮承载不使用固定页头底色")
        XCTAssertFalse(regexMatches(#"showsDivider"#, in: source), "统一悬浮承载不渲染下边界线")
        XCTAssertTrue(
            source.contains("public var variant: IconButtonVariant = .overlay"),
            "导航槽默认为悬浮圆形 IconButton.overlay"
        )
    }

    func testSecondaryPagesDropPromotionalKickersAndDuplicatedTitles() throws {
        let violations = try violations(in: "Features") { source in
            source.contains("长期个人资产")
                ? ["二级页不得输出宣传性 kicker 文案「长期个人资产」"]
                : []
        }
        XCTAssertTrue(violations.isEmpty, violations.joined(separator: "\n"))

        let tripListSource = try productionSource(at: "Features/Trips/TripListView.swift")
        XCTAssertLessThanOrEqual(
            tripListSource.components(separatedBy: "我的全部行程").count - 1,
            1,
            "页面标题只呈现一次：由顶部悬浮导航承载拥有，正文不重复标题块"
        )
        XCTAssertFalse(
            tripListSource.contains("当前行程和历史行程在同一页面分组展示"),
            "正文不重复纯解释性副标题"
        )
    }

    func testPageTitleBlockTitleRowHeightIsIndependentOfTrailing() throws {
        let source = try productionSource(
            at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift"
        )
        let titleBlockSource = try titleBlockRegion(in: source)

        XCTAssertTrue(
            titleBlockSource.contains(".frame(minHeight: 44"),
            "标题行必须自带 44pt 最小高度：trailing 触控目标不得反向决定一级页头高度（首页/路线/我的三页页头高度保持一致）"
        )
    }

    /// 切取 `PageTitleBlock` 的源码区域，避免断言命中文件内其他 `minHeight: 44`。
    private func titleBlockRegion(in source: String) throws -> Substring {
        let startMarker = "public struct PageTitleBlock"
        let endMarker = "public struct UtilityPageContainer"
        let start = try XCTUnwrap(source.range(of: startMarker), "SharedPrimitives.swift 应包含 \(startMarker)")
        let end = try XCTUnwrap(source.range(of: endMarker, range: start.upperBound..<source.endIndex), "SharedPrimitives.swift 应包含 \(endMarker)")
        return source[start.lowerBound..<end.lowerBound]
    }

    func testPageShellBackgroundSlotDoesNotParticipateInLayout() throws {
        let source = try productionSource(
            at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift"
        )
        let shellSource = try pageShellRegion(in: source)

        XCTAssertTrue(
            shellSource.contains(".background {"),
            "PageShell 背景必须经 .background 垫底渲染：背景插槽是纯装饰层，不参与布局"
        )
        XCTAssertFalse(
            shellSource.contains("ZStack"),
            "PageShell 不得把背景作为 ZStack 兄弟节点：自然尺寸不受控的背景（如未标 scale 的位图）会把容器撑爆，将内容顶出屏幕"
        )
    }

    /// 转场顶部安全区尖峰免疫：根容器（PageShell / RouteDiscoveryView）不再消费动态安全区，
    /// 改用共享的固定窗口安全区常量定位（push/pop 期间系统临时插回导航栏高度会把锚定内容顶跳）。
    func testRootContainersPinWindowSafeAreaAgainstTransitionSpike() throws {
        let shellFile = try productionSource(
            at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift"
        )
        let shellSource = try pageShellRegion(in: shellFile)
        XCTAssertTrue(
            shellSource.contains("PinnedWindowSafeAreaInsets.current"),
            "PageShell 使用共享固定窗口安全区常量，不消费动态安全区"
        )
        XCTAssertTrue(
            shellSource.contains(".ignoresSafeArea()"),
            "PageShell 内容布局脱离动态安全区，由常量定位"
        )
        // 读值必须发生在视图挂载后（onAppear）：视图 init / body 求值事务内
        // 访问 UIWindow 会在 iOS 26 触发 AttributeGraph 循环，锁死整棵视图树
        // 的更新（@State mutation 不再触发重算，所有 push 静默失效）。
        XCTAssertTrue(
            shellSource.contains(".onAppear {"),
            "PageShell 的窗口安全区常量必须在 onAppear 中解析，不得在 init 期读取"
        )

        let discovery = try productionSource(at: "Features/Routes/RouteDiscoveryView.swift")
        XCTAssertTrue(
            discovery.contains("PinnedWindowSafeAreaInsets.current"),
            "路线页页头与场景同样使用固定窗口安全区常量"
        )
        XCTAssertTrue(
            discovery.contains(".onAppear {"),
            "路线页同样在 onAppear 中解析窗口安全区常量"
        )
        XCTAssertFalse(
            discovery.contains("let pinnedInsets: EdgeInsets = PinnedWindowSafeAreaInsets.current"),
            "路线页不得在属性初始化器中读取窗口安全区"
        )
    }

    /// 切取 `PageShell` 的源码区域，避免断言命中文件内其他容器写法。
    private func pageShellRegion(in source: String) throws -> Substring {
        let startMarker = "public struct PageShell"
        let endMarker = "\npublic enum PinnedWindowSafeAreaInsets"
        let start = try XCTUnwrap(source.range(of: startMarker), "SharedPrimitives.swift 应包含 \(startMarker)")
        let end = try XCTUnwrap(source.range(of: endMarker, range: start.upperBound..<source.endIndex), "SharedPrimitives.swift 应包含 \(endMarker)")
        return source[start.lowerBound..<end.lowerBound]
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
            // Features/*/Components/ 是业务组件（由组件目录与基线体系治理），不参与页面级规则扫描
            if fileURL.path.contains("/Features/") && fileURL.path.contains("/Components/") { continue }
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
        assertColor(AppColors.interactionBackground, red: 139, green: 214, blue: 173, alpha: 0.13)
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
        // add-map-point-category-tokens：起点按 route-map 规范为蓝色（冻结原型 #2563eb）。
        assertColor(AppColors.mapStart, red: 37, green: 99, blue: 235)
        assertColor(AppColors.mapEnd, red: 248, green: 113, blue: 113)
        assertColor(AppColors.mapWaypoint, red: 96, green: 165, blue: 250)
        assertColor(AppColors.mapPOI, red: 255, green: 183, blue: 77)
        // 地图点位类别：每类唯一 Token，取值见 docs/ui/tokens.md「地图点位取值」。
        assertColor(AppColors.mapKeyPoint, red: 161, green: 98, blue: 7)
        assertColor(AppColors.mapInterest, red: 37, green: 99, blue: 235)
        assertColor(AppColors.mapCamp, red: 124, green: 58, blue: 237)
        assertColor(AppColors.mapOvernight, red: 109, green: 40, blue: 217)
        assertColor(AppColors.mapWater, red: 8, green: 145, blue: 178)
        assertColor(AppColors.mapSupply, red: 194, green: 65, blue: 12)
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
            // Features/*/Components/ 是业务组件（由组件目录与基线体系治理），不参与页面级规则扫描
            if fileURL.path.contains("/Features/") && fileURL.path.contains("/Components/") { continue }
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

    func testSharedPrimitivesAreConstructible() {
        _ = WalkPanel(variant: .default) { Text("Panel") }
        _ = WalkPanel(surface: .glass) { Text("Glass panel") }
        _ = InfoTag(title: "已确认", tone: .info)
        _ = NoticeView(message: "信息待核验", tone: .warning)
        _ = UnavailableStateView(
            title: "结果不可用",
            message: "请稍后查看",
            icon: "exclamationmark.circle",
            actionTitle: "重试",
            action: {}
        )
        _ = UtilityPageContainer { Text("Utility") }
        _ = ImmersivePageContainer { Text("Immersive") }
        _ = LoadingView()
        _ = StatCardView(title: "Trips", value: "12")
    }

    func testStatusViewsProvideTheirOwnDarkContainers() {
        _ = ErrorView(message: "Error").body
        _ = EmptyStateView(title: "Empty").body
    }

    // MARK: 统一页面壳（UtilityPage 骨架，合同 docs/ui/components/common/utility-page/spec.md）

    func testUtilityPageShellRendersAllSlotCombinations() {
        // default：返回入口 + 标题区 + 滚动内容
        _ = UtilityPage(title: "页题", description: "页题说明") { Text("内容") }.body
        // backOnly：无标题（标题由内容区承载）
        _ = UtilityPage { Text("内容") }.body
        // 任务栈根落点：不显示返回入口
        _ = UtilityPage(title: "页题", showsBackEntry: false) { Text("内容") }.body
        // hero + background + bottomFixed 全插槽
        _ = UtilityPage(
            title: "页题",
            background: { AppColors.pageBase },
            hero: { Text("封面区") },
            bottomFixed: { Text("底部动作") }
        ) { Text("内容") }.body
        // 自定义 leading / trailing 动作
        _ = UtilityPage(
            leading: IconButtonConfiguration(systemName: "xmark", accessibilityLabel: "关闭", action: {}),
            trailing: IconButtonConfiguration(systemName: "magnifyingglass", accessibilityLabel: "搜索", action: {})
        ) { Text("内容") }.body
    }

    func testTextInputUsesApprovedTypographySurfaceAndRadius() throws {
        let source = try productionSource(at: "Features/Profile/SettingsPageShell.swift")
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

        let metricItem = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/MetricItem.swift")
        XCTAssertTrue(metricItem.contains("case `default`"))
        XCTAssertTrue(metricItem.contains("case inlineCompact"))
        XCTAssertTrue(metricItem.contains("case gridCompact"))
        XCTAssertFalse(metricItem.contains("minimumScaleFactor"))

        let metricGroup = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/MetricGroup.swift")
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
        let metricFixtures = try productionSource(
            at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/MetricPreviewFixtures.swift"
        )
        let combined = fixtures + metricFixtures

        XCTAssertTrue(combined.contains("routeName: \"云岭环线\""))
        XCTAssertTrue(combined.contains("start: \"云栈口\""))
        XCTAssertTrue(combined.contains("end: \"云栈口\""))
        XCTAssertTrue(combined.contains("value: \"12.1\", unit: \"km\""))
        XCTAssertTrue(combined.contains("value: \"600\", unit: \"m\""))
        XCTAssertTrue(combined.contains("value: \"约 5 h 20 min\""))
        XCTAssertTrue(combined.contains("conclusion: \"16°·多云\""))
        XCTAssertTrue(combined.contains("impact: \"山脊4级风\""))
    }

    func testHomePilotUsesRegisteredVisualTokens() throws {
        let colors = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Theme/Color+App.swift")
        let typography = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Theme/Font+App.swift")
        let shadows = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Theme/Shadow.swift")
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
        let metricItem = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/MetricItem.swift")
        let metricGroup = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/MetricGroup.swift")
        let weather = try productionSource(at: "Features/Home/Components/WeatherSummary.swift")
        let focus = try productionSource(at: "Features/Home/Components/FocusTripSummary.swift")
        let home = try productionSource(at: "Features/Home/HomeView.swift")

        XCTAssertTrue(metricItem.contains("#Preview"))
        XCTAssertTrue(metricItem.contains("MetricItem("))
        XCTAssertTrue(metricGroup.contains("#Preview"))
        XCTAssertTrue(metricGroup.contains("MetricGroup("))
        XCTAssertTrue(weather.contains("#Preview"))
        XCTAssertTrue(weather.contains("WeatherSummary("))
        XCTAssertTrue(focus.contains("#Preview"))
        XCTAssertTrue(focus.contains("FocusTripSummary("))
        // 校准状态 8 个：guest、noFocus、focusComplete、focusMissingMetrics、
        // focusWeatherOmitted、loading、error、longContent（PAGE-HOME 规范）。
        XCTAssertEqual(occurrences(of: "#Preview", in: home), 8)
        XCTAssertTrue(home.contains("HomeView("))
    }

    /// 焦点行程摘要左边距：PAGE-HOME 摘要与页面 18pt 水平边距对齐，content 槽位必须真正应用传入参数。
    func testFocusTripSummaryAppliesSpecifiedHorizontalPadding() throws {
        let focus = try productionSource(at: "Features/Home/Components/FocusTripSummary.swift")
        XCTAssertTrue(
            focus.contains(".padding(.horizontal, horizontalPadding)"),
            "content 槽位必须应用调用方传入的水平边距，不得接收后丢弃"
        )
    }

    /// 首页触控域：ready 且有焦点行程时整页可点开行程详情；子内容自身手势与守卫保证非焦点态为空操作。
    func testHomePageOffersWholePageTapToOpenFocusedTrip() throws {
        let home = try productionSource(at: "Features/Home/HomeView.swift")
        XCTAssertTrue(home.contains("openFocusedTripIfNeeded"), "整页触控复用焦点行程守卫入口")
        XCTAssertTrue(home.contains(".contentShape(Rectangle())"), "触控域覆盖整页而非仅摘要块")
        XCTAssertTrue(
            home.contains("guard case .ready = viewModel.state"),
            "非焦点状态（guest/loading/error）点击为空操作"
        )
    }

    /// 首页无焦点空态：已登录无焦点行程停留在首页呈现空态与主动入口，不再自动跳转全部路线。
    func testHomePageShowsNoFocusEmptyStateWithoutAutoJump() throws {
        let home = try productionSource(at: "Features/Home/HomeView.swift")
        let homeViewModel = try productionSource(at: "Features/Home/HomeViewModel.swift")
        let root = try productionSource(at: "App/RootView.swift")
        XCTAssertTrue(home.contains("NoFocusContent"), "无焦点空态由 NoFocusContent 非组件承载")
        XCTAssertTrue(home.contains("onBrowseRoutes"), "空态主动入口承载 browseRoutes UI 事件")
        XCTAssertFalse(home.contains("onNoFocus"), "首页不再持有无焦点自动跳转回调")
        XCTAssertFalse(homeViewModel.contains("onNoFocus"), "HomeViewModel 不再触发无焦点自动跳转")
        XCTAssertFalse(root.contains("onNoFocus:"), "RootView 不再把无焦点结果接到 showRouteList")
    }

    /// PAGE-ROUTE-LIST 返回入口：经任意页推入（首页空态、发现流）统一显示返回入口；
    /// 特判只在 navigate 内拥有一次，来源页不得各自设置。
    func testRouteListPushedFromAnyTabShowsBackEntry() throws {
        let root = try productionSource(at: "App/RootView.swift")
        XCTAssertTrue(
            root.contains("if destination == .routeList { shell.routeListShowsBackEntry = true }"),
            "推入 routeList 的返回入口可见性由 navigate 统一设置"
        )
        XCTAssertFalse(
            root.contains("if destination == .routeList { shell.routeListShowsBackEntry = true }\n                navigate"),
            "来源页 onNavigate 不再各自特判"
        )
    }

    func testStandardNavigationPagesUseSharedRootBackgroundContainer() throws {
        let equipmentSource = try productionSource(at: "Features/Equipment/EquipmentListView.swift")

        XCTAssertTrue(equipmentSource.contains("UtilityPage("), "二级页由统一壳 UtilityPage 承载（根背景容器收归壳内）")
    }

    func testRouteDiscoveryCardHeightEqualsPagingViewport() {
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 500), 500)
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 800), 800)
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 1_200), 1_200)
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

    /// 6.3 修订（D2）：RouteSummary 内 MetricGroup.grid 是指标唯一承载，页面不再叠加私有指标面板。
    func testRouteDetailSummaryUsesIconLedMetricPanelWithoutRepeatedLabels() throws {
        let detail = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        XCTAssertFalse(detail.contains("RouteDetailMetricPanel"), "页面不再叠加私有指标面板")

        let summary = try productionSource(at: "Features/Routes/Components/RouteSummary.swift")
        XCTAssertTrue(summary.contains("MetricGroup(items: projection.metrics, variant: .grid)"), "指标由 RouteSummary 内 MetricGroup.grid 承载")
        XCTAssertFalse(summary.contains("Text(metric.0)"))
        XCTAssertFalse(summary.contains("查看路线"))
    }

    /// add-route-detail-pure-map-mode：生成入口迁入 MapToolbar，信息面滚动内容不承载生成动作；
    /// 资格不足时保持可见、禁用呈现但可点，以轻提示传达原因。
    func testRouteDetailKeepsEligibilityAwareGenerationActionOutsideScrollableContent() throws {
        let source = try routeDetailPageSources()

        XCTAssertTrue(source.contains("RouteToolbarGenerateAction("))
        XCTAssertTrue(source.contains("presentation.generationAction"))
        XCTAssertTrue(source.contains("action.isEnabled ? onGenerate : onUnavailable"))
        XCTAssertTrue(source.contains("onGenerateTrip(routeId)"))
        XCTAssertTrue(source.contains("showsGenerationNotice"))
        XCTAssertFalse(source.contains("RouteGenerationPrimaryAction"))
    }

    func testRouteDetailOverlayUsesFullScreenContinuousScrollWithoutDrawerState() throws {
        let source = try routeDetailPageSources()

        XCTAssertTrue(source.contains("RouteDetailScrollOverlay("))
        XCTAssertTrue(source.contains(".routeDetailAlignedScrolling(topInset: topSpacerHeight)"), "顶部地图留白传入滚动内容布局")
        XCTAssertTrue(source.contains("contentMargins(.top, topInset, for: .scrollContent)"), "顶部留白由滚动内容边距承载，不要求额外占位 View")
        XCTAssertFalse(source.contains("drawerState"))
        XCTAssertFalse(source.contains("overlayOffset"))
        XCTAssertFalse(source.contains("RouteDetailSheetPhysics"))
        XCTAssertFalse(source.contains("isScrollEnabled"))
        XCTAssertFalse(source.contains("case expanded"))
    }

    func testRouteDetailUsesOneFullScreenScrollOverlay() throws {
        let source = try routeDetailPageSources()

        XCTAssertTrue(source.contains("RouteDetailScrollOverlay("))
        XCTAssertTrue(source.contains("topSpacerHeight: topSpacerHeight"), "页面向信息滚动层传入顶部地图留白")
        XCTAssertEqual(source.components(separatedBy: "ScrollView(").count - 1, 1, "页面及支持结构共同保持唯一滚动拥有者")
        XCTAssertFalse(source.contains("private struct RouteDetailDrawer: View"))
        XCTAssertFalse(source.contains("isScrollEnabled"))
        XCTAssertFalse(source.contains("case expanded"))
    }

    func testRouteSummaryMetricsUseOneSolidDarkGreenSection() throws {
        let source = try productionSource(at: "Features/Routes/Components/RouteSummary.swift")

        XCTAssertTrue(source.contains("MetricGroup(items: projection.metrics, variant: .grid)"))
        XCTAssertFalse(source.contains("sheetSectionBorder"))
        XCTAssertFalse(source.contains("RouteDetailMetricCard"))
    }

    func testExpandedGroupsUseSolidSectionsWithTransparentGaps() throws {
        let source = try routeDetailPageSources()

        // 信息面迭代：容器透明，每个资料区由 sectionCard 独立成卡片展示。
        XCTAssertFalse(source.contains("RouteDetailSectionContainer"))
        XCTAssertTrue(source.contains("private func sectionCard<Content: View>"))
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

    /// 页面和其非组件支持结构共同构成 RouteDetail；同时校验入口仍消费该支持结构。
    private func routeDetailPageSources(file: StaticString = #filePath, line: UInt = #line) throws -> String {
        let page = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        let support = try productionSource(at: "Features/Routes/RouteDetailViewSupport.swift")
        XCTAssertTrue(page.contains("RouteDetailScrollOverlay("), "页面必须消费被审计的信息滚动层", file: file, line: line)
        return [page, support].joined(separator: "\n")
    }

    /// 个人资料域已按页拆分为独立文件；结构断言聚合读取全部拆分文件。
    private func profileEntrySources() throws -> String {
        try [
            "Features/Profile/SettingsPageShell.swift",
            "Features/Profile/EntryFormPage.swift",
            "Features/Profile/ProfileDetailsPage.swift",
            "Features/Profile/NotificationSettingsPage.swift",
            "Features/Profile/PrivacySettingsPage.swift",
            "Features/Profile/HelpFeedbackPage.swift",
            "Features/Profile/AboutPage.swift",
        ]
        .map { try productionSource(at: $0) }
        .joined(separator: "\n")
    }

    func testPersonalTripStatusBadgeColorsMatchApprovedContract() {
        assertColor(PersonalTripStatus.planned.badgeForegroundColor, red: 251, green: 191, blue: 36)
        assertColor(PersonalTripStatus.planned.badgeBackgroundColor, red: 245, green: 158, blue: 11, alpha: 0.15)
        assertColor(PersonalTripStatus.inProgress.badgeForegroundColor, red: 74, green: 222, blue: 128)
        assertColor(PersonalTripStatus.inProgress.badgeBackgroundColor, red: 34, green: 197, blue: 94, alpha: 0.12)
        assertColor(PersonalTripStatus.completed.badgeForegroundColor, red: 184, green: 194, blue: 189)
        assertColor(PersonalTripStatus.completed.badgeBackgroundColor, red: 255, green: 255, blue: 255, alpha: 0.06)
        assertColor(PersonalTripStatus.cancelled.badgeForegroundColor, red: 248, green: 113, blue: 113)
        assertColor(PersonalTripStatus.cancelled.badgeBackgroundColor, red: 239, green: 68, blue: 68, alpha: 0.10)
    }

    func testTripStatusBadgeShapeAndInputMatchApprovedContract() throws {
        let source = try productionSource(at: "Features/Trips/TripStatusBadge.swift")

        XCTAssertTrue(source.contains("private let status: PersonalTripStatus"))
        XCTAssertTrue(source.contains("init(status: PersonalTripStatus)"))
        XCTAssertTrue(source.contains("Capsule(style: .continuous)"), "radius-pill：胶囊圆角")
        XCTAssertFalse(source.contains("RoundedRectangle(cornerRadius: Radius.md"))
        XCTAssertFalse(source.contains("init(status: some StatusBadgeModel)"))
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
            Set(["HomeView.swift", "RouteDiscoveryView.swift", "MePageBackgroundOverlay.swift"]),
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

        let sharedPrimitives = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift")
        XCTAssertTrue(sharedPrimitives.contains(".ignoresSafeArea()"), "页面壳负责将沉浸式背景延伸到系统区域")
        XCTAssertTrue(sharedPrimitives.contains("immersiveSystemAreaContext"), "共享承载负责读取沉浸式页面系统区域")
        XCTAssertTrue(sharedPrimitives.contains("immersiveBottomContentPadding"), "共享承载负责把底部系统区域转换为内容避让")
        let routeDiscovery = try productionSource(at: "Features/Routes/RouteDiscoveryView.swift")
        XCTAssertTrue(routeDiscovery.contains(".immersiveSystemAreaContext()"), "路线发现页复用共享系统区域承载")
        let routeScene = try productionSource(at: "Features/Routes/Components/RouteScene.swift")
        XCTAssertTrue(routeScene.contains(".immersiveBottomContentPadding(Spacing.xl)"), "路线场景复用共享底部内容避让")
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
        let source = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Components/SharedPrimitives.swift")
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
        XCTAssertTrue(discovery.contains("输入路线名称或地区"), "搜索输入占位（6.3 钉入 spec）")
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

    /// 6.3 修订（R1/R2/L1/L2/S1/S2/S3/S6）：四个路线页面的状态文案与变体钉入 spec 后的契约。
    func testRoutePagesUseApprovedStateCopyAndVariants() throws {
        let source = try productionSource(at: "Features/Routes/RouteDiscoveryView.swift")
        let collectionStart = try XCTUnwrap(source.range(of: "struct RouteCollectionView: View"))
        let searchStart = try XCTUnwrap(source.range(of: "struct RouteSearchView: View"))
        let discoverySource = String(source[..<collectionStart.lowerBound])
        let collectionSource = String(source[collectionStart.lowerBound..<searchStart.lowerBound])
        let searchSource = String(source[searchStart.lowerBound...])

        XCTAssertTrue(discoverySource.contains("variant: .scene"), "重点路线失败态使用 ErrorView.scene")
        XCTAssertTrue(discoverySource.contains("暂时无法加载路线"), "重点路线失败态标题")
        XCTAssertTrue(discoverySource.contains("不会用缓存猜测替代真实路线资料。"), "重点路线失败态说明")
        XCTAssertTrue(discoverySource.contains("variant: .default"), "重点路线空态使用 EmptyState.default")
        XCTAssertFalse(discoverySource.contains("variant: .compactText"), "发现页不再用 compactText")
        XCTAssertTrue(discoverySource.contains("UIAccessibility.post"), "发现页按 PAGE-ROUTES 合同公告换页位置与首尾边界")
        XCTAssertFalse(discoverySource.contains("RoutePagingConfigurator"), "发现页不再保留旧 UIKit paging 配置器")

        XCTAssertTrue(collectionSource.contains("当前暂无可选择路线"), "全部路线空态标题（原型 h3）")
        XCTAssertTrue(collectionSource.contains("路线准备完成后会出现在这里。"), "全部路线空态说明（原型 p）")
        XCTAssertTrue(collectionSource.contains("icon: \"route\""), "全部路线空态 icon route 口径")
        XCTAssertTrue(collectionSource.contains("暂时无法加载全部路线"), "全部路线失败态标题")
        XCTAssertTrue(collectionSource.contains("不会使用缓存或猜测路线替代。"), "全部路线失败态说明")

        XCTAssertTrue(searchSource.contains("输入路线名称或地区"), "搜索框 placeholder（原型 searchbox）")
        XCTAssertTrue(searchSource.contains("初始状态不展示默认结果。"), "initial 说明（原型 empty-search p）")
        XCTAssertTrue(searchSource.contains("暂时无法搜索路线"), "搜索失败态标题")
        XCTAssertTrue(searchSource.contains("已保留关键词，不会用猜测结果替代。"), "搜索失败态说明")
        XCTAssertTrue(searchSource.contains("重新搜索"), "搜索失败重试文案")
        XCTAssertTrue(searchSource.contains("Walk 当前没有找到相关路线"), "noResults 说明钉入 spec")
    }

    /// 6.3 修订（S4/S5）：输入 change 经短延时防抖、submit 直通；搜索会话状态提升到 App 层以支持返回恢复。
    func testRouteSearchDebounceAndRestorationWiring() throws {
        let viewModel = try productionSource(at: "Features/Routes/RouteDiscoveryViewModel.swift")
        XCTAssertTrue(viewModel.contains("immediate: Bool"), "search 提供立即提交通道（submit 不经防抖）")
        XCTAssertTrue(viewModel.contains("Task.sleep"), "change 路径先经短延时防抖")

        let root = try productionSource(at: "App/RootView.swift")
        XCTAssertTrue(root.contains("routeSearchModel"), "App 层持有搜索会话状态")
        XCTAssertTrue(root.contains("routeSearchQuery"), "App 层持有搜索关键词")

        let search = try productionSource(at: "Features/Routes/RouteDiscoveryView.swift")
        let searchStart = try XCTUnwrap(search.range(of: "struct RouteSearchView: View"))
        let searchSource = String(search[searchStart.lowerBound...])
        XCTAssertTrue(searchSource.contains("@ObservedObject"), "搜索页接受外部持有的会话状态")
        XCTAssertTrue(searchSource.contains("@Binding"), "搜索页接受外部持有的 query")
    }

    /// 6.3 修订（D1）：RouteImageGallery 只读去事件化，页面不建私有图片网格，无图片查看器。
    func testRouteImageGalleryIsReadonlyWithoutViewer() throws {
        let gallery = try productionSource(at: "Features/Routes/Components/RouteImageGallery.swift")
        XCTAssertFalse(gallery.contains("Button"), "图片不建立按钮或打开状态")
        XCTAssertFalse(gallery.contains("onOpenImage"), "不产生打开图片事件")
        XCTAssertFalse(gallery.contains("?? \"路线图片\""), "不用默认文案补标题")

        let detail = try routeDetailPageSources()
        XCTAssertTrue(detail.contains("RouteBusinessComponents.RouteImageGallery("), "页面使用生产图片区组件")
        XCTAssertFalse(detail.contains("RouteImageGrid"), "不保留页面私有图片网格")
        XCTAssertFalse(detail.contains("RouteImageViewer"), "不建立图片查看器覆盖层")
        XCTAssertFalse(detail.contains("selectedImage"), "不持有图片覆盖层状态")

        let catalog = try productionSource(at: "App/Baseline/ComponentCatalog.swift")
        XCTAssertFalse(catalog.contains("RouteImageViewer"), "RouteImageViewer 退役后从目录移除")
    }

    // MARK: 批次 2/3 —— PAGE-LOGIN / TRIP-DETAIL / TRIPS / TRIP-DAY / TRIP-WEATHER / TRIP-EQUIPMENT

    // 6.4（A1/A3）后面板内部由生产 AuthPanel 组件拥有：玻璃面、关闭、legal note 均为组件权威。
    func testLoginEstablishesWalkAccountAfterFirstVerification() throws {
        let login = try productionSource(at: "Features/Profile/LoginView.swift")
        let authPanel = try productionSource(at: "Features/Profile/Components/AuthPanel.swift")
        XCTAssertTrue(authPanel.contains("首次验证通过后将直接建立或复用 Walk 账号"), "legal note 由 AuthPanel 组件拥有")
        XCTAssertTrue(authPanel.contains("WalkPanel(variant: .glass)"), "认证面板使用 WalkPanel 的 glass 表面变体")
        XCTAssertTrue(authPanel.contains("关闭登录"), "认证面板提供关闭按钮")
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

    func testTripDetailContainsRouteVersionAndMetricsInBody() throws {
        let detail = try productionSource(at: "Features/Trips/TripDetailView.swift")
        let routeCard = try productionSource(at: "Features/Trips/Components/TripRouteSummaryCard.swift")

        // PAGE-TRIP-DETAIL 正文承载路线入口卡；指标摘要并入走向卡、置于海拔图上方；版本卡已退役。
        XCTAssertFalse(detail.contains("TripBusinessComponents.TripRouteVersionCard("), "版本卡不再承载于 DETAIL 正文")
        XCTAssertTrue(routeCard.contains("TripBusinessComponents.TripRouteMetricsSummary("), "指标摘要并入走向卡置于海拔图上方")
        XCTAssertTrue(detail.contains("TripBusinessComponents.TripRouteSummaryCard("), "DETAIL 正文承载路线入口卡")
        XCTAssertTrue(detail.contains("routeEntryProjection("), "DETAIL 构造路线入口投影")
    }

    func testTripListEmptyStatePointsToRouteDiscovery() throws {
        let list = try productionSource(at: "Features/Trips/TripListView.swift")
        XCTAssertTrue(list.contains("先查找一条路线并生成个人行程"), "空态引导查找路线")
    }

    func testTripListUsesApprovedPageStatesAndSpacing() throws {
        let list = try productionSource(at: "Features/Trips/TripListView.swift")
        XCTAssertTrue(list.contains("UtilityPage(title:"), "二级页滚动与顶部间距由统一壳承载，页面不自写固定导航头间距")
        XCTAssertTrue(list.contains("variant: .default"), "全局空态使用 EmptyState.default")
        XCTAssertTrue(list.contains("variant: .page"), "加载失败使用 ErrorView.page")
        XCTAssertFalse(list.contains("variant: .section"), "PAGE-TRIPS 全局状态不得使用 Section 变体")
        XCTAssertFalse(list.contains("个人行程找回"), "页面标题只呈现一次：正文不重复标题块与 kicker")
        XCTAssertFalse(list.contains("当前行程和历史行程在同一页面分组展示。"), "正文不重复纯解释性副标题")
        XCTAssertTrue(list.contains("无法加载行程列表"), "错误态标题钉入 spec")
        XCTAssertTrue(list.contains("不会使用缓存或离线行程补齐。"), "错误态说明钉入 spec")
        XCTAssertTrue(list.contains("icon: \"calendar\""), "全局空态图标 calendar（原型证据）")
        XCTAssertFalse(list.contains(".refreshable"), "页面不提供下拉刷新")
        XCTAssertFalse(list.contains("variant: .compactText"), "分组空态是纯文本提示，非 EmptyState 变体")
    }

    /// PAGE-TRIPS / TripListRow 6.2 修订：行首 RouteMark（42×42 薄荷软底 route 图标，无封面槽），
    /// Copy 为 TripName + DetailLine 单行「路线名 · shortDate 区间」。
    func testTripListRowUsesRouteMarkAndSingleDetailLine() throws {
        let row = try productionSource(at: "Features/Trips/Components/TripListRow.swift")
        XCTAssertTrue(row.contains("RouteMark"), "行首元素命名 RouteMark")
        XCTAssertTrue(row.contains("42"), "RouteMark 42 × 42")
        XCTAssertTrue(row.contains("AppColors.interactionBackground"), "薄荷软底")
        XCTAssertFalse(row.contains("coverAvailable"), "不设封面槽")
        XCTAssertFalse(row.contains("TripDeterministicCoverSurface"), "行内不消费封面")
        XCTAssertTrue(row.contains("lineLimit(1)"), "DetailLine 单行")
        XCTAssertTrue(row.contains("· "), "DetailLine 以「路线名 · 日期区间」组合")
    }

    /// FocusTripSummary 沉底左下修订：
    /// 信息块锚定左下、全局一级导航之上；路线名、起终点一句话描述、
    /// 距离/爬升/用时三指标、天气自上而下排列；weather 省略时仍渲染两个中性槽位。
    func testFocusTripSummaryUsesSingleLeftInfoBlockAndNeutralWeatherSlots() throws {
        let focus = try productionSource(at: "Features/Home/Components/FocusTripSummary.swift")
        XCTAssertTrue(focus.contains("VStack(alignment: .leading, spacing: Spacing.lg)"), "左侧单一信息块纵向排列")
        XCTAssertTrue(focus.contains("alignment: .bottomLeading"), "信息块沉底左下")
        XCTAssertTrue(focus.contains("contentBottomPadding"), "信息块不贴底，位于全局一级导航之上")
        XCTAssertTrue(focus.contains("label: \"累计爬升\""), "保留累计爬升指标")
        XCTAssertTrue(focus.contains("label: \"预计用时\""), "保留预计用时指标")
        XCTAssertTrue(focus.contains("routeIdentityMaxWidth: CGFloat = 290"), "RouteName 最大宽 290")
        XCTAssertTrue(focus.contains(".font(.displayTitle)"), "RouteName 用 displayTitle 档")
        XCTAssertFalse(focus.contains(".font(.sceneTitle)"), "不再使用 sceneTitle")
        XCTAssertTrue(focus.contains("本次未提供天气摘要"), "省略时中性槽位一")
        XCTAssertTrue(focus.contains("行程其他内容仍可查看"), "省略时中性槽位二")
        XCTAssertFalse(focus.contains("if let weather = model.weather {"), "weather 省略仍渲染 WeatherSummary")

        let weather = try productionSource(at: "Features/Home/Components/WeatherSummary.swift")
        XCTAssertTrue(weather.contains("case omitted"), "字段省略不得解释为 unavailable")
        XCTAssertFalse(weather.contains("case omitted =>"), "omitted 是独立状态")
    }

    func testTripDayKeepsServerActionAndPointOrderAndEdgeHint() throws {
        let browse = try productionSource(at: "Features/Trips/TripBrowseView.swift")
        XCTAssertTrue(browse.contains("boundaryCue"), "日尾边界提示由浏览页承担")
        let plan = try productionSource(at: "Features/Trips/TripBrowsePagePlan.swift")
        XCTAssertTrue(plan.contains("presentationItems"), "行动按后端 sequence 原序展示")
        XCTAssertTrue(plan.contains("pointItems"), "点位按单一 sequence 流展示")
        XCTAssertFalse(plan.contains("departureTransportActions"), "客户端不推断去程交通槽位")
        XCTAssertFalse(plan.contains("groupedPoints"), "客户端不按类别重排点位")
        XCTAssertTrue(browse.contains("本次行程只有一天"), "一日行程边界提示")
        XCTAssertTrue(browse.contains("到达底部后继续上滑查看下一日"), "非末日边界提示指向边界越界翻页")
        XCTAssertTrue(browse.contains("已到行程最后一天"), "末日边界提示")
        let day = try productionSource(at: "Features/Trips/Components/TripDayArrangement.swift")
        XCTAssertTrue(day.contains("spacing: Spacing.md"), "内部滚动区行距使用 canonical md token")
        XCTAssertFalse(day.contains("Spacing.listItemGap"), "禁止旧 listItemGap alias")
    }

    /// PAGE-TRIP-WEATHER（6.1 修订）：逐日卡唯一数据源是冻结自然日天气（detail.days[].weather），
    /// 概况与重要影响来自 weatherOverview 合同；不从预报时段或天气关联聚合派生。
    func testTripWeatherBuildsDailyCardsFromFrozenDayWeather() throws {
        let source = try productionSource(at: "Features/Trips/TripDayWeatherViews.swift")
        XCTAssertTrue(source.contains("TripBusinessComponents.DailyWeatherCard("), "逐日卡消费冻结自然日天气")
        XCTAssertTrue(source.contains("detail.days"), "逐日数据源为行程详情冻结自然日")
        XCTAssertTrue(source.contains("importantImpacts"), "重要影响来自概况合同")
        XCTAssertTrue(source.contains("trip_weather_projection_unavailable"), "后端暂不可用错误使用稳定错误码判断")
        XCTAssertFalse(source.contains("forecast"), "不从预报时段聚合派生逐日字段")
        XCTAssertFalse(source.contains("weatherAssociations"), "不从天气关联聚合派生")
        XCTAssertFalse(source.contains("private struct DailyTripWeatherCard"), "不建立页面私有逐日天气卡")
        XCTAssertFalse(source.contains("private struct WeatherOverview"), "不建立页面私有天气概况")
    }

    func testTripEquipmentFollowsSectionedSpec() throws {
        let equipment = try productionSource(at: "Features/Trips/TripEquipment.swift")
        // PAGE-TRIP-EQUIPMENT 权威：页面由统一二级页壳承载（固定导航头由壳内部装配），
        // 清单不可用用 ErrorView.page（非 UnavailableStateView），保存失败经 InlineEquipmentEditor.saveError。
        XCTAssertTrue(equipment.contains("UtilityPage("), "页面由统一二级页壳承载（固定导航头由壳内部装配）")
        XCTAssertTrue(equipment.contains("title: \"行程装备\""), "页题交由壳标题区")
        XCTAssertTrue(equipment.contains("本次清单为空"), "空态标题钉入 spec（6.4 T6）")
        XCTAssertTrue(equipment.contains("新增本次装备"), "次级操作新增")
        XCTAssertTrue(equipment.contains("管理我的装备"), "次级操作管理")
        XCTAssertTrue(equipment.contains("重新核对已有状态"), "重新核对")
        XCTAssertTrue(equipment.contains("当前行程只读"), "只读态标题钉入 spec（6.4 T1）")
        // 四项概况指标由 TripEquipmentOverview 组件拥有（PAGE-TRIP-EQUIPMENT 禁止 Page 直接拥有概况内部指标），
        // 文案权威在组件 spec，断言改查组件源码而非页面源码。
        let overview = try productionSource(at: "Features/Trips/Components/TripEquipmentOverview.swift")
        XCTAssertTrue(overview.contains("label: \"装备条目\""), "四指标格条目数")
        XCTAssertTrue(overview.contains("预计总重量"), "四指标格完整重量")
        XCTAssertTrue(overview.contains("label: \"未确认已有\""), "四指标格未确认")
        XCTAssertTrue(equipment.contains("ErrorView("), "清单不可用使用 ErrorView.page")
        XCTAssertTrue(equipment.contains("title: \"无法显示行程装备\""), "清单不可用有明确文案")
        XCTAssertTrue(equipment.contains("Task { await viewModel.load() }"), "清单不可用提供重试")
        XCTAssertTrue(equipment.contains("saveError: viewModel.errorMessage"), "保存失败经 InlineEquipmentEditor.saveError 接收后端失败原因")
    }

    // MARK: 批次 6.4 —— PAGE-ME / PAGE-LOGIN / PAGE-EQUIPMENT-EDIT / PAGE-MY-EQUIPMENT / PAGE-TRIP-EQUIPMENT / PAGE-TRIP-CREATE

    /// PAGE-ME 6.4 修订（M1-M5）：页题字档、游客态 copy、AvatarButton unavailable、最小高、可访问名。
    func testProfileUsesApprovedPageTitleGuestCopyAndAvatarStates() throws {
        let profile = try productionSource(at: "Features/Profile/ProfileView.swift")
        XCTAssertFalse(profile.contains(".ornament(31"), "登录态页头标题使用 font-pageTitle，不再自定 ornament 档")
        XCTAssertTrue(profile.contains("登录后查看个人行程、行程日历、个人装备和装备清单。"), "游客态说明 copy 钉入 spec")
        XCTAssertTrue(profile.contains("minHeight: 440"), "游客态最小高 440 逻辑点")
        XCTAssertTrue(profile.contains("打开个人与设置"), "AvatarButton 可访问名为「打开个人与设置」")
        XCTAssertTrue(profile.contains("state: .unavailable"), "profileError 回退进入 AvatarButton unavailable 重试")
        XCTAssertFalse(profile.contains("arrow.clockwise"), "profileError 不再用重试图标按钮")
    }

    /// PAGE-LOGIN：FormField 容器与 TextInput 容器不可嵌套（双层边框缺陷）；背景环境动画用 Lottie 承载。
    func testLoginUsesSingleLayerFormControlsAndAnimatedBackground() throws {
        let authPanel = try productionSource(at: "Features/Profile/Components/AuthPanel.swift")
        XCTAssertFalse(
            authPanel.range(of: "\\bTextInput\\(", options: .regularExpression) != nil,
            "FormField 自带容器样式，嵌套自带容器的 TextInput 会产生双层边框"
        )
        XCTAssertTrue(authPanel.contains("TextField("), "FormField 内使用裸 TextField 控件")
        XCTAssertTrue(authPanel.contains("@FocusState"), "焦点态由 AuthPanel 持有并驱动 FormField 聚焦描边")

        let login = try productionSource(at: "Features/Profile/LoginView.swift")
        XCTAssertTrue(login.contains("LottieView"), "背景环境动画使用 Lottie 承载（规范：极光呼吸层循环动画）")
        XCTAssertTrue(login.contains("accessibilityReduceMotion"), "减少动态效果时环境动画不渲染（PAGE-LOGIN 结构验收）")
    }

    /// PAGE-LOGIN 6.4 修订（A1/A2/A3）：消费生产 AuthPanel、焦点确认双态、品牌行；RootView 修复误判。
    func testLoginConsumesProductionAuthPanelWithFocusConfirmation() throws {
        let login = try productionSource(at: "Features/Profile/LoginView.swift")
        XCTAssertTrue(login.contains("AuthPanel("), "登录页消费生产 AuthPanel 组件")
        XCTAssertFalse(login.contains("WalkPanel(surface: .glass)"), "不再私有重建认证面板玻璃面")
        XCTAssertTrue(login.contains("AuthPanelProjection("), "登录页构造 AuthPanel 投影")
        XCTAssertTrue(login.contains(".confirmingFocus"), "提供 confirmingFocus 校准态映射")
        XCTAssertTrue(login.contains(".focusError"), "提供 focusError 校准态映射")
        XCTAssertTrue(login.contains("onRetryFocusTrip"), "焦点确认失败提供重试事件")
        XCTAssertTrue(login.contains("retryAvailableAt: activeRetryAvailableAt"), "发送限流时间投影给 AuthPanel")
        XCTAssertTrue(login.contains("viewModel.focusErrorMessage"), "焦点确认失败原因投影给 AuthPanel")
        XCTAssertFalse(login.contains("首次验证通过后直接建立 Walk 账号"), "legal note 由 AuthPanel 组件拥有")
        XCTAssertTrue(login.contains("ROUTE 01 · PERSONAL JOURNEY"), "品牌行补齐「Walk / ROUTE 01 · PERSONAL JOURNEY」")

        let authPanel = try productionSource(at: "Features/Profile/Components/AuthPanel.swift")
        XCTAssertTrue(authPanel.contains("ScrollView"), "AuthPanel 在短屏、键盘或大字号下内部滚动")
        XCTAssertTrue(authPanel.contains("ViewThatFits"), "AuthPanel 内容自高贴底，内容超出最大高时才内部滚动（PAGE-LOGIN：最大高只是上限，不是目标高度）")

        let root = try productionSource(at: "App/RootView.swift")
        XCTAssertTrue(root.contains("onConfirmFocusTrip"), "RootView 提供焦点确认处理器")
        // W4：确认结果由 AuthenticationFlow 持有，行为由 AuthenticationFlowTests 覆盖。
        XCTAssertTrue(root.contains("authFlow.consumeFocusConfirmation()"), "execute(.homeStart) 消费认证链路确认结果，不再自行 catch 落回首页")
    }

    /// PAGE-EQUIPMENT-EDIT 6.4 修订（E1）：页题说明钉入原型 copy。
    func testEquipmentEditPageTitleMatchesPinnedCopy() throws {
        let source = try productionSource(at: "Features/Equipment/AddEquipmentView.swift")
        XCTAssertTrue(source.contains("本页只维护装备名称、实际拥有数量和可选的单件重量。"), "页题说明钉入 spec")
    }

    /// PAGE-MY-EQUIPMENT 6.4 修订（L1/L2/L4）：空态 copy 钉入原型；页面不提供下拉刷新。
    func testMyEquipmentUsesApprovedEmptyStatesAndNoRefresh() throws {
        let source = try productionSource(at: "Features/Equipment/EquipmentListView.swift")
        XCTAssertTrue(source.contains("还没有个人装备"), "装备空态标题钉入 spec")
        XCTAssertTrue(source.contains("没有个人装备也不会阻断行程生成。"), "装备空态说明钉入 spec")
        XCTAssertTrue(source.contains("还没有用户装备清单"), "清单空态标题钉入 spec")
        XCTAssertTrue(source.contains("可以按自己的习惯创建一日、三日或五日清单。"), "清单空态说明钉入 spec")
        XCTAssertFalse(source.contains(".refreshable"), "页面不提供下拉刷新")
    }

    /// PAGE-TRIP-EQUIPMENT 6.4 修订（T1/T2/T3/T4/T5/T6/T7）：文案钉入、删除确认组件化、共享 DateCopy、禁刷新。
    func testTripEquipmentUsesApprovedStateCopyAndConfirmationDialog() throws {
        let equipment = try productionSource(at: "Features/Trips/TripEquipment.swift")
        XCTAssertTrue(equipment.contains("只有规划中的行程可以调整本次装备。"), "只读态说明钉入 spec")
        XCTAssertTrue(equipment.contains("本次清单是独立副本"), "独立快照标题钉入 spec")
        XCTAssertTrue(equipment.contains("增删改不会影响个人装备、用户装备清单或系统标准装备清单。"), "独立快照说明钉入 spec")
        XCTAssertTrue(equipment.contains("预计总重量 0 kg。规划中的行程可以新增只属于当前行程的装备。"), "空列表说明钉入 spec")
        XCTAssertFalse(equipment.contains("部分重量未计入"), "概况内部指标 Notice 不由页面拥有")
        XCTAssertFalse(equipment.contains(".confirmationDialog("), "删除确认使用 ConfirmationDialog 组件而非系统 API")
        XCTAssertTrue(equipment.contains("ConfirmationDialog("), "删除确认使用生产组件")
        XCTAssertFalse(equipment.contains(".refreshable"), "页面不提供下拉刷新")
        XCTAssertTrue(equipment.contains("DateCopy."), "行程上下文日期使用共享 DateCopy 口径")

        let row = try productionSource(at: "Features/Trips/Components/TripListRow.swift")
        XCTAssertTrue(row.contains("DateCopy."), "TripListRow 复用共享 DateCopy")
        XCTAssertFalse(row.contains("private static func shortDate"), "私有 shortDate 收敛为共享实现")

        let dateCopy = try productionSource(at: "Features/Shared/DateCopy.swift")
        XCTAssertTrue(dateCopy.contains("月"), "shortDate 口径「M月D日」")
        XCTAssertTrue(dateCopy.contains("—"), "区间用「—」连接")
    }

    /// PAGE-TRIP-CREATE 6.4 修订（C1/C2/C3/C4）：版本冲突区、日期模板与城市错误 copy、去除多余 SectionHeader。
    func testTripCreateShowsVersionConflictRegionAndPinnedCopy() throws {
        let source = try productionSource(at: "Features/Trips/CreateTripView.swift")
        XCTAssertTrue(source.contains("route_version_conflict"), "识别 409 route_version_conflict 进入 versionConflict 态")
        XCTAssertTrue(source.contains("refreshRouteVersion"), "VersionConflictRegion 承载重读上下文动作")
        XCTAssertTrue(source.contains("viewCurrentRoute"), "VersionConflictRegion 承载返回路线详情动作")
        XCTAssertTrue(source.contains("一日路线固定只生成"), "一日日期模板 copy 钉入 spec")
        XCTAssertTrue(source.contains("去程、徒步和返程都在 D1 内完成。"), "一日日期模板原型 copy 完整钉入 spec")
        XCTAssertTrue(source.contains("多日路线的实际自然日和结束日期由生成结果返回，生成前不根据建议天数或参考分日推算。"), "多日日期模板 copy 钉入 spec")
        XCTAssertTrue(source.contains("请先填写城市，再生成个人行程。"), "出发城市错误文案钉入 spec")
        XCTAssertFalse(source.contains("SectionHeader(title: \"必要信息\")"), "RequiredInputSection 只排列必要输入，无 SectionHeader")
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
        // 按 PAGE-ME / PAGE-ACCOUNT-MENU 权威，查看入口、脱敏账号与关于行由 TripCalendarCard / AccountMenuView 承载，不在我的页。
        let calendarCard = try productionSource(at: "Features/Shared/Components/TripCalendarCard.swift")
        XCTAssertTrue(calendarCard.contains("查看全部"), "行程日历查看入口在 TripCalendarCard 组件内")
        // 按 PAGE-ACCOUNT-MENU 权威，脱敏账号摘要由设置主页身份头部 ProfileIdentityHeader 组件承载。
        let identityHeader = try productionSource(at: "Features/Profile/Components/ProfileIdentityHeader.swift")
        XCTAssertTrue(identityHeader.contains("maskedPhone"), "脱敏账号摘要在账户菜单身份头部组件内")
        let accountMenu = try productionSource(at: "Features/Profile/AccountMenuView.swift")
        XCTAssertTrue(accountMenu.contains("ProfileIdentityHeader("), "设置主页使用身份头部组件")
        XCTAssertTrue(accountMenu.contains("关于 Walk"), "关于行文案在账户菜单页内")
        XCTAssertFalse(accountMenu.contains("isCloseActionPresented"), "账户菜单不显示右上角叉号")
        XCTAssertFalse(accountMenu.contains("accountSecurity"), "账号与安全已从设置主页移除")
        XCTAssertFalse(profile.contains("fullScreenCover"), "模态承载在 RootView，我的页自身不弹覆盖层")
        XCTAssertTrue(profile.contains("onOpenAccountMenu("), "头像入口弹出 PAGE-ACCOUNT-MENU 模态")
    }

    func testSettingsDetailSheetsFollowModalPageSpec() throws {
        let entryPages = try profileEntrySources()

        XCTAssertFalse(entryPages.contains("AccountSecurityView"), "账号与安全二级页已退役")
        XCTAssertTrue(entryPages.contains("UtilityPage("), "二级设置页使用统一页面壳 UtilityPage，不再自建骨架")
        XCTAssertFalse(entryPages.contains("SettingsDetailPage"), "旧设置页壳已退役")
        XCTAssertTrue(entryPages.contains("SurfaceElevated"), "二级设置页 Section 使用浅层表面")
        XCTAssertTrue(entryPages.contains("EntrySettingsRow"), "二级设置页使用左右信息行")
        XCTAssertTrue(entryPages.contains("surfaceDivider"), "二级设置页行间使用横线分隔")
        XCTAssertTrue(entryPages.contains("反馈内容") && entryPages.contains("提交"), "反馈页仅保留内容与提交")
        XCTAssertFalse(entryPages.contains("常见问题"), "反馈页不再包含常见问题")
        XCTAssertFalse(entryPages.contains("EntryPageContract.feedbackFields[0]"), "反馈页不再包含分类")
        XCTAssertTrue(entryPages.contains("Walk 是一款面向徒步爱好者的行程规划应用"), "关于页使用已确认介绍")
        XCTAssertTrue(entryPages.contains("CFBundleShortVersionString"), "关于页展示当前版本号")
        XCTAssertFalse(entryPages.contains("EntrySettingsRow(title: \"版本\""), "关于页版本号居中展示，不使用左右信息行")
    }

    func testHelpFeedbackSubmitClearsContentWithLocalSuccess() async throws {
        let source = try profileEntrySources()
        XCTAssertTrue(source.contains("feedbackSubmitted"), "反馈提交提供本地成功反馈")
        XCTAssertTrue(source.contains("feedback = \"\""), "提交后清空反馈内容")
        XCTAssertFalse(source.contains("uploadFeedback") && source.contains("apiClient"), "反馈提交不发起网络请求")
    }

    func testEquipmentListFollowsPageStructureSpec() throws {
        let list = try productionSource(at: "Features/Equipment/EquipmentListView.swift")
        XCTAssertFalse(list.contains("长期个人资产"), "二级页页题不含宣传性 kicker")
        XCTAssertTrue(list.contains("装备与清单"), "页题区标题")
        XCTAssertTrue(list.contains("个人装备记录实际拥有数量和可选单件重量；清单按清单内数量汇总预计总重量。"), "页题区说明")
        // PAGE-MY-EQUIPMENT 权威页签为 SegmentedControl 通用组件，非原生 .pickerStyle(.segmented)；
        // 装备行未填写重量文案属 EquipmentListRow 组件，重命名文案属 InlineListNameEditor 组件。
        XCTAssertTrue(list.contains("SegmentedControl("), "装备/清单页签使用 SegmentedControl 组件")
        let equipmentRow = try productionSource(at: "Features/Equipment/Components/EquipmentListRow.swift")
        XCTAssertTrue(equipmentRow.contains("重量未填写"), "装备行未填写重量文案在组件内")
        let listNameEditor = try productionSource(at: "Features/Equipment/Components/InlineListNameEditor.swift")
        XCTAssertTrue(listNameEditor.contains("重命名装备清单"), "清单行内重命名文案在组件内")
        XCTAssertTrue(list.contains("新增个人装备"), "装备页签底部固定主按钮")
        XCTAssertTrue(list.contains("创建装备清单"), "清单页签底部固定主按钮")
        XCTAssertTrue(list.contains("还没有个人装备"), "装备空态（6.4 L1 钉入原型 copy）")
        XCTAssertTrue(list.contains("还没有用户装备清单"), "清单空态（6.4 L2 钉入原型 copy）")
        XCTAssertFalse(
            regexMatches(#"NavigationLink\s*\{[^}]*EquipmentListDetailView"#, in: list),
            "清单详情不得再以 push 页实现，改为行内展开"
        )
    }

    func testEquipmentEditFollowsPageStructureSpec() throws {
        let edit = try productionSource(at: "Features/Equipment/AddEquipmentView.swift")
        XCTAssertFalse(edit.contains("写入长期个人资产"), "二级页页题不含宣传性 kicker")
        XCTAssertTrue(edit.contains("新增一件装备"))
        XCTAssertTrue(edit.contains("更新装备"))
        XCTAssertTrue(edit.contains("只维护装备名称、实际拥有数量和可选的单件重量。"))
        XCTAssertTrue(edit.contains("请输入装备名称"))
        XCTAssertTrue(edit.contains("请输入大于零的克重"))
        XCTAssertFalse(edit.contains("if #available(iOS 17.0"), "iOS 16 也必须展示装备名称输入")
        XCTAssertTrue(edit.contains("删除后会从用户装备清单移除，但不会修改已经生成的行程装备。"))
        XCTAssertTrue(edit.contains("\"保存\""), "底部固定主按钮保存")
        XCTAssertTrue(edit.contains("bottomFixed:"), "固定底部动作交由壳的 bottomFixed 插槽（safeAreaInset 由壳统一）")
    }

    func testEntryFormPageSupportsPageHeadingWithoutBreakingSharedForm() throws {
        let pages = try profileEntrySources()
        XCTAssertTrue(pages.contains("guide: String? = nil"), "引导语参数可选")
        XCTAssertTrue(pages.contains("pageTitle: String? = nil"), "页内标题参数可选")
        XCTAssertTrue(pages.contains("fieldSpacing: CGFloat = Spacing.lg"), "字段间距参数可配置")
    }

    func testEntryFormPageUsesUnifiedNavigationShell() throws {
        let pages = try profileEntrySources()
        XCTAssertTrue(pages.contains("UtilityPage("), "设置子页与全 App 二级页共用统一页面壳 UtilityPage")
        XCTAssertFalse(pages.contains("UtilityNavigationHeader("), "页面不自装配导航行，返回壳由 UtilityPage 统一承载")
        XCTAssertFalse(pages.contains(".toolbar(.hidden"), "隐藏系统导航栏/标签页由壳统一处理")
        XCTAssertFalse(pages.contains(".navigationTitle"), "不再依赖系统导航标题")
        XCTAssertFalse(pages.contains("navigationBarTitleDisplayMode"), "不再依赖系统导航栏")
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
        let summary = try productionSource(at: "Features/Routes/Components/RouteSummary.swift")
        XCTAssertTrue(summary.contains(".font(.heroTitle)"), "路线概要名称使用 hero 级标题")
        XCTAssertTrue(source.contains("spacing: Spacing.md"), "信息列表条目行间距使用 canonical md token")
        XCTAssertFalse(source.contains("Spacing.listItemGap"), "禁止旧 listItemGap alias")
    }

    func testRouteMapDetailSheetHasDismissControl() throws {
        let source = try productionSource(at: "Features/Routes/RouteDetailView.swift")
        XCTAssertTrue(source.contains("RouteBusinessComponents.RoutePointDetail("), "点位详情浮层由生产组件承载")

        let component = try productionSource(at: "Features/Routes/Components/RoutePointDetail.swift")
        XCTAssertTrue(component.contains("systemName: \"xmark\""), "点位详情浮层提供关闭按钮")
        XCTAssertTrue(component.contains("关闭点位详情"), "关闭按钮可访问标签")
        XCTAssertTrue(component.contains("popoverCard"), "点位详情使用 popover 式悬浮卡承载，不再全宽铺底")
        XCTAssertTrue(component.contains("onTapGesture(perform: onDismiss)"), "点击遮罩关闭悬浮卡")
    }

    func testSpacingSourceUsesApprovedContractCanonicalNames() throws {
        let source = try productionSource(at: "../Packages/WalkDesignSystem/Sources/WalkDesignSystem/Theme/Spacing.swift")
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

    /// Token 类守卫使用：覆盖 Features 下全部源码，包括业务组件目录。
    /// Token 约束（tokens.md「使用限制」）对页面和组件同样适用，不能沿用页面级规则的组件豁免。
    private func allFeatureSources() throws -> [(name: String, source: String)] {
        let featureRoot = try XCTUnwrap(walkRoot().appendingPathComponent("Features"))
        var result: [(name: String, source: String)] = []
        let enumerator = FileManager.default.enumerator(at: featureRoot, includingPropertiesForKeys: nil)
        for case let fileURL as URL in enumerator ?? NSEnumerator() where fileURL.pathExtension == "swift" {
            let relative = String(fileURL.standardizedFileURL.path.dropFirst(featureRoot.standardizedFileURL.path.count + 1))
            result.append((relative, try String(contentsOf: fileURL, encoding: .utf8)))
        }
        return result.sorted { $0.name < $1.name }
    }

    private func featureFiles() throws -> [(name: String, source: String)] {
        let featureRoot = try XCTUnwrap(walkRoot().appendingPathComponent("Features"))
        let fileManager = FileManager.default
        var result: [(name: String, source: String)] = []
        guard let enumerator = fileManager.enumerator(at: featureRoot, includingPropertiesForKeys: nil) else {
            return result
        }
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            // Features/*/Components/ 是业务组件（由组件目录与基线体系治理），不参与页面级规则扫描
            if fileURL.path.contains("/Features/") && fileURL.path.contains("/Components/") { continue }
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
