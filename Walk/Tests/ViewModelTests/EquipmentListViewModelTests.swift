import XCTest
@testable import Walk

@MainActor
final class EquipmentListViewModelTests: XCTestCase {
    func testInitialStateIsEmptyAndIdle() {
        let sut = EquipmentListViewModel(service: EquipmentServiceStub())

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertTrue(sut.equipmentLists.isEmpty)
        XCTAssertNil(sut.summary)
        XCTAssertFalse(sut.lastMutationSucceeded)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadPopulatesEquipmentListsAndDerivedSummary() async {
        let summary = PersonalEquipmentSummary(
            equipmentItemCount: 1,
            equipmentListCount: 1,
            knownTotalWeight: EquipmentWeight(grams: 3_000),
            missingWeightItemCount: 0
        )
        let service = EquipmentServiceStub(
            equipmentCollection: PersonalEquipmentCollection(
                items: [PersonalEquipment(
                    identity: "equipment-1",
                    name: "帐篷",
                    ownedQuantity: 2,
                    unitWeight: EquipmentWeight(grams: 1_500)
                )],
                summary: summary
            ),
            listCollection: EquipmentListCollection(items: [
                EquipmentListOverview(
                    identity: "list-1",
                    name: "周末露营",
                    summary: EquipmentListSummary(
                        itemCount: 1,
                        knownTotalWeight: EquipmentWeight(grams: 1_500),
                        missingWeightItemCount: 0
                    )
                ),
            ])
        )
        let sut = EquipmentListViewModel(service: service)

        await sut.load()

        XCTAssertEqual(sut.items.map(\.identity), ["equipment-1"])
        XCTAssertEqual(sut.equipmentLists.map(\.identity), ["list-1"])
        XCTAssertEqual(sut.summary, summary)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoadEquipmentFetchesEditingItemByStableIdentity() async {
        let item = PersonalEquipment(
            identity: "equipment-42",
            name: "冰爪",
            ownedQuantity: 2,
            unitWeight: EquipmentWeight(grams: 410)
        )
        let service = EquipmentServiceStub(
            createResult: PersonalEquipmentMutation(
                item: item,
                summary: PersonalEquipmentSummary(
                    equipmentItemCount: 1,
                    equipmentListCount: 0,
                    knownTotalWeight: EquipmentWeight(grams: 820),
                    missingWeightItemCount: 0
                )
            )
        )
        let sut = EquipmentListViewModel(service: service)

        await sut.loadEquipment(id: "equipment-42")

        XCTAssertEqual(sut.editingEquipment, item)
        XCTAssertEqual(service.loadedEquipmentIDs, ["equipment-42"])
    }

    func testLoadFailureExposesLocalizedMessageAndStopsLoading() async {
        let service = EquipmentServiceStub(error: APIClientError.api(
            code: "personal_equipment_unavailable",
            message: "装备服务暂不可用",
            retryable: true
        ))
        let sut = EquipmentListViewModel(service: service)

        await sut.load()

        XCTAssertEqual(sut.errorMessage, "装备服务暂不可用")
        XCTAssertFalse(sut.isLoading)
    }

    func testCreateEquipmentRefreshesCollectionState() async {
        let initialSummary = PersonalEquipmentSummary(
            equipmentItemCount: 0,
            equipmentListCount: 0,
            knownTotalWeight: EquipmentWeight(grams: 0),
            missingWeightItemCount: 0
        )
        let created = PersonalEquipment(
            identity: "equipment-1",
            name: "帐篷",
            ownedQuantity: 1,
            unitWeight: nil
        )
        let service = EquipmentServiceStub(
            equipmentCollection: PersonalEquipmentCollection(items: [], summary: initialSummary),
            createResult: PersonalEquipmentMutation(
                item: created,
                summary: PersonalEquipmentSummary(
                    equipmentItemCount: 1,
                    equipmentListCount: 0,
                    knownTotalWeight: EquipmentWeight(grams: 0),
                    missingWeightItemCount: 1
                )
            )
        )
        let sut = EquipmentListViewModel(service: service)

        await sut.createEquipment(name: "帐篷", ownedQuantity: 1, unitWeightGrams: nil)

        XCTAssertEqual(sut.items, [created])
        XCTAssertEqual(sut.summary?.missingWeightItemCount, 1)
    }

    func testLoadListDetailAndMemberMutationUpdateSelectedList() async {
        let emptyDetail = EquipmentListDetail(
            identity: "list-1",
            name: "周末露营",
            members: [],
            summary: EquipmentListSummary(
                itemCount: 0,
                knownTotalWeight: EquipmentWeight(grams: 0),
                missingWeightItemCount: 0
            )
        )
        let populatedDetail = EquipmentListDetail(
            identity: "list-1",
            name: "周末露营",
            members: [EquipmentListMember(
                identity: "equipment-1",
                name: "帐篷",
                ownedQuantity: 2,
                unitWeight: EquipmentWeight(grams: 1_500),
                quantity: 1
            )],
            summary: EquipmentListSummary(
                itemCount: 1,
                knownTotalWeight: EquipmentWeight(grams: 1_500),
                missingWeightItemCount: 0
            )
        )
        let service = EquipmentServiceStub(
            listDetail: emptyDetail,
            listMutation: EquipmentListMutation(equipmentList: populatedDetail)
        )
        let sut = EquipmentListViewModel(service: service)

        await sut.loadEquipmentList(id: "list-1")
        await sut.putMember(equipmentListID: "list-1", personalEquipmentID: "equipment-1", quantity: 1)

        XCTAssertEqual(sut.selectedEquipmentList, populatedDetail)
        XCTAssertEqual(sut.selectedEquipmentList?.members[0].quantity, 1)
    }
}

private final class EquipmentServiceStub: EquipmentServicing {
    var equipmentCollection: PersonalEquipmentCollection
    var listCollection: EquipmentListCollection
    var createResult: PersonalEquipmentMutation
    var listDetail: EquipmentListDetail
    var listMutation: EquipmentListMutation
    var error: Error?
    private(set) var loadedEquipmentIDs: [String] = []

    init(
        equipmentCollection: PersonalEquipmentCollection = PersonalEquipmentCollection(
            items: [],
            summary: PersonalEquipmentSummary(
                equipmentItemCount: 0,
                equipmentListCount: 0,
                knownTotalWeight: EquipmentWeight(grams: 0),
                missingWeightItemCount: 0
            )
        ),
        listCollection: EquipmentListCollection = EquipmentListCollection(items: []),
        createResult: PersonalEquipmentMutation? = nil,
        listDetail: EquipmentListDetail? = nil,
        listMutation: EquipmentListMutation? = nil,
        error: Error? = nil
    ) {
        self.equipmentCollection = equipmentCollection
        self.listCollection = listCollection
        let fallbackItem = PersonalEquipment(identity: "equipment", name: "装备", ownedQuantity: 1, unitWeight: nil)
        self.createResult = createResult ?? PersonalEquipmentMutation(item: fallbackItem, summary: equipmentCollection.summary)
        let fallbackDetail = listDetail ?? EquipmentListDetail(
            identity: "list",
            name: "清单",
            members: [],
            summary: EquipmentListSummary(itemCount: 0, knownTotalWeight: EquipmentWeight(grams: 0), missingWeightItemCount: 0)
        )
        self.listDetail = fallbackDetail
        self.listMutation = listMutation ?? EquipmentListMutation(equipmentList: fallbackDetail)
        self.error = error
    }

    func getPersonalEquipment() async throws -> PersonalEquipmentCollection {
        if let error { throw error }
        return equipmentCollection
    }

    func createPersonalEquipment(name: String, ownedQuantity: Int, unitWeightGrams: Int?) async throws -> PersonalEquipmentMutation {
        if let error { throw error }
        return createResult
    }

    func getPersonalEquipment(id: String) async throws -> PersonalEquipment {
        loadedEquipmentIDs.append(id)
        if let error { throw error }
        return createResult.item
    }

    func updatePersonalEquipment(id: String, update: PersonalEquipmentUpdate) async throws -> PersonalEquipmentMutation {
        if let error { throw error }
        return createResult
    }

    func getDeletionImpact(id: String) async throws -> PersonalEquipmentDeletionImpact {
        if let error { throw error }
        return PersonalEquipmentDeletionImpact(
            personalEquipmentId: id,
            equipmentListReferenceCount: 0,
            affectedEquipmentLists: []
        )
    }

    func deletePersonalEquipment(id: String) async throws -> PersonalEquipmentDeletionResult {
        if let error { throw error }
        return PersonalEquipmentDeletionResult(
            deletedPersonalEquipmentId: id,
            removedEquipmentListReferenceCount: 0,
            summary: equipmentCollection.summary
        )
    }

    func getEquipmentLists() async throws -> EquipmentListCollection {
        if let error { throw error }
        return listCollection
    }

    func createEquipmentList(name: String) async throws -> EquipmentListCreateResult {
        if let error { throw error }
        return EquipmentListCreateResult(
            equipmentList: listDetail,
            personalEquipmentSummary: equipmentCollection.summary
        )
    }

    func getEquipmentList(id: String) async throws -> EquipmentListDetail {
        if let error { throw error }
        return listDetail
    }

    func renameEquipmentList(id: String, name: String) async throws -> EquipmentListMutation {
        if let error { throw error }
        return listMutation
    }

    func deleteEquipmentList(id: String) async throws -> EquipmentListDeletionResult {
        if let error { throw error }
        return EquipmentListDeletionResult(
            deletedEquipmentListId: id,
            personalEquipmentSummary: equipmentCollection.summary
        )
    }

    func putListMember(equipmentListID: String, personalEquipmentID: String, quantity: Int) async throws -> EquipmentListMutation {
        if let error { throw error }
        return listMutation
    }

    func removeListMember(equipmentListID: String, personalEquipmentID: String) async throws -> EquipmentListMutation {
        if let error { throw error }
        return listMutation
    }
}

@MainActor
final class TripEquipmentViewModelTests: XCTestCase {
    func testLoadUsesReturnedProjectionAsPageState() async {
        let initial = tripEquipmentProjection(revision: "revision-1", name: "帐篷")
        let sut = TripEquipmentViewModel(
            tripID: "trip-1",
            service: TripEquipmentServiceStub(projection: initial)
        )

        await sut.load()

        XCTAssertEqual(sut.projection, initial)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(sut.isEditable)
    }

    func testSuccessfulMutationReplacesEntireProjection() async {
        let initial = tripEquipmentProjection(revision: "revision-1", name: "帐篷")
        let replacement = tripEquipmentProjection(revision: "revision-2", name: "双人帐篷")
        let service = TripEquipmentServiceStub(projection: replacement)
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)
        sut.projection = initial

        await sut.updateItem(
            itemID: "item-1",
            update: TripEquipmentItemUpdate(name: "双人帐篷")
        )

        XCTAssertEqual(sut.projection, replacement)
        XCTAssertEqual(sut.projection?.revision, "revision-2")
        XCTAssertFalse(sut.isMutating)
        XCTAssertNil(sut.errorMessage)
    }

    func testFailedMutationPreservesProjectionAndShowsError() async {
        let initial = tripEquipmentProjection(revision: "revision-1", name: "帐篷")
        let service = TripEquipmentServiceStub(
            projection: initial,
            error: APIClientError.api(
                code: "trip_equipment_read_only",
                message: "该行程装备已只读",
                retryable: false
            )
        )
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)
        sut.projection = initial

        await sut.deleteItem(itemID: "item-1")

        XCTAssertEqual(sut.projection, initial)
        XCTAssertEqual(sut.errorMessage, "该行程装备已只读")
        XCTAssertFalse(sut.isMutating)
    }

