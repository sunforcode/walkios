import XCTest
@testable import Walk

@MainActor
final class EquipmentListViewModelTests: XCTestCase {
    var sut: EquipmentListViewModel!

    override func setUp() {
        super.setUp()
        sut = EquipmentListViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState_ChecklistShouldBeNil() {
        XCTAssertNil(sut.checklist)
    }

    func testInitialState_CheckedItemsShouldBeEmpty() {
        XCTAssertTrue(sut.checkedItems.isEmpty)
    }

    func testInitialState_ProgressShouldBeZero() {
        XCTAssertEqual(sut.progress, 0)
    }

    // MARK: - Progress Tests

    func testProgress_WithNoItems_ShouldBeZero() {
        XCTAssertEqual(sut.progress, 0)
    }

    // MARK: - Count Tests

    func testCheckedCount_InitiallyZero() {
        XCTAssertEqual(sut.checkedCount, 0)
    }

    func testTotalCount_InitiallyZero() {
        XCTAssertEqual(sut.totalCount, 0)
    }

    // MARK: - Toggle Tests

    func testToggleCheck_ShouldToggleCheckedItemWhenServiceSucceeds() async {
        sut.checklist = MockData.equipmentChecklist
        let equipmentId = "eq_001"
        sut.checkedItems = [equipmentId]

        await sut.toggleCheck(equipmentId: equipmentId)

        XCTAssertFalse(sut.checkedItems.contains(equipmentId))
        XCTAssertNil(sut.errorMessage)
    }
}
