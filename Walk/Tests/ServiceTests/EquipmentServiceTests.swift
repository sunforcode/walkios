import XCTest
@testable import Walk

final class EquipmentServiceTests: XCTestCase {
    func testPersonalEquipmentRequestsUseFixedPathsMethodsDataEnvelopeAndNoOwnerQuery() throws {
        let requests: [(String, APIHTTPMethod, String, APIResponseEnvelope, [URLQueryItem])] = [
            requestContract(PersonalEquipmentAPI.Collection()),
            requestContract(try PersonalEquipmentAPI.Create(name: "帐篷", ownedQuantity: 1, unitWeightGrams: 1_500)),
            requestContract(PersonalEquipmentAPI.Detail(personalEquipmentID: "equipment-1")),
            requestContract(try PersonalEquipmentAPI.Update(
                personalEquipmentID: "equipment-1",
                update: PersonalEquipmentUpdate(name: "双人帐篷")
            )),
            requestContract(PersonalEquipmentAPI.DeletionImpact(personalEquipmentID: "equipment-1")),
            requestContract(PersonalEquipmentAPI.Delete(personalEquipmentID: "equipment-1")),
            requestContract(EquipmentListAPI.Collection()),
            requestContract(try EquipmentListAPI.Create(name: "周末露营")),
            requestContract(EquipmentListAPI.Detail(equipmentListID: "list-1")),
            requestContract(try EquipmentListAPI.Rename(equipmentListID: "list-1", name: "高山露营")),
            requestContract(EquipmentListAPI.Delete(equipmentListID: "list-1")),
            requestContract(try EquipmentListAPI.PutMember(
                equipmentListID: "list-1",
                personalEquipmentID: "equipment-1",
                quantity: 2
            )),
            requestContract(EquipmentListAPI.DeleteMember(
                equipmentListID: "list-1",
                personalEquipmentID: "equipment-1"
            )),
        ]

        XCTAssertEqual(requests.map(\.0), [
            "GET /personal-equipment",
            "POST /personal-equipment",
            "GET /personal-equipment/equipment-1",
            "PATCH /personal-equipment/equipment-1",
            "GET /personal-equipment/equipment-1/deletion-impact",
            "DELETE /personal-equipment/equipment-1?confirmListRemoval=true",
            "GET /equipment-lists",
            "POST /equipment-lists",
            "GET /equipment-lists/list-1",
            "PATCH /equipment-lists/list-1",
            "DELETE /equipment-lists/list-1",
            "PUT /equipment-lists/list-1/members/equipment-1",
            "DELETE /equipment-lists/list-1/members/equipment-1",
        ])
        XCTAssertEqual(requests.map(\.1), [
            .get, .post, .get, .patch, .get, .delete,
            .get, .post, .get, .patch, .delete, .put, .delete,
        ])
        XCTAssertTrue(requests.allSatisfy { $0.2.hasPrefix("/personal-equipment") || $0.2.hasPrefix("/equipment-lists") })
        XCTAssertTrue(requests.allSatisfy { $0.3 == .data })
        XCTAssertTrue(requests.allSatisfy { contract in
            contract.4.allSatisfy { $0.name != "ownerId" && $0.name != "accountId" && $0.name != "userId" }
        })
    }

    func testDeleteUsesOnlyRequiredConfirmationQuery() {
        let request = PersonalEquipmentAPI.Delete(personalEquipmentID: "equipment-1")

        XCTAssertEqual(request.query, [URLQueryItem(name: "confirmListRemoval", value: "true")])
    }

