import XCTest
@testable import WalkData

final class TripEquipmentContractTests: XCTestCase {
    func testTripItemPreservesPreparationFieldsWhenDecodedAndEncoded() throws {
        let data = Data(#"{"identity":"item-1","name":"饮水","quantity":1,"source":"user_added","ownershipStatus":"unconfirmed_owned","category":"drinking_water","equipmentType":"drinking_water","unitLabel":"份","weightScope":"含水瓶","carryAllocation":{"backpackQuantity":1,"wornQuantity":0,"handheldQuantity":0},"supply":{"kind":"drinking_water","amount":{"value":1500,"unit":"milliliter"},"containerMode":"included"},"packedQuantity":0,"ownershipCheckApplicable":false}"#.utf8)
        let item = try JSONDecoder().decode(TripEquipmentItem.self, from: data)
        let encoded = try JSONEncoder().encode(item)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        XCTAssertNotNil(object["carryAllocation"])
        XCTAssertNotNil(object["supply"])
        XCTAssertEqual(object["ownershipCheckApplicable"] as? Bool, false)
    }
}

extension TripEquipmentContractTests {
    func testOldTripItemLeavesUnknownPreparationValuesAbsent() throws {
        let item = try decodeItem(#"{"identity":"item-1","name":"未知","quantity":2,"source":"system_suggestion","ownershipStatus":"unconfirmed_owned"}"#)
        XCTAssertNil(item.category)
        XCTAssertNil(item.equipmentType)
        XCTAssertNil(item.unitLabel)
        XCTAssertNil(item.carryAllocation)
        XCTAssertNil(item.supply)
        XCTAssertNil(item.packedQuantity)
        XCTAssertNil(item.ownershipCheckApplicable)
        XCTAssertNil(item.unitWeight)
        XCTAssertNil(item.totalWeight)
    }

    func testFractionalUnitAndTotalWeightAreNotTruncated() throws {
        let item = try decodeItem(#"{"identity":"item-1","name":"袜子","quantity":2,"unitWeight":{"grams":50.125},"source":"user_added","ownershipStatus":"owned","category":"clothing","unitLabel":"双","carryAllocation":{"backpackQuantity":1,"wornQuantity":1,"handheldQuantity":0},"packedQuantity":1,"ownershipCheckApplicable":true}"#)
        XCTAssertEqual(item.unitWeight?.grams, 50.125)
        XCTAssertEqual(item.totalWeight?.grams, 100.25)
        XCTAssertEqual(item.carryAllocation?.wornQuantity, 1)
        XCTAssertEqual(item.packedQuantity, 1)
        XCTAssertEqual(item.ownershipCheckApplicable, true)
    }

    func testSupplyAmountDoesNotInventWeightOrMultiplyKnownWeight() throws {
        let unknown = try decodeItem(#"{"identity":"water","name":"水","quantity":1,"source":"user_added","ownershipStatus":"unconfirmed_owned","category":"drinking_water","equipmentType":"drinking_water","unitLabel":"份","supply":{"kind":"drinking_water","amount":{"value":1500.5,"unit":"milliliter"},"containerMode":"excluded"},"ownershipCheckApplicable":false}"#)
        XCTAssertEqual(unknown.supply?.amount.value, 1500.5)
        XCTAssertNil(unknown.unitWeight)
        XCTAssertNil(unknown.totalWeight)
        let known = TripEquipmentItem(identity: "food", name: "食品", quantity: 1, unitWeight: .init(grams: 500.25), note: nil, source: .userAdded, ownershipStatus: .unconfirmedOwned, category: .food, equipmentType: .food, unitLabel: .portion, weightScope: "半份食品", supply: .init(kind: .food, amount: .init(value: 0.5, unit: .portion), containerMode: .excluded), ownershipCheckApplicable: false)
        XCTAssertEqual(known.totalWeight?.grams, 500.25)
    }

    func testPreparationDecodesAllServerBucketsWithoutRecalculation() throws {
        let value = try preparation()
        XCTAssertEqual(value.tripID, "trip-1")
        XCTAssertEqual(value.revision, "revision-1")
        XCTAssertEqual(value.weightBreakdown.backpack.knownWeight.grams, 1200.75)
        XCTAssertEqual(value.weightBreakdown.backpack.missingWeightItemCount, 2)
        XCTAssertEqual(value.weightBreakdown.worn.knownWeight.grams, 100.25)
        XCTAssertEqual(value.weightBreakdown.worn.missingWeightItemCount, 1)
        XCTAssertEqual(value.weightBreakdown.handheld.knownWeight.grams, 50.5)
        XCTAssertEqual(value.weightBreakdown.unallocated.knownWeight.grams, 25.25)
        XCTAssertEqual(value.weightBreakdown.unallocated.missingWeightItemCount, 1)
        XCTAssertEqual(value.backpackBreakdown.equipment.knownWeight.grams, 500.25)
        XCTAssertEqual(value.backpackBreakdown.food.knownWeight.grams, 300.5)
        XCTAssertEqual(value.backpackBreakdown.drinkingWater.knownWeight.grams, 400)
        XCTAssertEqual(value.backpackBreakdown.fuel.missingWeightItemCount, 1)
        XCTAssertEqual(value.backpackBreakdown.unclassified.missingWeightItemCount, 1)
        XCTAssertEqual(value.packing.backpackQuantity, 6)
        XCTAssertEqual(value.packing.packedQuantity, 3)
        XCTAssertEqual(value.packing.unpackedQuantity, 3)
        XCTAssertEqual(value.packing.unallocatedItemCount, 2)
    }

    func testPreparationMissingBucketFailsInsteadOfBecomingZero() throws {
        var object = try jsonObject(Data(preparationJSON.utf8))
        var breakdown = try XCTUnwrap(object["weightBreakdown"] as? [String: Any])
        breakdown.removeValue(forKey: "unallocated")
        object["weightBreakdown"] = breakdown
        XCTAssertThrowsError(try JSONDecoder().decode(TripEquipmentPreparation.self, from: JSONSerialization.data(withJSONObject: object)))
    }

    func testAllElevenEndpointMethodsPathsAndPolicies() throws {
        assertRequest(TripEquipmentAPI.Current(tripID: "trip/甲"), .get, "/trips/trip%2F%E7%94%B2/equipment")
        assertRequest(try TripEquipmentAPI.CreateItem(tripID: "trip/甲", input: .init(name: "物品", quantity: 1), revision: "r1"), .post, "/trips/trip%2F%E7%94%B2/equipment/items")
        assertRequest(try TripEquipmentAPI.UpdateItem(tripID: "trip/甲", itemID: "item/#", update: .init(note: .value("备注"))), .patch, "/trips/trip%2F%E7%94%B2/equipment/items/item%2F%23")
        assertRequest(TripEquipmentAPI.DeleteItem(tripID: "trip/甲", itemID: "item/#"), .delete, "/trips/trip%2F%E7%94%B2/equipment/items/item%2F%23")
        assertRequest(TripEquipmentAPI.RecheckOwnership(tripID: "trip/甲"), .post, "/trips/trip%2F%E7%94%B2/equipment:recheck-ownership")
        assertRequest(try TripEquipmentAPI.FromPersonal(tripID: "trip/甲", personalEquipmentID: "asset", quantity: 2, revision: "r1", idempotencyKey: "key"), .post, "/trips/trip%2F%E7%94%B2/equipment/items:from-personal")
        assertRequest(try TripEquipmentAPI.AppendList(tripID: "trip/甲", equipmentListID: "list", revision: "r1", idempotencyKey: "key"), .post, "/trips/trip%2F%E7%94%B2/equipment:append-list")
        assertRequest(try TripEquipmentAPI.ReplaceWithPersonal(tripID: "trip/甲", itemID: "item/#", personalEquipmentID: "asset", quantity: 2, revision: "r1"), .put, "/trips/trip%2F%E7%94%B2/equipment/items/item%2F%23/personal-equipment")
        assertRequest(TripEquipmentAPI.Preparation(tripID: "trip/甲"), .get, "/trips/trip%2F%E7%94%B2/equipment/preparation")
        assertRequest(try TripEquipmentAPI.SetPacking(tripID: "trip/甲", itemID: "item/#", packedQuantity: 1, revision: "r1"), .put, "/trips/trip%2F%E7%94%B2/equipment/items/item%2F%23/packing")
        assertRequest(try TripEquipmentAPI.ResetPacking(tripID: "trip/甲", revision: "r1"), .post, "/trips/trip%2F%E7%94%B2/equipment:reset-packing")
    }

    func testCreateEncodesOnlyWritableFieldsAndPreservesFractionalWeight() throws {
        let request = try TripEquipmentAPI.CreateItem(tripID: "trip", input: .init(name: "饮水", quantity: 1, unitWeight: .init(grams: 1600.25), note: "出发", category: .drinkingWater, equipmentType: .drinkingWater, variant: "软水袋", unitLabel: .portion, weightScope: "含水袋", carryAllocation: .init(backpackQuantity: 1, wornQuantity: 0, handheldQuantity: 0), supply: .init(kind: .drinkingWater, amount: .init(value: 1500.5, unit: .milliliter), containerMode: .included)), revision: "r1")
        let body = try jsonObject(XCTUnwrap(request.body))
        XCTAssertEqual(Set(body.keys), ["name", "quantity", "unitWeight", "note", "category", "equipmentType", "variant", "unitLabel", "weightScope", "carryAllocation", "supply"])
        XCTAssertEqual((body["unitWeight"] as? [String: Double])?["grams"], 1600.25)
        XCTAssertEqual(body["unitLabel"] as? String, "份")
        XCTAssertEqual(request.headers["If-Match"], "\"r1\"")
        let minimal = try TripEquipmentAPI.CreateItem(tripID: "trip", input: .init(name: "未知", quantity: 1), revision: "r1")
        XCTAssertEqual(Set(try jsonObject(XCTUnwrap(minimal.body)).keys), ["name", "quantity"])
    }

    func testPatchSupportsOmitSetClearForEveryNullableField() throws {
        let unchanged = try JSONEncoder().encode(TripEquipmentItemUpdate(name: "新名称"))
        XCTAssertEqual(Set(try jsonObject(unchanged).keys), ["name"])
        let cleared = TripEquipmentItemUpdate(unitWeight: .clear, note: .clear, category: .clear, equipmentType: .clear, variant: .clear, unitLabel: .clear, weightScope: .clear, carryAllocation: .clear, supply: .clear)
        let clearObject = try jsonObject(JSONEncoder().encode(cleared))
        XCTAssertEqual(Set(clearObject.keys), ["unitWeight", "note", "category", "equipmentType", "variant", "unitLabel", "weightScope", "carryAllocation", "supply"])
        XCTAssertTrue(clearObject.values.allSatisfy { $0 is NSNull })
        let changed = TripEquipmentItemUpdate(quantity: 1, unitWeight: .value(.init(grams: 500.75)), note: .value("备注"), category: .value(.food), equipmentType: .value(.food), variant: .value("晚餐"), unitLabel: .value(.portion), weightScope: .value("含包装"), carryAllocation: .value(.init(backpackQuantity: 1, wornQuantity: 0, handheldQuantity: 0)), supply: .value(.init(kind: .food, amount: .init(value: 0.5, unit: .portion), containerMode: .included)))
        let object = try jsonObject(JSONEncoder().encode(changed))
        XCTAssertEqual(object["category"] as? String, "food")
        XCTAssertEqual(object["unitLabel"] as? String, "份")
        XCTAssertEqual((object["unitWeight"] as? [String: Double])?["grams"], 500.75)
        XCTAssertEqual(Set((object["carryAllocation"] as? [String: Any])?.keys.map { $0 } ?? []), ["backpackQuantity", "wornQuantity", "handheldQuantity"])
        XCTAssertNil(object["packedQuantity"])
        XCTAssertNil(object["revision"])
    }

    func testPatchNewFieldsRequireRevisionIncludingExplicitNull() throws {
        let updates: [TripEquipmentItemUpdate] = [.init(category: .clear), .init(equipmentType: .clear), .init(variant: .clear), .init(unitLabel: .clear), .init(weightScope: .clear), .init(carryAllocation: .clear), .init(supply: .clear)]
        for update in updates {
            XCTAssertThrowsError(try TripEquipmentAPI.UpdateItem(tripID: "trip", itemID: "item", update: update)) {
                XCTAssertEqual($0 as? EquipmentRequestValidationError, .missingRevision)
            }
            let request = try TripEquipmentAPI.UpdateItem(tripID: "trip", itemID: "item", update: update, revision: "r1")
            XCTAssertEqual(request.headers["If-Match"], "\"r1\"")
        }
        let legacy = try TripEquipmentAPI.UpdateItem(tripID: "trip", itemID: "item", update: .init(name: "名称", unitWeight: .clear, note: .clear))
        XCTAssertNil(legacy.headers["If-Match"])
    }

    func testSelectionReplacementAndAppendPreserveOnlyTheirCommandInput() throws {
        let selection = try TripEquipmentAPI.FromPersonal(tripID: "trip", personalEquipmentID: "asset/甲?", quantity: 2, revision: "r1", idempotencyKey: " original key ")
        let selectionBody = try jsonObject(XCTUnwrap(selection.body))
        XCTAssertEqual(Set(selectionBody.keys), ["personalEquipmentId", "quantity"])
        XCTAssertEqual(selectionBody["personalEquipmentId"] as? String, "asset/甲?")
        XCTAssertEqual(selectionBody["quantity"] as? Int, 2)
        XCTAssertEqual(selection.headers, ["If-Match": "\"r1\"", "Idempotency-Key": " original key "])
        let replacement = try TripEquipmentAPI.ReplaceWithPersonal(tripID: "trip", itemID: "item", personalEquipmentID: "asset/甲?", quantity: 2, revision: "r1")
        XCTAssertEqual(try jsonObject(XCTUnwrap(replacement.body)) as NSDictionary, selectionBody as NSDictionary)
        XCTAssertEqual(replacement.headers, ["If-Match": "\"r1\""])
        let append = try TripEquipmentAPI.AppendList(tripID: "trip", equipmentListID: "list/甲?", revision: "r1", idempotencyKey: "key")
        XCTAssertEqual(try jsonObject(XCTUnwrap(append.body)) as NSDictionary, ["equipmentListId": "list/甲?"] as NSDictionary)
        XCTAssertEqual(append.headers, ["If-Match": "\"r1\"", "Idempotency-Key": "key"])
    }

    func testPackingHasDedicatedBodyAndResetBodyIsZeroBytes() throws {
        let packing = try TripEquipmentAPI.SetPacking(tripID: "trip", itemID: "item", packedQuantity: 0, revision: "r1")
        XCTAssertEqual(try jsonObject(XCTUnwrap(packing.body)) as NSDictionary, ["packedQuantity": 0] as NSDictionary)
        let reset = try TripEquipmentAPI.ResetPacking(tripID: "trip", revision: "r1")
        XCTAssertNil(reset.body)
        XCTAssertNil(reset.contentType)
        XCTAssertEqual(reset.headers, ["If-Match": "\"r1\""])
        let recheck = try TripEquipmentAPI.RecheckOwnership(tripID: "trip", revision: "r1")
        XCTAssertNil(recheck.body)
        XCTAssertEqual(recheck.headers["If-Match"], "\"r1\"")
        XCTAssertEqual(try TripEquipmentAPI.DeleteItem(tripID: "trip", itemID: "item", revision: "r1").headers["If-Match"], "\"r1\"")
    }

    func testInvalidCommandHeadersAndNonFiniteNumbersFailBeforeTransport() {
        for revision in ["", "bad revision", "\"quoted\"", "r\n1", "\t", "W/\"weak\""] {
            XCTAssertThrowsError(try TripEquipmentAPI.ResetPacking(tripID: "trip", revision: revision))
        }
        XCTAssertThrowsError(try TripEquipmentAPI.FromPersonal(tripID: "trip", personalEquipmentID: "asset", quantity: 1, revision: "r1", idempotencyKey: " \n "))
        XCTAssertThrowsError(try TripEquipmentAPI.AppendList(tripID: "trip", equipmentListID: "list", revision: "r1", idempotencyKey: ""))
        XCTAssertThrowsError(try TripEquipmentAPI.CreateItem(tripID: "trip", input: .init(name: "物品", quantity: 1, unitWeight: .init(grams: .nan)), revision: "r1"))
        XCTAssertThrowsError(try TripEquipmentAPI.UpdateItem(tripID: "trip", itemID: "item", update: .init(unitWeight: .value(.init(grams: .infinity)))))
        XCTAssertThrowsError(try TripEquipmentAPI.CreateItem(tripID: "trip", input: .init(name: "燃料", quantity: 1, supply: .init(kind: .fuel, amount: .init(value: .infinity, unit: .gram), containerMode: .included)), revision: "r1"))
    }

    func testEveryEndpointRejectsMissingOrMismatchedETag() throws {
        let projection = try current()
        try assertSnapshotETag(TripEquipmentAPI.Current(tripID: "trip"), projection)
        try assertSnapshotETag(TripEquipmentAPI.CreateItem(tripID: "trip", input: .init(name: "item", quantity: 1), revision: "r1"), projection)
        try assertSnapshotETag(TripEquipmentAPI.UpdateItem(tripID: "trip", itemID: "item", update: .init(note: .clear)), projection)
        try assertSnapshotETag(TripEquipmentAPI.DeleteItem(tripID: "trip", itemID: "item"), projection)
        try assertSnapshotETag(TripEquipmentAPI.RecheckOwnership(tripID: "trip"), projection)
        try assertSnapshotETag(TripEquipmentAPI.FromPersonal(tripID: "trip", personalEquipmentID: "asset", quantity: 1, revision: "r1", idempotencyKey: "key"), projection)
        try assertSnapshotETag(TripEquipmentAPI.AppendList(tripID: "trip", equipmentListID: "list", revision: "r1", idempotencyKey: "key"), projection)
        try assertSnapshotETag(TripEquipmentAPI.ReplaceWithPersonal(tripID: "trip", itemID: "item", personalEquipmentID: "asset", quantity: 1, revision: "r1"), projection)
        try assertSnapshotETag(TripEquipmentAPI.SetPacking(tripID: "trip", itemID: "item", packedQuantity: 0, revision: "r1"), projection)
        try assertSnapshotETag(TripEquipmentAPI.ResetPacking(tripID: "trip", revision: "r1"), projection)
        let request = TripEquipmentAPI.Preparation(tripID: "trip")
        let value = try preparation()
        XCTAssertNoThrow(try request.validateResponse(value, statusCode: 200, headers: ["etag": "\"revision-1\""]))
        XCTAssertThrowsError(try request.validateResponse(value, statusCode: 200, headers: [:]))
        XCTAssertThrowsError(try request.validateResponse(value, statusCode: 200, headers: ["ETag": "W/\"revision-1\""]))
    }

    func testLegacyIntegerConvenienceRemainsCompatible() throws {
        let request = try TripEquipmentAPI.CreateItem(tripID: "trip", name: "物品", quantity: 2, unitWeightGrams: 123, note: nil)
        let body = try jsonObject(XCTUnwrap(request.body))
        XCTAssertEqual((body["unitWeight"] as? [String: Double])?["grams"], 123)
        XCTAssertNil(body["note"])
        XCTAssertNil(request.headers["If-Match"])
    }

    func testServiceExposesAllTypedRequestsWithoutChangingPayload() async throws {
        let client = TripRequestRecorder(snapshot: Data(currentJSON.utf8), preparation: Data(preparationJSON.utf8))
        let service: any TripEquipmentPreparing = TripEquipmentService(apiClient: client)
        _ = try await service.getEquipment(tripID: "trip")
        _ = try await service.addItem(tripID: "trip", input: .init(name: "物品", quantity: 1, unitWeight: .init(grams: 12.5)), revision: "r1")
        _ = try await service.updateItem(tripID: "trip", itemID: "item", update: .init(carryAllocation: .clear), revision: "r1")
        _ = try await service.deleteItem(tripID: "trip", itemID: "item", revision: "r1")
        _ = try await service.recheckOwnership(tripID: "trip", revision: "r1")
        _ = try await service.addFromPersonal(tripID: "trip", personalEquipmentID: "asset", quantity: 2, revision: "r1", idempotencyKey: "selection")
        _ = try await service.appendList(tripID: "trip", equipmentListID: "list", revision: "r1", idempotencyKey: "append")
        _ = try await service.replaceWithPersonal(tripID: "trip", itemID: "item", personalEquipmentID: "asset", quantity: 1, revision: "r1")
        let preparation = try await service.getPreparation(tripID: "trip")
        _ = try await service.setPacking(tripID: "trip", itemID: "item", packedQuantity: 1, revision: "r1")
        _ = try await service.resetPacking(tripID: "trip", revision: "r1")
        XCTAssertEqual(preparation.weightBreakdown.backpack.knownWeight.grams, 1200.75)
        let requests = await client.requests
        XCTAssertEqual(requests.count, 11)
        XCTAssertEqual(requests[5].headers["Idempotency-Key"], "selection")
        XCTAssertEqual(requests[6].headers["Idempotency-Key"], "append")
        XCTAssertEqual(requests[10].path, "/trips/trip/equipment:reset-packing")
        XCTAssertNil(requests[10].body)
    }

    private func assertRequest<Request: APIRequest>(_ request: Request, _ method: APIHTTPMethod, _ path: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(request.method, method, file: file, line: line)
        XCTAssertEqual(request.path, path, file: file, line: line)
        XCTAssertTrue(request.pathIsPercentEncoded, file: file, line: line)
        XCTAssertTrue(request.query.isEmpty, file: file, line: line)
        XCTAssertEqual(request.responseEnvelope, .data, file: file, line: line)
        XCTAssertEqual(request.authenticationPolicy, .required, file: file, line: line)
        XCTAssertNil(request.offlineEligibility, file: file, line: line)
        if method != .get { XCTAssertEqual(request.storagePolicy, .none, file: file, line: line) }
    }

    private func assertSnapshotETag<Request: APIRequest>(_ request: Request, _ projection: TripEquipmentProjection, file: StaticString = #filePath, line: UInt = #line) throws where Request.Response == TripEquipmentProjection {
        XCTAssertNoThrow(try request.validateResponse(projection, statusCode: 200, headers: ["eTaG": "\"revision-1\""]), file: file, line: line)
        for headers in [[:], ["ETag": "\"stale\""], ["ETag": "W/\"revision-1\""], ["ETag": "revision-1"], ["ETag": "*"], ["ETag": "\"revision-1\", \"other\""], ["ETag": "\"revision-1\"", "etag": "\"revision-1\""]] {
            XCTAssertThrowsError(try request.validateResponse(projection, statusCode: 200, headers: headers), file: file, line: line) {
                XCTAssertEqual($0 as? APIClientError, .invalidResponse, file: file, line: line)
            }
        }
    }

    private func decodeItem(_ json: String) throws -> TripEquipmentItem {
        try JSONDecoder().decode(TripEquipmentItem.self, from: Data(json.utf8))
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func preparation() throws -> TripEquipmentPreparation {
        try JSONDecoder().decode(TripEquipmentPreparation.self, from: Data(preparationJSON.utf8))
    }

    private func current() throws -> TripEquipmentProjection {
        try JSONDecoder().decode(TripEquipmentProjection.self, from: Data(currentJSON.utf8))
    }

    private var currentJSON: String {
        #"{"trip":{"identity":"trip-1","status":"planned","routeName":"路线","startDate":"2026-10-01","endDate":"2026-10-02"},"revision":"revision-1","editable":true,"snapshot":{"identity":"snapshot-1","items":[],"summary":{"itemCount":0,"knownTotalWeight":{"grams":0},"missingWeightItemCount":0,"ownedItemCount":0,"unconfirmedOwnedItemCount":0}}}"#
    }

    private var preparationJSON: String {
        #"{"tripId":"trip-1","revision":"revision-1","weightBreakdown":{"backpack":{"knownWeight":{"grams":1200.75},"missingWeightItemCount":2},"worn":{"knownWeight":{"grams":100.25},"missingWeightItemCount":1},"handheld":{"knownWeight":{"grams":50.5},"missingWeightItemCount":0},"unallocated":{"knownWeight":{"grams":25.25},"missingWeightItemCount":1}},"backpackBreakdown":{"equipment":{"knownWeight":{"grams":500.25},"missingWeightItemCount":0},"food":{"knownWeight":{"grams":300.5},"missingWeightItemCount":0},"drinkingWater":{"knownWeight":{"grams":400},"missingWeightItemCount":0},"fuel":{"knownWeight":{"grams":0},"missingWeightItemCount":1},"unclassified":{"knownWeight":{"grams":0},"missingWeightItemCount":1}},"packing":{"backpackQuantity":6,"packedQuantity":3,"unpackedQuantity":3,"unallocatedItemCount":2}}"#
    }
}

private actor TripRequestRecorder: APIClient {
    struct RecordedRequest {
        let path: String
        let body: Data?
        let headers: [String: String]
    }

    private let snapshot: Data
    private let preparation: Data
    private(set) var requests: [RecordedRequest] = []

    init(snapshot: Data, preparation: Data) {
        self.snapshot = snapshot
        self.preparation = preparation
    }

    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        requests.append(.init(path: request.path, body: request.body, headers: request.headers))
        let json = request.path.hasSuffix("/preparation") ? preparation : snapshot
        return try JSONDecoder().decode(Request.Response.self, from: json)
    }
}
