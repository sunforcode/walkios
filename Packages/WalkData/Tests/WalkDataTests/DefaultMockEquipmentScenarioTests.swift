import Foundation
import XCTest
@testable import WalkData

final class DefaultMockEquipmentScenarioTests: XCTestCase {
    func testCreatedPersonalEquipmentIsVisibleOnNextRead() async throws {
        let client = DefaultMockEquipmentScenario()
        let service = EquipmentService(apiClient: client)
        let created = try await service.createPersonalEquipment(input: .init(
            name: "轻量修补贴", ownedQuantity: 2, unitWeight: .init(grams: 12.5)
        ))
        let collection = try await service.getPersonalEquipment()
        XCTAssertTrue(collection.items.contains { $0.identity == created.item.identity })
        XCTAssertEqual(collection.items.first { $0.identity == created.item.identity }?.unitWeight?.grams, 12.5)
    }

    func testSeedAndLegacyStaticFixturesAreIndependent() async throws {
        let client = DefaultMockEquipmentScenario()
        let personal = try await client.execute(PersonalEquipmentAPI.Collection())
        XCTAssertEqual(personal.items.map(\.identity), ["equipment-1", "equipment-2"])
        XCTAssertEqual(personal.summary.knownTotalWeight.grams, 1812.5)
        XCTAssertEqual(personal.summary.equipmentListCount, 1)
        let list = try await client.execute(EquipmentListAPI.Detail(equipmentListID: "list-1"))
        XCTAssertEqual(list.name, "周末露营")
        XCTAssertEqual(list.members.map(\.identity), ["equipment-1"])
        let oldStatic = try await MockAPIClient(fixtures: DefaultMockFixtures.all()).execute(PersonalEquipmentAPI.Collection())
        XCTAssertTrue(oldStatic.items.isEmpty)
        let account = try await client.execute(AccountAPI.Current())
        XCTAssertEqual(account.account.identity, "account-1")
    }

    func testPersonalChangesFlowIntoListAndDeletionRemovesReferences() async throws {
        let client = DefaultMockEquipmentScenario()
        let service = EquipmentService(apiClient: client)
        _ = try await service.updatePersonalEquipment(id: "equipment-1", update: .init(name: "新帐篷", ownedQuantity: 3, unitWeight: .value(.init(grams: 1600.25))))
        let updated = try await service.putListMember(equipmentListID: "list-1", personalEquipmentID: "equipment-1", quantity: 2)
        XCTAssertEqual(updated.equipmentList.members.first?.name, "新帐篷")
        XCTAssertEqual(updated.equipmentList.members.first?.ownedQuantity, 3)
        XCTAssertEqual(updated.equipmentList.summary.knownTotalWeight.grams, 3200.5)
        XCTAssertEqual(updated.equipmentList.members.first?.category, .tent)
        _ = try await service.updatePersonalEquipment(id: "equipment-1", update: .init(unitWeight: .clear))
        let cleared = try await service.getPersonalEquipment(id: "equipment-1")
        XCTAssertNil(cleared.unitWeight)
        XCTAssertNil(cleared.unitWeightSource)
        let impact = try await service.getDeletionImpact(id: "equipment-1")
        XCTAssertEqual(impact.equipmentListReferenceCount, 1)
        let deleted = try await service.deletePersonalEquipment(id: "equipment-1")
        XCTAssertEqual(deleted.removedEquipmentListReferenceCount, 1)
        let list = try await service.getEquipmentList(id: "list-1")
        XCTAssertTrue(list.members.isEmpty)
        XCTAssertEqual(list.summary.knownTotalWeight.grams, 0)
        XCTAssertEqual(deleted.summary.knownTotalWeight.grams, 12.5)
    }

    func testListCRUDAndMemberQuantityPersistWithoutChangingOwnedQuantity() async throws {
        let client = DefaultMockEquipmentScenario()
        let service = EquipmentService(apiClient: client)
        let created = try await service.createEquipmentList(name: "  新   清单  ")
        let id = created.equipmentList.identity
        XCTAssertEqual(created.equipmentList.name, "新 清单")
        XCTAssertTrue(created.equipmentList.members.isEmpty)
        _ = try await service.putListMember(equipmentListID: id, personalEquipmentID: "equipment-2", quantity: 2)
        _ = try await service.putListMember(equipmentListID: id, personalEquipmentID: "equipment-2", quantity: 3)
        _ = try await service.renameEquipmentList(id: id, name: "备用物资")
        let loaded = try await service.getEquipmentList(id: id)
        XCTAssertEqual(loaded.name, "备用物资")
        XCTAssertEqual(loaded.members.count, 1)
        XCTAssertEqual(loaded.members.first?.quantity, 3)
        XCTAssertEqual(loaded.members.first?.ownedQuantity, 1)
        XCTAssertEqual(loaded.summary.knownTotalWeight.grams, 37.5)
        let removed = try await service.removeListMember(equipmentListID: id, personalEquipmentID: "equipment-2")
        XCTAssertTrue(removed.equipmentList.members.isEmpty)
        let deleted = try await service.deleteEquipmentList(id: id)
        XCTAssertEqual(deleted.personalEquipmentSummary.equipmentListCount, 1)
        let personal = try await service.getPersonalEquipment(id: "equipment-2")
        XCTAssertEqual(personal.ownedQuantity, 1)
    }