    func testReadOnlyProjectionDoesNotExposeMutationCapability() async {
        let readOnly = tripEquipmentProjection(
            revision: "revision-1",
            name: "帐篷",
            status: .completed,
            editable: false
        )
        let sut = TripEquipmentViewModel(
            tripID: "trip-1",
            service: TripEquipmentServiceStub(projection: readOnly)
        )

        await sut.load()

        XCTAssertFalse(sut.isEditable)
    }

    func testReturningFromPersonalEquipmentRechecksOwnershipAndUsesNewRevision() async {
        let initial = tripEquipmentProjection(revision: "revision-1", name: "帐篷")
        let rechecked = tripEquipmentProjection(revision: "revision-2", name: "帐篷")
        let service = TripEquipmentServiceStub(
            projection: initial,
            recheckedProjection: rechecked
        )
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)

        await sut.handleAppearance()
        sut.prepareForPersonalEquipment()
        await sut.handleAppearance()

        XCTAssertEqual(service.loadCount, 1)
        XCTAssertEqual(service.recheckCount, 1)
        XCTAssertEqual(sut.projection?.revision, "revision-2")
    }

    func testEquipmentItemTotalWeightMultipliesUnitWeightByQuantity() {
        let item = TripEquipmentItem(
            identity: "item-1",
            name: "水",
            quantity: 3,
            unitWeight: EquipmentWeight(grams: 500),
            note: nil,
            source: .userAdded,
            ownershipStatus: .owned
        )

        XCTAssertEqual(item.totalWeight?.grams, 1_500)
    }
}

