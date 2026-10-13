import XCTest
import WalkData
import WalkDesignSystem
@testable import Walk

final class ComponentCatalogTests: XCTestCase {
    func testCatalogMatchesAuthoritativeComponentInventory() {
        let entries = ComponentCatalog.entries

        XCTAssertEqual(entries.count, 81)
        XCTAssertEqual(Set(entries.map(\.id)).count, 81)
        XCTAssertEqual(entries.filter { $0.category == .common }.count, 37)
        XCTAssertEqual(entries.filter { $0.category == .business }.count, 44)
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

    func testSelectInputExposesApprovedCalibrationStates() throws {
        let entry = try XCTUnwrap(ComponentCatalog.entry(id: "SelectInput"))
        let states = ["default", "empty", "selected", "disabled", "error"]
        XCTAssertEqual(entry.category, .common)
        XCTAssertEqual(Set(entry.stateIDs), Set(states))
        for state in states { XCTAssertNotNil(entry.makeView(state), state) }
        XCTAssertNil(entry.makeView("unknown"))
    }

    func testEquipmentFormExposesApprovedSelectionStates() throws {
        let entry = try XCTUnwrap(ComponentCatalog.entry(id: "PersonalEquipmentForm"))
        let states = ["default", "create", "categorySelected", "typeSelected", "edit",
                      "referenceWeightConfirmation", "validationError", "saveFailed"]
        XCTAssertEqual(Set(entry.stateIDs), Set(states))
        for state in states { XCTAssertNotNil(entry.makeView(state), state) }
        XCTAssertNil(entry.makeView("unknown"))
    }

    private static let commonComponentIDs = [
        "AvatarButton", "Card", "ConfirmationDialog", "ContentSection", "DangerAction", "DateInput",
        "EmptyState", "ErrorView", "FixedActionArea", "FormField", "IconButton", "InfoTag", "ListRow",
        "LoadingState", "MetricGroup", "MetricItem", "MixedPageShell", "ModalBottomSheet", "Notice",
        "PageTitleBlock", "Panel", "PrimaryAction", "QuantityStepper", "SearchField",
        "SecondaryAction", "SectionHeader", "SegmentedControl", "SelectInput", "SelectableOptionCard",
        "SettingsListRow", "SheetHandle", "SourceNote", "TextInput", "Timeline", "UnavailableState",
        "UtilityNavigationHeader", "UtilityPage",
    ]

    private static let businessComponentIDs = [
        "AuthPanel", "ChecklistItemRow", "ChecklistPanel", "DailyWeatherCard", "DailyWeatherSummaryRow",
        "ElevationProfile", "EquipmentDeletionImpact", "EquipmentListRow", "FocusTripSummary",
        "GearRing", "GenerationRouteSummaryCard", "GenerationWaitingView", "HeatmapCalendar",
        "InlineEquipmentEditor", "InlineListNameEditor", "PersonalEquipmentForm", "PersonalEquipmentSummaryCard", "ProfileIdentityHeader",
        "RouteFactSection", "RouteImageGallery", "RouteIntroduction", "RouteListRow",
        "RouteMap", "RoutePointDetail", "RoutePointSection", "RouteReferenceDayList", "RouteScene",
        "RouteSegmentList", "RouteSummary", "TrekDayBadge", "TripCalendarCard", "TripCoverHeader", "TripDayArrangement",
        "TripDayOverviewEntry", "TripEquipmentGearRings",
        "TripEquipmentSourcePicker", "TripEquipmentSummaryCard", "TripListRow", "TripRouteSummaryCard",
        "TripStatusBadge", "TripWeatherSummaryCard", "TripWeatherTrendChart", "WeatherOverview", "WeatherSummary",
    ]

    private static let expectedComponentIDs = commonComponentIDs + businessComponentIDs
}
