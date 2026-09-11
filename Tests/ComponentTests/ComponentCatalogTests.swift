import XCTest
import WalkData
import WalkDesignSystem
@testable import Walk

final class ComponentCatalogTests: XCTestCase {
    func testCatalogMatchesAuthoritativeComponentInventory() {
        let entries = ComponentCatalog.entries

        XCTAssertEqual(entries.count, 84)
        XCTAssertEqual(Set(entries.map(\.id)).count, 84)
        XCTAssertEqual(entries.filter { $0.category == .common }.count, 38)
        XCTAssertEqual(entries.filter { $0.category == .business }.count, 46)
        XCTAssertEqual(Set(entries.map(\.id)), Set(Self.expectedComponentIDs))
    }

    func testCategoryInventoriesMatchAuthoritativeIndexes() {
        let commonIDs = ComponentCatalog.entries.filter { $0.category == .common }.map(\.id)
        let businessIDs = ComponentCatalog.entries.filter { $0.category == .business }.map(\.id)

        XCTAssertEqual(Set(commonIDs), Set(Self.commonComponentIDs))
        XCTAssertEqual(Set(businessIDs), Set(Self.businessComponentIDs))
    }

    func testEveryComponentHasDefaultStateAndNoUnsupportedEntry() {
        for entry in ComponentCatalog.entries {
            XCTAssertTrue(entry.stateIDs.contains("default"), "Missing default state: \(entry.id)")
            XCTAssertFalse(entry.isUnsupported, "Unsupported catalog entry: \(entry.id)")
            XCTAssertNotNil(entry.makeView("default"), "Default state did not produce a view: \(entry.id)")
        }
    }

    func testPreviewRequestParsesExplicitComponentAndOptionalState() {
        XCTAssertEqual(
            ComponentPreviewRequest(arguments: ["Walk", "--component-preview", "AvatarButton"]),
            ComponentPreviewRequest(componentID: "AvatarButton", stateID: "default")
        )
        XCTAssertEqual(
            ComponentPreviewRequest(arguments: ["Walk", "--component-preview", "TripStatusBadge", "completed"]),
            ComponentPreviewRequest(componentID: "TripStatusBadge", stateID: "completed")
        )
        XCTAssertNil(ComponentPreviewRequest(arguments: ["Walk"]))
    }

    private static let commonComponentIDs = [
        "AvatarButton", "Card", "ConfirmationDialog", "ContentSection", "DangerAction", "DateInput",
        "EmptyState", "ErrorView", "FixedActionArea", "FormField", "IconButton", "InfoTag", "ListRow",
        "LoadingState", "MetricGroup", "MetricItem", "MixedPageShell", "ModalBottomSheet", "Notice",
        "PageTitleBlock", "Panel", "PrimaryAction", "PrimaryTabBar", "QuantityStepper", "SearchField",
        "SecondaryAction", "SectionHeader", "SegmentedControl", "SelectInput", "SelectableOptionCard",
        "SettingsListRow", "SheetHandle", "SourceNote", "TextInput", "Timeline", "UnavailableState",
        "UtilityNavigationHeader", "UtilityPage",
    ]

    private static let businessComponentIDs = [
        "AccountMenuSheet", "AuthPanel", "ChecklistItemRow", "ChecklistPanel", "DailyWeatherCard",
        "ElevationProfile", "EquipmentDeletionImpact", "EquipmentListRow", "FocusTripSummary",
        "GearRing", "GenerationRouteSummaryCard", "GenerationWaitingView", "HeatmapCalendar",
        "InlineEquipmentEditor", "InlineListNameEditor", "PersonalEquipmentForm", "PersonalEquipmentSummaryCard", "ProfileIdentityHeader",
        "RouteFactSection", "RouteImageGallery", "RouteImageViewer", "RouteIntroduction", "RouteListRow",
        "RouteMap", "RoutePointDetail", "RoutePointSection", "RouteReferenceDayList", "RouteScene",
        "RouteSegmentList", "RouteSummary", "TrekDayBadge", "TripCalendarCard", "TripCoverHeader", "TripDayArrangement",
        "TripDayHikeSummary", "TripDaySummaryCard", "TripDayTransportSummary", "TripEquipmentGearRings",
        "TripEquipmentSummaryCard", "TripListRow", "TripRouteSummaryCard",
        "TripStatusBadge", "TripWeatherSummaryCard", "TripWeatherTrendChart", "WeatherOverview", "WeatherSummary",
    ]

    private static let expectedComponentIDs = commonComponentIDs + businessComponentIDs
}