private final class TripEquipmentServiceStub: TripEquipmentServicing {
    let projection: TripEquipmentProjection
    let recheckedProjection: TripEquipmentProjection
    let error: Error?
    private(set) var loadCount = 0
    private(set) var recheckCount = 0

    init(
        projection: TripEquipmentProjection,
        recheckedProjection: TripEquipmentProjection? = nil,
        error: Error? = nil
    ) {
        self.projection = projection
        self.recheckedProjection = recheckedProjection ?? projection
        self.error = error
    }

    func getEquipment(tripID: String) async throws -> TripEquipmentProjection {
        loadCount += 1
        return try result()
    }

    func addItem(
        tripID: String,
        name: String,
        quantity: Int,
        unitWeightGrams: Int?,
        note: String?
    ) async throws -> TripEquipmentProjection {
        try result()
    }

    func updateItem(
        tripID: String,
        itemID: String,
        update: TripEquipmentItemUpdate
    ) async throws -> TripEquipmentProjection {
        try result()
    }

    func deleteItem(tripID: String, itemID: String) async throws -> TripEquipmentProjection {
        try result()
    }

    func recheckOwnership(tripID: String) async throws -> TripEquipmentProjection {
        recheckCount += 1
        if let error { throw error }
        return recheckedProjection
    }

    private func result() throws -> TripEquipmentProjection {
        if let error { throw error }
        return projection
    }
}

private func tripEquipmentProjection(
    revision: String,
    name: String,
    status: PersonalTripStatus = .planned,
    editable: Bool = true
) -> TripEquipmentProjection {
    TripEquipmentProjection(
        trip: TripEquipmentTrip(
            identity: "trip-1",
            status: status,
            routeName: "贡嘎环线",
            startDate: LocalDate(year: 2026, month: 8, day: 25),
            endDate: LocalDate(year: 2026, month: 8, day: 27)
        ),
        revision: revision,
        editable: editable,
        snapshot: TripEquipmentSnapshot(
            identity: "snapshot-1",
            items: [TripEquipmentItem(
                identity: "item-1",
                name: name,
                quantity: 1,
                unitWeight: nil,
                note: nil,
                source: .userAdded,
                ownershipStatus: .unconfirmedOwned
            )],
            summary: PersonalTripEquipmentSummary(
                itemCount: 1,
                knownTotalWeight: EquipmentWeight(grams: 0),
                missingWeightItemCount: 1,
                ownedItemCount: 0,
                unconfirmedOwnedItemCount: 1
            )
        )
    )
}
