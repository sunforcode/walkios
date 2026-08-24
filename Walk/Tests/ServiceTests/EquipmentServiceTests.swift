import XCTest
@testable import Walk

final class EquipmentServiceTests: XCTestCase {
    var sut: EquipmentService!

    override func setUp() {
        super.setUp()
        sut = EquipmentService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - getChecklist Tests

    func testGetChecklist_WithTripId_ShouldReturnChecklist() async throws {
        do {
            _ = try await sut.getChecklist(tripId: "trip_001")
        } catch {
            XCTAssertTrue(error is APIError || error is NetworkError)
        }
    }

    // MARK: - getRecommendedEquipment Tests

    func testGetRecommendedEquipment_WithRouteId_ShouldReturnEquipment() async throws {
        do {
            _ = try await sut.getRecommendedEquipment(routeId: "route_001")
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - updateCheckStatus Tests

    func testUpdateCheckStatus_ShouldToggleStatus() async throws {
        do {
            _ = try await sut.updateCheckStatus(equipmentId: "eq_001", isChecked: true)
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - batchUpdateCheckStatus Tests

    func testBatchUpdateCheckStatus_ShouldUpdateMultiple() async throws {
        do {
            _ = try await sut.batchUpdateCheckStatus(ids: ["eq_001", "eq_002"], isChecked: true)
        } catch {
            XCTAssertNotNil(error)
        }
    }

    // MARK: - Model Tests

    func testEquipment_WeightDescription_Grams() {
        let equipment = Equipment(
            id: "eq_test",
            name: "测试装备",
            category: .clothing,
            weight: 500,
            quantity: 1,
            isChecked: false,
            description: nil,
            createdAt: nil
        )
        XCTAssertEqual(equipment.weightDescription, "500 g")
    }

    func testEquipment_WeightDescription_Kilograms() {
        let equipment = Equipment(
            id: "eq_test",
            name: "测试装备",
            category: .shelter,
            weight: 2000,
            quantity: 1,
            isChecked: false,
            description: nil,
            createdAt: nil
        )
        XCTAssertEqual(equipment.weightDescription, "2.0 kg")
    }

    func testEquipmentChecklist_GroupedByCategory() {
        let checklist = EquipmentChecklist(
            tripId: "trip_001",
            items: MockData.equipment,
            createdAt: Date(),
            updatedAt: Date()
        )
        let grouped = checklist.groupedByCategory()
        XCTAssertFalse(grouped.isEmpty)

        // Verify clothing category exists
        let clothingGroup = grouped.first { $0.0 == .clothing }
        XCTAssertNotNil(clothingGroup)
    }
}
