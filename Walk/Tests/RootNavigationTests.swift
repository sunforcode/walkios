import SwiftUI
import XCTest
import WalkData
import WalkDesignSystem
@testable import Walk

@MainActor
final class RootNavigationTests: XCTestCase {
    func testAppShellStartsOnTripsWithFourApprovedTabs() {
        let sut = AppShellState()

        XCTAssertEqual(sut.selectedTab, .trips)
        XCTAssertEqual(AppTab.allCases.map(\.rawValue), ["trips", "routes", "equipment", "profile"])
        XCTAssertEqual(AppTab.allCases.map(\.title), ["行程", "路线", "装备", "我的"])
    }

    func testAppShellKeepsIndependentNavigationPaths() {
        var sut = AppShellState()
        sut.setPath([.routeDetail("route-1")], for: .routes)
        sut.selectTab(.trips)

        XCTAssertEqual(sut.path(for: .routes), [.routeDetail("route-1")])
        XCTAssertTrue(sut.path(for: .trips).isEmpty)
    }

    func testShowRouteDiscoverySelectsRoutesTabAtRoot() {
        var sut = AppShellState()
        sut.setPath([.routeDetail("route-1")], for: .routes)

        sut.showRouteDiscovery()

        XCTAssertEqual(sut.selectedTab, .routes)
        XCTAssertTrue(sut.path(for: .routes).isEmpty)
    }

    func testShowRouteListSelectsRoutesTabAndTargetsAllRoutes() {
        var sut = AppShellState()
        sut.setPath([.routeDetail("route-1")], for: .routes)

        sut.showRouteList()

        XCTAssertEqual(sut.selectedTab, .routes)
        XCTAssertEqual(sut.path(for: .routes), [.routeList])
        XCTAssertFalse(sut.routeListShowsBackEntry, "行程清单找路线落点为任务栈根页，不显示返回入口")
    }

    func testRouteListBackEntryVisibilityIsOwnedByShell() {
        var sut = AppShellState()

        sut.routeListShowsBackEntry = true
        sut.showRouteDiscovery()
        XCTAssertFalse(sut.routeListShowsBackEntry, "回到发现页后来源上下文复位")

        sut.routeListShowsBackEntry = true
        sut.showRouteList()
        XCTAssertFalse(sut.routeListShowsBackEntry, "任务栈根页进入不显示返回入口")
    }

    func testCreateSuccessReplacesCreateDestinationWithTripDetail() {
        var sut = AppShellState()
        sut.setPath(
            [.routeDetail("route-1"), .createTrip(routeID: "route-1")],
            for: .routes
        )

        sut.replaceTop(with: .tripDetail("trip-1"), in: .routes)

        XCTAssertEqual(
            sut.path(for: .routes),
            [.routeDetail("route-1"), .tripDetail("trip-1")]
        )
    }

    func testShellUsesTransparentTabBarAndStandardHitTarget() {
        XCTAssertEqual(RootNavigation.minimumHitSize, 44)

        let appearance = RootNavigation.makeTabBarAppearance()
        XCTAssertEqual(appearance.backgroundEffect, nil)
        XCTAssertTrue(appearance.backgroundColor == nil || appearance.backgroundColor?.cgColor.alpha == 0)
        XCTAssertTrue(appearance.shadowColor == nil || appearance.shadowColor?.cgColor.alpha == 0)
    }

    func testProfileHeaderUsesStandardAvatarEntrySize() {
        XCTAssertEqual(AvatarButtonVariant.pageHeader.size, RootNavigation.minimumHitSize)
    }

    func testCoreDestinationsRemainTypeSafeAndMappedToApprovedPages() {
        XCTAssertEqual(AppDestination.routeList.pageID, "PAGE-ROUTE-LIST")
        XCTAssertEqual(AppDestination.routeSearch.pageID, "PAGE-SEARCH")
        XCTAssertEqual(AppDestination.routeDetail("route-1").pageID, "PAGE-ROUTE-DETAIL")
        XCTAssertEqual(AppDestination.createTrip(routeID: "route-1").pageID, "PAGE-TRIP-CREATE")
        XCTAssertEqual(AppDestination.tripDetail("trip-1").pageID, "PAGE-TRIP-DETAIL")
        XCTAssertEqual(AppDestination.tripBrowse(tripID: "trip-1", dayNumber: 2).pageID, "PAGE-TRIP-BROWSE")
        XCTAssertEqual(AppDestination.tripWeather("trip-1").pageID, "PAGE-TRIP-WEATHER")
        XCTAssertEqual(AppDestination.tripEquipment("trip-1").pageID, "PAGE-TRIP-EQUIPMENT")
        XCTAssertEqual(AppDestination.tripList.pageID, "PAGE-TRIPS")
        XCTAssertEqual(AppDestination.personalEquipment.pageID, "PAGE-MY-EQUIPMENT")
        XCTAssertEqual(AppDestination.equipmentEdit(equipmentID: nil).pageID, "PAGE-EQUIPMENT-EDIT")
    }

