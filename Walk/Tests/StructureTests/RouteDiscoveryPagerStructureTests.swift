import XCTest
@testable import Walk

/// 结构测试强制：PAGE-ROUTES（路线发现）的 RoutePager 必须是纵向 scroll snap 分页
/// （`docs/ui/pages/PAGE-ROUTES/spec.md`：RoutePager 是唯一纵向滚动拥有者，纵向 scroll snap，首尾不循环；
/// 禁止项明确不允许横向分页）。
final class RouteDiscoveryPagerStructureTests: XCTestCase {

    /// scroll snap 的吸附单位是分页容器高度：卡片高度必须与分页视口一致，
    /// 否则第二屏起每次吸附累积偏差，卡片与视口错位（不满屏/露缝）。
    func testPagerCardHeightEqualsPagingViewport() {
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 800), 800)
        XCTAssertEqual(RouteDiscoveryLayout.cardHeight(for: 0), 0)
    }

    func testRoutePagerUsesVerticalScrollSnapPaging() throws {
        let source = try featuresSource("Routes/RouteDiscoveryView.swift")
        XCTAssertTrue(
            source.contains(".scrollTargetBehavior(.paging)"),
            "PAGE-ROUTES 规范要求 RoutePager 使用纵向 scroll snap 分页（.scrollTargetBehavior(.paging)）。"
        )
        XCTAssertTrue(
            source.contains("ScrollView(.vertical"),
            "PAGE-ROUTES 规范要求 RoutePager 的滚动轴为纵向。"
        )
        XCTAssertFalse(
            source.contains(".tabViewStyle(.page"),
            "PAGE-ROUTES 规范禁止把整屏分页承载在横向 TabView(.page) 上。"
        )
    }

    // MARK: 文件发现

    /// 本文件位于 `Walk/Tests/StructureTests/` → 上三级为 Walk，再进 Features。
    private static func featuresRootURL() throws -> URL {
        let testFileURL = URL(fileURLWithPath: #filePath)
        return testFileURL
            .deletingLastPathComponent()   // StructureTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // Walk
            .appendingPathComponent("Features")
    }

    private func featuresSource(_ relativePath: String) throws -> String {
        let root = try Self.featuresRootURL()
        return try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}

/// 路线发现页焦点顺序：只有已定位当前页时才隐藏其他页。
final class RouteDiscoveryAccessibilityTests: XCTestCase {
    func testUnlocatedPagerKeepsEveryCardAccessible() {
        for index in 0..<3 {
            XCTAssertFalse(RouteDiscoveryView.hidesFromAccessibility(index: index, activeIndex: nil))
        }
    }

    func testLocatedPagerHidesOnlyNonCurrentCards() {
        XCTAssertFalse(RouteDiscoveryView.hidesFromAccessibility(index: 1, activeIndex: 1))
        XCTAssertTrue(RouteDiscoveryView.hidesFromAccessibility(index: 0, activeIndex: 1))
        XCTAssertTrue(RouteDiscoveryView.hidesFromAccessibility(index: 2, activeIndex: 1))
    }
}

/// 登录页弹出与键盘动画的性能约束。
///
/// 缺陷：LoginView 用 1 秒循环刷新整页 @State `now`，导致场景、Lottie、面板每秒整页重算，
/// 与 fullScreenCover 弹出、键盘升起动画叠加，真机明显卡顿；背景随键盘安全区逐帧重新布局。
final class LoginPresentationPerformanceStructureTests: XCTestCase {
    private func loginSource() throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Features/Profile/LoginView.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testLoginPageHasNoPerSecondWholePageRefresh() throws {
        let source = try loginSource()
        XCTAssertFalse(
            source.contains("while !Task.isCancelled"),
            "登录页不得用常驻循环定时刷新整页状态"
        )
        XCTAssertTrue(source.contains(".task(id: nextCooldownDeadline)"), "冷却刷新只在存在未到期冷却时触发")
    }

    func testLoginBackgroundDoesNotRelayoutWithKeyboard() throws {
        let source = try loginSource()
        let scene = try XCTUnwrap(source.range(of: "LoginNightRidgeScene(phase: viewModel.phase)"))
        let tail = source[scene.upperBound...].prefix(260)
        XCTAssertTrue(tail.contains(".ignoresSafeArea(.keyboard)"), "背景场景不随键盘重新布局")
        XCTAssertTrue(tail.contains(".drawingGroup()"), "静态背景合成为单层")
    }
}