    func testFiltersDoNotNarrowAccountSummary() async throws {
        let client = DefaultMockEquipmentScenario()
        let response = try await client.execute(PersonalEquipmentAPI.Collection(category: .tent, missingWeight: false))
        XCTAssertEqual(response.items.map(\.identity), ["equipment-1"])
        XCTAssertEqual(response.summary.equipmentItemCount, 2)
        XCTAssertEqual(response.summary.knownTotalWeight.grams, 1812.5)
    }

    func testTripCRUDPersistsFractionalWeightAndUpdatesDetailSummary() async throws {
        let client = DefaultMockEquipmentScenario()
        let service = TripEquipmentService(apiClient: client)
        let original = try await service.getEquipment(tripID: "trip-1")
        let created = try await service.addItem(tripID: "trip-1", input: .init(name: "小修补包", quantity: 2, unitWeight: .init(grams: 12.5)), revision: original.revision)
        let item = try XCTUnwrap(created.snapshot.items.last)
        XCTAssertEqual(item.source, .userAdded)
        XCTAssertEqual(item.ownershipStatus, .unconfirmedOwned)
        XCTAssertEqual(created.snapshot.summary.knownTotalWeight.grams, original.snapshot.summary.knownTotalWeight.grams + 25)
        let updated = try await service.updateItem(tripID: "trip-1", itemID: item.identity, update: .init(quantity: 3, unitWeight: .value(.init(grams: 13.75))), revision: created.revision)
        XCTAssertEqual(updated.snapshot.items.last?.unitWeight?.grams, 13.75)
        let detail = try await client.execute(PersonalTripAPI.Detail(tripID: "trip-1"))
        XCTAssertEqual(detail.revision, updated.revision)
        XCTAssertEqual(detail.equipmentSnapshot.summary, updated.snapshot.summary)
        let deleted = try await service.deleteItem(tripID: "trip-1", itemID: item.identity, revision: updated.revision)
        XCTAssertEqual(deleted.snapshot.items, original.snapshot.items)
        let read = try await service.getEquipment(tripID: "trip-1")
        XCTAssertEqual(read, deleted)
    }

    func testSelectionAndAppendCopyCurrentValuesIntoIndependentSnapshot() async throws {
        let client = DefaultMockEquipmentScenario()
        let service = TripEquipmentService(apiClient: client)
        let personal = EquipmentService(apiClient: client)
        let selected = try await service.addFromPersonal(tripID: "trip-1", personalEquipmentID: "equipment-2", quantity: 1, revision: "revision-1", idempotencyKey: "select-1")
        XCTAssertEqual(selected.snapshot.items.last?.name, "修补贴")
        XCTAssertEqual(selected.snapshot.items.last?.unitWeight?.grams, 12.5)
        XCTAssertEqual(selected.snapshot.items.last?.ownershipStatus, .owned)
        let appended = try await service.appendList(tripID: "trip-1", equipmentListID: "list-1", revision: selected.revision, idempotencyKey: "append-1")
        XCTAssertEqual(appended.snapshot.items.last?.category, .tent)
        XCTAssertEqual(appended.snapshot.items.last?.unitWeight?.grams, 1800)
        XCTAssertEqual(appended.snapshot.items.count, 10)
        _ = try await personal.updatePersonalEquipment(id: "equipment-1", update: .init(name: "改名后的帐篷", unitWeight: .value(.init(grams: 900))))
        _ = try await personal.deletePersonalEquipment(id: "equipment-2")
        let read = try await service.getEquipment(tripID: "trip-1")
        XCTAssertEqual(read, appended)
        let rechecked = try await service.recheckOwnership(tripID: "trip-1", revision: read.revision)
        XCTAssertEqual(rechecked.snapshot.items.last?.name, "轻量帐篷")
        XCTAssertEqual(rechecked.snapshot.items.last?.ownershipStatus, .unconfirmedOwned)
        XCTAssertEqual(rechecked.snapshot.items.last?.unitWeight?.grams, 1800)
    }

    func testStableKeyReplaysOriginalSnapshotAfterSourceDeletionAndLaterMutation() async throws {
        let client = DefaultMockEquipmentScenario()
        let request = try TripEquipmentAPI.FromPersonal(tripID: "trip-1", personalEquipmentID: "equipment-2", quantity: 1, revision: "revision-1", idempotencyKey: "stable")
        let first = try await client.execute(request)
        _ = try await client.execute(PersonalEquipmentAPI.Delete(personalEquipmentID: "equipment-2"))
        let later = try await client.execute(TripEquipmentAPI.CreateItem(tripID: "trip-1", input: .init(name: "雨伞", quantity: 1), revision: first.revision))
        let replay = try await client.execute(request)
        XCTAssertEqual(replay, first)
        let current = try await client.execute(TripEquipmentAPI.Current(tripID: "trip-1"))
        XCTAssertEqual(current, later)
        do {
            _ = try await client.execute(TripEquipmentAPI.FromPersonal(tripID: "trip-1", personalEquipmentID: "equipment-2", quantity: 2, revision: "revision-1", idempotencyKey: "stable"))
            XCTFail("Changed content must not reuse a stable key")
        } catch { assertCode(error, "idempotency_conflict") }
    }