    func testUpdateCanEncodeExplicitWeightClearWithoutEncodingUnchangedFields() throws {
        let request = try PersonalEquipmentAPI.Update(
            personalEquipmentID: "equipment-1",
            update: PersonalEquipmentUpdate(unitWeight: .clear)
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.body)) as? [String: Any])

        XCTAssertTrue(object["unitWeight"] is NSNull)
        XCTAssertNil(object["name"])
        XCTAssertNil(object["ownedQuantity"])
        XCTAssertNil(object["ownerId"])
    }

    func testCollectionDecodesDataEnvelopeOmittedWeightAndDerivedSummary() async throws {
        let request = PersonalEquipmentAPI.Collection()
        let fixture = Data(#"{"data":{"items":[{"identity":"equipment-1","name":"帐篷","ownedQuantity":2}],"summary":{"equipmentItemCount":1,"equipmentListCount":3,"knownTotalWeight":{"grams":0},"missingWeightItemCount":1}}}"#.utf8)
        let service = EquipmentService(apiClient: MockAPIClient(fixtures: [request.identifier: fixture]))

        let result = try await service.getPersonalEquipment()

        XCTAssertNil(result.items[0].unitWeight)
        XCTAssertEqual(result.summary.equipmentItemCount, 1)
        XCTAssertEqual(result.summary.equipmentListCount, 3)
        XCTAssertEqual(result.summary.knownTotalWeight.grams, 0)
        XCTAssertEqual(result.summary.missingWeightItemCount, 1)
    }

    func testEquipmentListDetailDecodesMembersAndSummary() async throws {
        let request = EquipmentListAPI.Detail(equipmentListID: "list-1")
        let fixture = Data(#"{"data":{"identity":"list-1","name":"周末露营","members":[{"identity":"equipment-1","name":"帐篷","ownedQuantity":2,"unitWeight":{"grams":1500},"quantity":1}],"summary":{"itemCount":1,"knownTotalWeight":{"grams":1500},"missingWeightItemCount":0}}}"#.utf8)
        let service = EquipmentService(apiClient: MockAPIClient(fixtures: [request.identifier: fixture]))

        let result = try await service.getEquipmentList(id: "list-1")

        XCTAssertEqual(result.members[0].ownedQuantity, 2)
        XCTAssertEqual(result.members[0].quantity, 1)
        XCTAssertEqual(result.summary.itemCount, 1)
        XCTAssertEqual(result.summary.knownTotalWeight.grams, 1_500)
    }

    func testMutationServiceMethodsUseAllTypedRequests() async throws {
        let createEquipment = try PersonalEquipmentAPI.Create(name: "帐篷", ownedQuantity: 1, unitWeightGrams: nil)
        let updateEquipment = try PersonalEquipmentAPI.Update(
            personalEquipmentID: "equipment-1",
            update: PersonalEquipmentUpdate(
                name: "双人帐篷",
                ownedQuantity: 2,
                unitWeight: .value(EquipmentWeight(grams: 1_800))
            )
        )
        let createList = try EquipmentListAPI.Create(name: "周末露营")
        let renameList = try EquipmentListAPI.Rename(equipmentListID: "list-1", name: "高山露营")
        let putMember = try EquipmentListAPI.PutMember(
            equipmentListID: "list-1",
            personalEquipmentID: "equipment-1",
            quantity: 2
        )
        let equipmentMutation = Data(#"{"data":{"item":{"identity":"equipment-1","name":"双人帐篷","ownedQuantity":2,"unitWeight":{"grams":1800}},"summary":{"equipmentItemCount":1,"equipmentListCount":1,"knownTotalWeight":{"grams":3600},"missingWeightItemCount":0}}}"#.utf8)
        let listMutation = Data(#"{"data":{"equipmentList":{"identity":"list-1","name":"高山露营","members":[{"identity":"equipment-1","name":"双人帐篷","ownedQuantity":2,"unitWeight":{"grams":1800},"quantity":2}],"summary":{"itemCount":1,"knownTotalWeight":{"grams":3600},"missingWeightItemCount":0}}}}"#.utf8)
        let fixtures: [String: Data] = [
            createEquipment.identifier: equipmentMutation,
            PersonalEquipmentAPI.Detail(personalEquipmentID: "equipment-1").identifier: Data(#"{"data":{"identity":"equipment-1","name":"帐篷","ownedQuantity":1}}"#.utf8),
            updateEquipment.identifier: equipmentMutation,
            PersonalEquipmentAPI.DeletionImpact(personalEquipmentID: "equipment-1").identifier: Data(#"{"data":{"personalEquipmentId":"equipment-1","equipmentListReferenceCount":1,"affectedEquipmentLists":[{"identity":"list-1","name":"周末露营"}]}}"#.utf8),
            PersonalEquipmentAPI.Delete(personalEquipmentID: "equipment-1").identifier: Data(#"{"data":{"deletedPersonalEquipmentId":"equipment-1","removedEquipmentListReferenceCount":1,"summary":{"equipmentItemCount":0,"equipmentListCount":1,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0}}}"#.utf8),
            EquipmentListAPI.Collection().identifier: Data(#"{"data":{"items":[]}}"#.utf8),
            createList.identifier: Data(#"{"data":{"equipmentList":{"identity":"list-1","name":"周末露营","members":[],"summary":{"itemCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0}},"personalEquipmentSummary":{"equipmentItemCount":1,"equipmentListCount":1,"knownTotalWeight":{"grams":3600},"missingWeightItemCount":0}}}"#.utf8),
            EquipmentListAPI.Detail(equipmentListID: "list-1").identifier: Data(#"{"data":{"identity":"list-1","name":"周末露营","members":[],"summary":{"itemCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0}}}"#.utf8),
            renameList.identifier: listMutation,
            putMember.identifier: listMutation,
            EquipmentListAPI.DeleteMember(equipmentListID: "list-1", personalEquipmentID: "equipment-1").identifier: listMutation,
            EquipmentListAPI.Delete(equipmentListID: "list-1").identifier: Data(#"{"data":{"deletedEquipmentListId":"list-1","personalEquipmentSummary":{"equipmentItemCount":1,"equipmentListCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":1}}}"#.utf8),
        ]
        let service = EquipmentService(apiClient: MockAPIClient(fixtures: fixtures))

        let created = try await service.createPersonalEquipment(name: "帐篷", ownedQuantity: 1, unitWeightGrams: nil)
        let detail = try await service.getPersonalEquipment(id: "equipment-1")
        let updated = try await service.updatePersonalEquipment(id: "equipment-1", update: PersonalEquipmentUpdate(name: "双人帐篷", ownedQuantity: 2, unitWeight: .value(EquipmentWeight(grams: 1_800))))
        let impact = try await service.getDeletionImpact(id: "equipment-1")
        let deleted = try await service.deletePersonalEquipment(id: "equipment-1")
        let lists = try await service.getEquipmentLists()
        let createdList = try await service.createEquipmentList(name: "周末露营")
        let listDetail = try await service.getEquipmentList(id: "list-1")
        let renamed = try await service.renameEquipmentList(id: "list-1", name: "高山露营")
        let memberAdded = try await service.putListMember(equipmentListID: "list-1", personalEquipmentID: "equipment-1", quantity: 2)
        let memberRemoved = try await service.removeListMember(equipmentListID: "list-1", personalEquipmentID: "equipment-1")
        let deletedList = try await service.deleteEquipmentList(id: "list-1")

        XCTAssertEqual(created.item.identity, "equipment-1")
        XCTAssertEqual(detail.identity, "equipment-1")
        XCTAssertEqual(updated.item.unitWeight?.grams, 1_800)
        XCTAssertEqual(impact.equipmentListReferenceCount, 1)
        XCTAssertEqual(deleted.removedEquipmentListReferenceCount, 1)
        XCTAssertTrue(lists.items.isEmpty)
        XCTAssertEqual(createdList.equipmentList.identity, "list-1")
        XCTAssertTrue(listDetail.members.isEmpty)
        XCTAssertEqual(renamed.equipmentList.name, "高山露营")
        XCTAssertEqual(memberAdded.equipmentList.members[0].quantity, 2)
        XCTAssertEqual(memberRemoved.equipmentList.identity, "list-1")
        XCTAssertEqual(deletedList.deletedEquipmentListId, "list-1")
    }

    private func requestContract<Request: APIRequest>(
        _ request: Request
    ) -> (String, APIHTTPMethod, String, APIResponseEnvelope, [URLQueryItem]) {
        (request.identifier, request.method, request.path, request.responseEnvelope, request.query)
    }
}

final class TripEquipmentServiceTests: XCTestCase {
    func testRequestsUseCurrentSnapshotPathsDataEnvelopeAndNoOwnerOrSnapshotInputs() throws {
        let requests: [(String, APIHTTPMethod, String, APIResponseEnvelope, [URLQueryItem])] = [
            requestContract(TripEquipmentAPI.Current(tripID: "trip-1")),
            requestContract(try TripEquipmentAPI.CreateItem(
                tripID: "trip-1",
                name: "帐篷",
                quantity: 1,
                unitWeightGrams: 1_500,
                note: "双人"
            )),
            requestContract(try TripEquipmentAPI.UpdateItem(
                tripID: "trip-1",
                itemID: "item-1",
                update: TripEquipmentItemUpdate(name: "双人帐篷")
            )),
            requestContract(TripEquipmentAPI.DeleteItem(tripID: "trip-1", itemID: "item-1")),
            requestContract(TripEquipmentAPI.RecheckOwnership(tripID: "trip-1")),
        ]

        XCTAssertEqual(requests.map(\.0), [
            "GET /trips/trip-1/equipment",
            "POST /trips/trip-1/equipment/items",
            "PATCH /trips/trip-1/equipment/items/item-1",
            "DELETE /trips/trip-1/equipment/items/item-1",
            "POST /trips/trip-1/equipment:recheck-ownership",
        ])
        XCTAssertEqual(requests.map(\.1), [.get, .post, .patch, .delete, .post])
        XCTAssertTrue(requests.allSatisfy { $0.3 == .data })
        XCTAssertTrue(requests.allSatisfy { $0.4.isEmpty })
    }

    func testPatchEncodesAbsentValueAndNullAsDistinctStates() throws {
        let request = try TripEquipmentAPI.UpdateItem(
            tripID: "trip-1",
            itemID: "item-1",
            update: TripEquipmentItemUpdate(
                quantity: 2,
                unitWeight: .clear,
                note: .value("雨天备用")
            )
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.body)) as? [String: Any])

        XCTAssertNil(object["name"])
        XCTAssertEqual(object["quantity"] as? Int, 2)
        XCTAssertTrue(object["unitWeight"] is NSNull)
        XCTAssertEqual(object["note"] as? String, "雨天备用")
        XCTAssertEqual(Set(object.keys), ["quantity", "unitWeight", "note"])
    }

    func testPatchEncodesOptionalValueAndCanClearNote() throws {
        let request = try TripEquipmentAPI.UpdateItem(
            tripID: "trip-1",
            itemID: "item-1",
            update: TripEquipmentItemUpdate(
                unitWeight: .value(EquipmentWeight(grams: 1_800)),
                note: .clear
            )
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(request.body)) as? [String: Any])
        let weight = try XCTUnwrap(object["unitWeight"] as? [String: Any])

        XCTAssertEqual(weight["grams"] as? Int, 1_800)
        XCTAssertTrue(object["note"] is NSNull)
    }

    func testDeleteAndRecheckSendNoBody() {
        XCTAssertNil(TripEquipmentAPI.DeleteItem(tripID: "trip-1", itemID: "item-1").body)
        XCTAssertNil(TripEquipmentAPI.RecheckOwnership(tripID: "trip-1").body)
    }

    func testServiceDecodesBoundedProjectionAndUsesEveryTypedMutationRequest() async throws {
        let create = try TripEquipmentAPI.CreateItem(
            tripID: "trip-1",
            name: "帐篷",
            quantity: 1,
            unitWeightGrams: nil,
            note: nil
        )
        let update = try TripEquipmentAPI.UpdateItem(
            tripID: "trip-1",
            itemID: "item-1",
            update: TripEquipmentItemUpdate(note: .clear)
        )
        let requests: [String] = [
            TripEquipmentAPI.Current(tripID: "trip-1").identifier,
            create.identifier,
            update.identifier,
            TripEquipmentAPI.DeleteItem(tripID: "trip-1", itemID: "item-1").identifier,
            TripEquipmentAPI.RecheckOwnership(tripID: "trip-1").identifier,
        ]
        let fixture = Data(#"{"data":{"trip":{"identity":"trip-1","status":"planned","routeName":"贡嘎环线","startDate":"2026-08-25","endDate":"2026-08-27"},"revision":"revision-2","editable":true,"snapshot":{"identity":"snapshot-1","items":[{"identity":"item-1","name":"帐篷","quantity":1,"source":"user_added","ownershipStatus":"unconfirmed_owned"}],"summary":{"itemCount":1,"knownTotalWeight":{"grams":0},"missingWeightItemCount":1,"ownedItemCount":0,"unconfirmedOwnedItemCount":1}}}}"#.utf8)
        let service = TripEquipmentService(apiClient: MockAPIClient(
            fixtures: Dictionary(uniqueKeysWithValues: requests.map { ($0, fixture) })
        ))

        let current = try await service.getEquipment(tripID: "trip-1")
        let created = try await service.addItem(
            tripID: "trip-1",
            name: "帐篷",
            quantity: 1,
            unitWeightGrams: nil,
            note: nil
        )
        let updated = try await service.updateItem(
            tripID: "trip-1",
            itemID: "item-1",
            update: TripEquipmentItemUpdate(note: .clear)
        )
        let deleted = try await service.deleteItem(tripID: "trip-1", itemID: "item-1")
        let rechecked = try await service.recheckOwnership(tripID: "trip-1")

        XCTAssertEqual(current.snapshot.items[0].source, .userAdded)
        XCTAssertEqual(current.snapshot.items[0].ownershipStatus, .unconfirmedOwned)
        XCTAssertEqual(current.trip.routeName, "贡嘎环线")
        XCTAssertEqual([created, updated, deleted, rechecked].map(\.revision), [
            "revision-2", "revision-2", "revision-2", "revision-2",
        ])
    }

    private func requestContract<Request: APIRequest>(
        _ request: Request
    ) -> (String, APIHTTPMethod, String, APIResponseEnvelope, [URLQueryItem]) {
        (request.identifier, request.method, request.path, request.responseEnvelope, request.query)
    }
}