    func testSettingsEntriesPushIntoProfileStackWhileMenuStaysModal() {
        var sut = AppShellState()
        sut.presentAccountMenu()

        XCTAssertTrue(sut.isAccountMenuPresented, "账户菜单为 Modal 任务，以模态 Sheet 呈现")
        XCTAssertTrue(sut.path(for: .profile).isEmpty, "菜单本身不进入我的页任务栈")

        // 设置项经我的页任务栈承接：先关闭 Sheet，再推入对应设置内容页。
        sut.dismissAccountMenu()
        sut.setPath([.profileDetails], for: .profile)

        XCTAssertFalse(sut.isAccountMenuPresented, "选择设置项后账户菜单关闭")
        XCTAssertEqual(sut.path(for: .profile), [.profileDetails], "设置内容页推入我的页任务栈")
        XCTAssertEqual(AppDestination.profileDetails.pageID, "PAGE-ME", "设置内容页不建立新 Page ID")

        sut.setPath([], for: .profile)
        XCTAssertNil(sut.path(for: .profile).first, "从设置内容页返回回到我的页")
    }

    func testPendingAuthIntentPreservesRouteAndSourceContext() {
        XCTAssertEqual(PendingAuthIntent.createTrip(routeID: "route-1"), .createTrip(routeID: "route-1"))
        XCTAssertEqual(PendingAuthIntent.profile, .profile)
        XCTAssertEqual(PendingAuthIntent.trips, .trips)
    }

    func testAuthenticationGatePresentsLoginAsModalWithoutDiscardingCurrentPath() {
        var sut = AppShellState()
        sut.setPath([.routeDetail("route-1")], for: .routes)

        sut.presentLogin()

        XCTAssertTrue(sut.isLoginPresented, "登录为 Modal 任务，全屏覆盖呈现")
        XCTAssertEqual(sut.path(for: .routes), [.routeDetail("route-1")], "登录不进入任务栈")

        sut.dismissLogin()

        XCTAssertFalse(sut.isLoginPresented)
        XCTAssertEqual(sut.path(for: .routes), [.routeDetail("route-1")])
    }

    func testProductionRootPresentsLoginAsModalCover() throws {
        let rootSource = try productionSource(at: "App/RootView.swift")
        XCTAssertTrue(rootSource.contains("fullScreenCover(isPresented: $shell.isLoginPresented)"), "登录以全屏覆盖弹出")
        XCTAssertFalse(rootSource.contains("case .login:"), "登录不再是任务栈目的地")
    }

    func testTripRevisionCanBePropagatedBackToDetailDestination() {
        var sut = AppShellState()
        sut.recordTripRevision("revision-2", tripID: "trip-1")
        XCTAssertEqual(sut.reloadRevision(for: "trip-1"), "revision-2")
    }

    func testEntryPagesExposeOnlyApprovedTripAndEquipmentFields() {
        XCTAssertEqual(EntryPageContract.tripFields, ["出发城市", "开始日期", "装备清单（可选）"])
        XCTAssertEqual(EntryPageContract.equipmentFields, ["名称", "拥有数量", "单件克重（可选）"])
    }

    func testProductionRootHasNoGuideToolOrUnscopedCreateBranches() throws {
        let rootSource = try productionSource(at: "App/RootView.swift")
        let destinationSource = try productionSource(at: "App/RootNavigation.swift")
        let createSource = try productionSource(at: "Features/Trips/CreateTripView.swift")

        XCTAssertFalse(rootSource.contains("GuidesTab"))
        XCTAssertFalse(rootSource.contains("DrawerView"))
        XCTAssertFalse(destinationSource.contains("case navigation"))
        XCTAssertFalse(destinationSource.contains("case tool"))
        XCTAssertFalse(createSource.contains("UnscopedCreateTripGuidanceView"))
    }

    func testTripListEmptyStateTargetsRouteListAndHasNoCreateAction() throws {
        let source = try productionSource(at: "Features/Trips/TripListView.swift")

        XCTAssertTrue(source.contains("actionTitle: \"查找路线\""))
        XCTAssertFalse(source.contains("创建行程"))
    }