    func testConcurrentRetriesWithSameKeyCreateOneItem() async throws {
        let client = DefaultMockEquipmentScenario()
        let request = try TripEquipmentAPI.FromPersonal(tripID: "trip-1", personalEquipmentID: "equipment-2", quantity: 1, revision: "revision-1", idempotencyKey: "concurrent-key")
        async let a = client.execute(request)
        async let b = client.execute(request)
        let responses = try await (a, b)
        XCTAssertEqual(responses.0, responses.1)
        XCTAssertEqual(responses.0.snapshot.items.count, 9)
        XCTAssertEqual(responses.0.revision, "revision-2")
    }

    func testLegacyOriginalFieldMutationsRemainUsableWithoutRevision() async throws {
        let service = TripEquipmentService(apiClient: DefaultMockEquipmentScenario())
        let created = try await service.addItem(tripID: "trip-1", name: "备用雨伞", quantity: 1, unitWeightGrams: 200, note: nil)
        let id = try XCTUnwrap(created.snapshot.items.last?.identity)
        let updated = try await service.updateItem(tripID: "trip-1", itemID: id, update: .init(quantity: 2))
        XCTAssertEqual(updated.snapshot.items.last?.quantity, 2)
        let deleted = try await service.deleteItem(tripID: "trip-1", itemID: id)
        XCTAssertEqual(deleted.snapshot.items.count, 8)
    }

    func testAppendConflictIsAtomicAndStaleRevisionDoesNotWrite() async throws {
        let client = DefaultMockEquipmentScenario()
        let personal = EquipmentService(apiClient: client)
        let conflict = try await personal.createPersonalEquipment(input: .init(name: " 双人帐篷 ", ownedQuantity: 1))
        _ = try await personal.putListMember(equipmentListID: "list-1", personalEquipmentID: conflict.item.identity, quantity: 1)
        let before = try await client.execute(TripEquipmentAPI.Current(tripID: "trip-1"))
        do {
            _ = try await client.execute(TripEquipmentAPI.AppendList(tripID: "trip-1", equipmentListID: "list-1", revision: before.revision, idempotencyKey: "atomic"))
            XCTFail("Conflicting batch must fail")
        } catch { assertCode(error, "equipment_name_conflict") }
        let unchanged = try await client.execute(TripEquipmentAPI.Current(tripID: "trip-1"))
        XCTAssertEqual(unchanged, before)
        do {
            _ = try await client.execute(TripEquipmentAPI.CreateItem(tripID: "trip-1", input: .init(name: "旧请求", quantity: 1), revision: "revision-0"))
            XCTFail("Stale revision must fail")
        } catch { assertCode(error, "concurrent_modification") }
        let stillUnchanged = try await client.execute(TripEquipmentAPI.Current(tripID: "trip-1"))
        XCTAssertEqual(stillUnchanged, before)
    }

    func testInstancesAndIdentityChangesDoNotShareMutations() async throws {
        let identity = MockIdentityBox("account-a")
        let client = DefaultMockEquipmentScenario(identityProvider: { identity.get() })
        let other = DefaultMockEquipmentScenario()
        _ = try await client.execute(PersonalEquipmentAPI.Create(input: .init(name: "用户A的装备", ownedQuantity: 1)))
        let otherItems = try await other.execute(PersonalEquipmentAPI.Collection())
        XCTAssertEqual(otherItems.items.count, 2)
        identity.set("account-b")
        let afterSwitch = try await client.execute(PersonalEquipmentAPI.Collection())
        XCTAssertEqual(afterSwitch.items.count, 2)
        _ = try await client.execute(PersonalEquipmentAPI.Create(input: .init(name: "用户B的装备", ownedQuantity: 1)))
        _ = try await client.execute(AccountAPI.Logout())
        let afterLogout = try await client.execute(PersonalEquipmentAPI.Collection())
        XCTAssertEqual(afterLogout.items.count, 2)
        identity.set("anonymous")
        do {
            _ = try await client.execute(PersonalEquipmentAPI.Collection())
            XCTFail("Anonymous requests must be rejected")
        } catch { assertCode(error, "authentication_required") }
    }

    private func assertCode(_ error: Error, _ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case let APIClientError.api(code, _, _, _) = error else {
            return XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
        XCTAssertEqual(code, expected, file: file, line: line)
    }
}

private final class MockIdentityBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String
    init(_ value: String) { self.value = value }
    func get() -> String { lock.lock(); defer { lock.unlock() }; return value }
    func set(_ value: String) { lock.lock(); defer { lock.unlock() }; self.value = value }
}
