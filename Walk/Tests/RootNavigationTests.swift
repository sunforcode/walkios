import SwiftUI
import XCTest
@testable import Walk

@MainActor
final class RootNavigationTests: XCTestCase {
    func testAppShellStartsOnHomeWithThreeApprovedTabs() {
        let sut = AppShellState()

        XCTAssertEqual(sut.selectedTab, .home)
        XCTAssertEqual(AppTab.allCases, [.home, .routes, .profile])
        XCTAssertEqual(AppTab.allCases.map(\.title), ["首页", "路线", "我的"])
    }

    func testAppShellKeepsIndependentNavigationPaths() {
        var sut = AppShellState()
        sut.setPath([.routeDetail("route-1")], for: .routes)
        sut.selectTab(.home)

        XCTAssertEqual(sut.path(for: .routes), [.routeDetail("route-1")])
        XCTAssertTrue(sut.path(for: .home).isEmpty)
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
        XCTAssertEqual(ProfileLayout.avatarSize, RootNavigation.minimumHitSize)
    }

    func testCoreDestinationsRemainTypeSafeAndMappedToApprovedPages() {
        XCTAssertEqual(AppDestination.login.pageID, "PAGE-LOGIN")
        XCTAssertEqual(AppDestination.routeList.pageID, "PAGE-ROUTE-LIST")
        XCTAssertEqual(AppDestination.routeSearch.pageID, "PAGE-SEARCH")
        XCTAssertEqual(AppDestination.routeDetail("route-1").pageID, "PAGE-ROUTE-DETAIL")
        XCTAssertEqual(AppDestination.createTrip(routeID: "route-1").pageID, "PAGE-TRIP-CREATE")
        XCTAssertEqual(AppDestination.tripDetail("trip-1").pageID, "PAGE-TRIP-DETAIL")
        XCTAssertEqual(AppDestination.tripDay(tripID: "trip-1", initialDayID: "day-2").pageID, "PAGE-TRIP-DAY")
        XCTAssertEqual(AppDestination.tripWeather("trip-1").pageID, "PAGE-TRIP-WEATHER")
        XCTAssertEqual(AppDestination.tripEquipment("trip-1").pageID, "PAGE-TRIP-EQUIPMENT")
        XCTAssertEqual(AppDestination.tripList.pageID, "PAGE-TRIPS")
        XCTAssertEqual(AppDestination.personalEquipment.pageID, "PAGE-MY-EQUIPMENT")
        XCTAssertEqual(AppDestination.equipmentEdit(equipmentID: nil).pageID, "PAGE-EQUIPMENT-EDIT")
        XCTAssertEqual(AppDestination.accountSecurity.pageID, "PAGE-ME")
    }

    func testPendingAuthIntentPreservesRouteAndSourceContext() {
        XCTAssertEqual(PendingAuthIntent.createTrip(routeID: "route-1"), .createTrip(routeID: "route-1"))
        XCTAssertEqual(PendingAuthIntent.profile, .profile)
        XCTAssertEqual(PendingAuthIntent.homeStart, .homeStart)
    }

    func testAuthenticationGatePushesLoginWithoutDiscardingCurrentPath() {
        var sut = AppShellState()
        sut.setPath([.routeDetail("route-1")], for: .routes)

        sut.presentLogin(in: .routes)

        XCTAssertEqual(sut.path(for: .routes), [.routeDetail("route-1"), .login])
        sut.dismissLogin(in: .routes)
        XCTAssertEqual(sut.path(for: .routes), [.routeDetail("route-1")])
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
        let homeSource = try productionSource(at: "Features/Home/HomeView.swift")
        let createSource = try productionSource(at: "Features/Trips/CreateTripView.swift")

        XCTAssertFalse(rootSource.contains("GuidesTab"))
        XCTAssertFalse(rootSource.contains("DrawerView"))
        XCTAssertFalse(destinationSource.contains("case navigation"))
        XCTAssertFalse(destinationSource.contains("case tool"))
        XCTAssertFalse(homeSource.contains("onOpenTools"))
        XCTAssertFalse(createSource.contains("UnscopedCreateTripGuidanceView"))
    }

    func testTripListEmptyStateTargetsRouteListAndHasNoCreateAction() throws {
        let source = try productionSource(at: "Features/Trips/TripListView.swift")

        XCTAssertTrue(source.contains("actionTitle: \"查找路线\""))
        XCTAssertFalse(source.contains("创建行程"))
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