    func testAllFourStacksRemainIndependent() {
        var sut = AppShellState()
        sut.setPath([.routeDetail("route")], for: .routes)
        sut.setPath([.tripDetail("trip"), .tripEquipment("trip"), .personalEquipment], for: .trips)
        sut.setPath([.equipmentEdit(equipmentID: "gear")], for: .equipment)
        sut.setPath([.profileDetails], for: .profile)
        sut.selectTab(.equipment)
        XCTAssertEqual(sut.path(for: .trips).last, .personalEquipment)
        sut.setPath([.tripDetail("trip"), .tripEquipment("trip")], for: .trips)
        XCTAssertEqual(sut.path(for: .equipment), [.equipmentEdit(equipmentID: "gear")])
        XCTAssertEqual(sut.path(for: .routes), [.routeDetail("route")])
        XCTAssertEqual(sut.path(for: .profile), [.profileDetails])
    }

    func testSessionLossClearsPersonalStacksAndRevisionsButRetainsPublicSource() {
        var sut = AppShellState()
        sut.setPath([.routeDetail("route"), .createTrip(routeID: "route")], for: .routes)
        sut.setPath([.tripDetail("trip"), .personalEquipment], for: .trips)
        sut.setPath([.equipmentEdit(equipmentID: "gear")], for: .equipment)
        sut.recordTripRevision("revision", tripID: "trip")
        sut.presentAccountMenu()
        sut.clearPersonalNavigation()
        XCTAssertEqual(sut.path(for: .routes), [.routeDetail("route")])
        XCTAssertTrue(sut.path(for: .trips).isEmpty)
        XCTAssertTrue(sut.path(for: .equipment).isEmpty)
        XCTAssertNil(sut.reloadRevision(for: "trip"))
        XCTAssertFalse(sut.isAccountMenuPresented)
    }

    func testLogoutClearsEveryStackAndReturnsToTrips() {
        var sut = AppShellState()
        for tab in AppTab.allCases { sut.setPath([.tripDetail("trip")], for: tab) }
        sut.selectTab(.equipment)
        sut.routeListShowsBackEntry = true
        sut.presentAccountMenu()
        sut.presentLogin()
        sut.recordTripRevision("revision", tripID: "trip")
        sut.resetAfterLogout()
        XCTAssertEqual(sut.selectedTab, .trips)
        XCTAssertTrue(AppTab.allCases.allSatisfy { sut.path(for: $0).isEmpty })
        XCTAssertNil(sut.reloadRevision(for: "trip"))
        XCTAssertFalse(sut.routeListShowsBackEntry)
        XCTAssertFalse(sut.isAccountMenuPresented)
        XCTAssertFalse(sut.isLoginPresented)
    }

    func testReauthenticationRestoresOnlyCurrentTaskAfterPersonalDataIsCleared() {
        var sut = AppShellState()
        sut.selectTab(.trips)
        let path: [AppDestination] = [.tripDetail("trip"), .tripEquipment("trip")]
        sut.setPath(path, for: .trips)
        sut.setPath([.equipmentEdit(equipmentID: "gear")], for: .equipment)
        sut.recordTripRevision("old-revision", tripID: "trip")
        sut.suspendSelectedTask()
        sut.clearPersonalNavigation()
        XCTAssertTrue(sut.path(for: .trips).isEmpty)
        sut.selectTab(.routes)
        sut.resumeSuspendedTask()
        XCTAssertEqual(sut.selectedTab, .trips)
        XCTAssertEqual(sut.path(for: .trips), path)
        XCTAssertTrue(sut.path(for: .equipment).isEmpty)
        XCTAssertNil(sut.reloadRevision(for: "trip"))
        sut.setPath([], for: .trips)
        sut.resumeSuspendedTask()
        XCTAssertTrue(sut.path(for: .trips).isEmpty, "恢复意图只能消费一次")
    }

    func testCancelledReauthenticationAndLogoutCannotRestoreSuspendedTask() {
        for logout in [false, true] {
            var sut = AppShellState()
            sut.selectTab(.trips)
            sut.setPath([.tripDetail("private-trip")], for: .trips)
            sut.suspendSelectedTask()
            sut.clearPersonalNavigation()
            if logout { sut.resetAfterLogout() } else { sut.discardSuspendedTask() }
            sut.resumeSuspendedTask()
            XCTAssertTrue(sut.path(for: .trips).isEmpty)
        }
    }

    func testTripEquipmentModelsAreReusedOnlyWithinCurrentSession() {
        let session = TripEquipmentSession()
        let client = MockAPIClient(fixtures: DefaultMockFixtures.all())
        let service = TripEquipmentService(apiClient: client)
        let equipment = EquipmentService(apiClient: client)
        let original = session.model(tripID: "trip-1", service: service, equipmentService: equipment)
        XCTAssertTrue(original === session.model(tripID: "trip-1", service: service, equipmentService: equipment))
        XCTAssertFalse(original === session.model(tripID: "trip-2", service: service, equipmentService: equipment))
        session.clear()
        XCTAssertFalse(original === session.model(tripID: "trip-1", service: service, equipmentService: equipment))
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
