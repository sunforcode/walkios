import Foundation
import XCTest
@testable import WalkData

final class PersonalEquipmentContractTests: XCTestCase {
    func testPersonalEquipmentPreservesFractionalGrams() throws {
        let data = Data(#"{"identity":"equipment-1","name":"修补贴","ownedQuantity":2,"unitWeight":{"grams":12.5}}"#.utf8)
        let equipment = try JSONDecoder().decode(PersonalEquipment.self, from: data)
        XCTAssertEqual(Double(try XCTUnwrap(equipment.unitWeight).grams), 12.5)
    }

    func testAllFifteenRequestsUseTheirDocumentedMethodsPathsAuthenticationAndEnvelope() throws {
        let rows = [
            contract(PersonalEquipmentAPI.Collection()),
            contract(try PersonalEquipmentAPI.Create(name: "装备", ownedQuantity: 1, unitWeightGrams: nil)),
            contract(try PersonalEquipmentAPI.FromCatalog(input: .init(catalogEquipmentId: "c", ownedQuantity: 1), idempotencyKey: "adopt")),
            contract(PersonalEquipmentAPI.Detail(personalEquipmentID: "e")),
            contract(try PersonalEquipmentAPI.Update(personalEquipmentID: "e", update: .init(name: "新名称"))),
            contract(PersonalEquipmentAPI.DeletionImpact(personalEquipmentID: "e")),
            contract(PersonalEquipmentAPI.Delete(personalEquipmentID: "e")),
            contract(EquipmentListAPI.Collection()),
            contract(try EquipmentListAPI.Create(name: "清单")),
            contract(try EquipmentListAPI.Copy(equipmentListID: "l", name: "副本", idempotencyKey: "copy")),
            contract(EquipmentListAPI.Detail(equipmentListID: "l")),
            contract(try EquipmentListAPI.Rename(equipmentListID: "l", name: "新清单")),
            contract(EquipmentListAPI.Delete(equipmentListID: "l")),
            contract(try EquipmentListAPI.PutMember(equipmentListID: "l", personalEquipmentID: "e", quantity: 2)),
            contract(EquipmentListAPI.DeleteMember(equipmentListID: "l", personalEquipmentID: "e")),
        ]
        XCTAssertEqual(rows, [
            "GET /personal-equipment", "POST /personal-equipment", "POST /personal-equipment:from-catalog",
            "GET /personal-equipment/e", "PATCH /personal-equipment/e", "GET /personal-equipment/e/deletion-impact",
            "DELETE /personal-equipment/e?confirmListRemoval=true", "GET /equipment-lists", "POST /equipment-lists",
            "POST /equipment-lists/l:copy", "GET /equipment-lists/l", "PATCH /equipment-lists/l", "DELETE /equipment-lists/l",
            "PUT /equipment-lists/l/members/e", "DELETE /equipment-lists/l/members/e",
        ])
    }

    func testEveryOpaquePathIdentityStaysOneEncodedPathSegment() throws {
        let id = "A /?#%中文"
        let encoded = "A%20%2F%3F%23%25%E4%B8%AD%E6%96%87"
        XCTAssertEqual(PersonalEquipmentAPI.Detail(personalEquipmentID: id).path, "/personal-equipment/\(encoded)")
        XCTAssertEqual(try PersonalEquipmentAPI.Update(personalEquipmentID: id, update: .init(name: "n")).path, "/personal-equipment/\(encoded)")
        XCTAssertEqual(PersonalEquipmentAPI.DeletionImpact(personalEquipmentID: id).path, "/personal-equipment/\(encoded)/deletion-impact")
        XCTAssertEqual(PersonalEquipmentAPI.Delete(personalEquipmentID: id).path, "/personal-equipment/\(encoded)")
        XCTAssertEqual(EquipmentListAPI.Detail(equipmentListID: id).path, "/equipment-lists/\(encoded)")
        XCTAssertEqual(try EquipmentListAPI.Rename(equipmentListID: id, name: "n").path, "/equipment-lists/\(encoded)")
        XCTAssertEqual(EquipmentListAPI.Delete(equipmentListID: id).path, "/equipment-lists/\(encoded)")
        XCTAssertEqual(try EquipmentListAPI.Copy(equipmentListID: id, name: "n", idempotencyKey: "k").path, "/equipment-lists/\(encoded):copy")
        XCTAssertEqual(try EquipmentListAPI.PutMember(equipmentListID: id, personalEquipmentID: id, quantity: 1).path, "/equipment-lists/\(encoded)/members/\(encoded)")
        XCTAssertEqual(EquipmentListAPI.DeleteMember(equipmentListID: id, personalEquipmentID: id).path, "/equipment-lists/\(encoded)/members/\(encoded)")
    }

    func testFiltersPreserveLiteralKeywordAndBothBooleanValues() {
        let request = PersonalEquipmentAPI.Collection(keyword: "  bag_50% & +  ", category: .sleeping, equipmentType: .sleepingBag, missingWeight: true)
        XCTAssertEqual(request.query, [
            URLQueryItem(name: "keyword", value: "  bag_50% & +  "),
            URLQueryItem(name: "category", value: "sleeping"),
            URLQueryItem(name: "equipmentType", value: "sleeping_bag"),
            URLQueryItem(name: "missingWeight", value: "true"),
        ])
        XCTAssertEqual(PersonalEquipmentAPI.Collection(missingWeight: false).query, [URLQueryItem(name: "missingWeight", value: "false")])
        XCTAssertTrue(PersonalEquipmentAPI.Collection().query.isEmpty)
    }

    func testManualCreateEncodesCompleteMutableConfigurationWithoutReadonlyFields() throws {
        let request = try PersonalEquipmentAPI.Create(input: .init(
            name: "睡袋", ownedQuantity: 2, unitWeight: .init(grams: 12.5), category: .sleeping,
            equipmentType: .sleepingBag, variant: "M", unitLabel: .item, weightScope: "含袋"
        ))
        let body = try object(request.body)
        XCTAssertEqual(Set(body.keys), Set(["name", "ownedQuantity", "unitWeight", "category", "equipmentType", "variant", "unitLabel", "weightScope"]))
        XCTAssertEqual(body["category"] as? String, "sleeping")
        XCTAssertEqual(body["equipmentType"] as? String, "sleeping_bag")
        XCTAssertEqual(body["unitLabel"] as? String, "件")
        XCTAssertEqual((body["unitWeight"] as? [String: Double])?["grams"], 12.5)
    }

    func testManualCreateOmitsAllUnknownValuesRatherThanEncodingNull() throws {
        let request = try PersonalEquipmentAPI.Create(input: .init(name: "旧装备", ownedQuantity: 1))
        XCTAssertEqual(Set(try object(request.body).keys), Set(["name", "ownedQuantity"]))
    }

    func testIntegerCreationCompatibilityPreservesItsNumericWeight() throws {
        let grams: Int = 325
        let body = try object(PersonalEquipmentAPI.Create(name: "旧装备", ownedQuantity: 1, unitWeightGrams: grams).body)
        XCTAssertEqual((body["unitWeight"] as? [String: Double])?["grams"], 325)
        XCTAssertEqual(EquipmentWeight(grams: grams).grams, 325)
        XCTAssertEqual(EquipmentWeight(grams: Int64(625)).grams, 625)
    }

    func testPatchDistinguishesOmissionClearAndNewValuesForEveryOptionalField() throws {
        let unchanged = try object(PersonalEquipmentAPI.Update(personalEquipmentID: "e", update: .init(name: "n")).body)
        XCTAssertEqual(Set(unchanged.keys), ["name"])
        let clear = try object(PersonalEquipmentAPI.Update(personalEquipmentID: "e", update: .init(
            unitWeight: .clear, category: .clear, equipmentType: .clear, variant: .clear, unitLabel: .clear, weightScope: .clear
        )).body)
        XCTAssertEqual(Set(clear.keys), Set(["unitWeight", "category", "equipmentType", "variant", "unitLabel", "weightScope"]))
        XCTAssertTrue(clear.values.allSatisfy { $0 is NSNull })
        let values = try object(PersonalEquipmentAPI.Update(personalEquipmentID: "e", update: .init(
            name: "new", ownedQuantity: 3, unitWeight: .value(.init(grams: 12.5)), category: .value(.sleeping),
            equipmentType: .value(.sleepingBag), variant: .value("L"), unitLabel: .value(.item), weightScope: .value("含袋")
        )).body)
        XCTAssertEqual(values["ownedQuantity"] as? Int, 3)
        XCTAssertEqual(values["category"] as? String, "sleeping")
        XCTAssertEqual(values["equipmentType"] as? String, "sleeping_bag")
        XCTAssertEqual(values["variant"] as? String, "L")
        XCTAssertEqual(values["unitLabel"] as? String, "件")
        XCTAssertEqual(values["weightScope"] as? String, "含袋")
        XCTAssertEqual((values["unitWeight"] as? [String: Double])?["grams"], 12.5)
    }

    func testCatalogAdoptionOmissionRequestsServerReferenceValues() throws {
        let input = PersonalEquipmentFromCatalogRequest(catalogEquipmentId: "catalog / opaque", ownedQuantity: 2)
        let request = try PersonalEquipmentAPI.FromCatalog(input: input, idempotencyKey: "same-key")
        let body = try object(request.body)
        XCTAssertEqual(Set(body.keys), Set(["catalogEquipmentId", "ownedQuantity"]))
        XCTAssertEqual(body["catalogEquipmentId"] as? String, "catalog / opaque")
        XCTAssertEqual(request.headers, ["Idempotency-Key": "same-key"])
    }

    func testCatalogAdoptionCanExplicitlyClearEveryCopiedOptionalValue() throws {
        let request = try PersonalEquipmentAPI.FromCatalog(input: .init(
            catalogEquipmentId: "c", ownedQuantity: 1, unitWeight: .clear, variant: .clear, unitLabel: .clear, weightScope: .clear
        ), idempotencyKey: "k")
        let body = try object(request.body)
        for field in ["unitWeight", "variant", "unitLabel", "weightScope"] { XCTAssertTrue(body[field] is NSNull, field) }
        XCTAssertNil(body["name"])
        XCTAssertNil(body["category"])
        XCTAssertNil(body["unitWeightSource"])
    }

    func testCatalogAdoptionCanOverrideWeightAndConfiguration() throws {
        let request = try PersonalEquipmentAPI.FromCatalog(input: .init(
            catalogEquipmentId: "c", ownedQuantity: 2, name: "我的鞋", unitWeight: .value(.init(grams: 720.25)),
            variant: .value("43"), unitLabel: .value(.pairOfShoes), weightScope: .value("一双")
        ), idempotencyKey: "k")
        let body = try object(request.body)
        XCTAssertEqual(Set(body.keys), Set(["catalogEquipmentId", "ownedQuantity", "name", "unitWeight", "variant", "unitLabel", "weightScope"]))
        XCTAssertEqual(body["name"] as? String, "我的鞋")
        XCTAssertEqual(body["variant"] as? String, "43")
        XCTAssertEqual(body["unitLabel"] as? String, "双")
        XCTAssertEqual((body["unitWeight"] as? [String: Double])?["grams"], 720.25)
    }

    func testCopySendsOnlyNameAndCallerOwnedIdempotencyKey() throws {
        let request = try EquipmentListAPI.Copy(equipmentListID: "l", name: "副本", idempotencyKey: "  opaque-key  ")
        XCTAssertEqual(try object(request.body) as NSDictionary, ["name": "副本"] as NSDictionary)
        XCTAssertEqual(request.headers, ["Idempotency-Key": "  opaque-key  "])
        XCTAssertTrue(request.query.isEmpty)
    }

    func testIdempotencyCommandsRejectEmptyKeysInsteadOfGeneratingNewKeys() {
        XCTAssertThrowsError(try PersonalEquipmentAPI.FromCatalog(input: .init(catalogEquipmentId: "c", ownedQuantity: 1), idempotencyKey: " \n")) { error in
            XCTAssertEqual(error as? EquipmentRequestValidationError, .emptyIdempotencyKey)
        }
        XCTAssertThrowsError(try EquipmentListAPI.Copy(equipmentListID: "l", name: "副本", idempotencyKey: "")) { error in
            XCTAssertEqual(error as? EquipmentRequestValidationError, .emptyIdempotencyKey)
        }
    }

    func testPersonalAndListMemberProjectionsPreserveAllConfigurationAndSourceFields() throws {
        let item = try JSONDecoder().decode(PersonalEquipment.self, from: Data(itemJSON.utf8))
        XCTAssertEqual(item.category, .sleeping)
        XCTAssertEqual(item.equipmentType, .sleepingBag)
        XCTAssertEqual(item.variant, "M")
        XCTAssertEqual(item.unitLabel, .item)
        XCTAssertEqual(item.weightScope, "含袋")
        XCTAssertEqual(item.unitWeightSource, .catalogReference)
        XCTAssertEqual(item.catalogEquipmentId, "catalog-1")
        let member = try JSONDecoder().decode(EquipmentListMember.self, from: Data(memberJSON.utf8))
        XCTAssertEqual(member.unitWeight, item.unitWeight)
        XCTAssertEqual(member.category, item.category)
        XCTAssertEqual(member.equipmentType, item.equipmentType)
        XCTAssertEqual(member.variant, item.variant)
        XCTAssertEqual(member.unitLabel, item.unitLabel)
        XCTAssertEqual(member.weightScope, item.weightScope)
        XCTAssertEqual(member.unitWeightSource, item.unitWeightSource)
        XCTAssertEqual(member.catalogEquipmentId, item.catalogEquipmentId)
        XCTAssertEqual(member.quantity, 3)
        XCTAssertEqual(member.ownedQuantity, 2)
    }

    func testLegacyMissingConfigurationIsNotReplacedByDefaults() throws {
        let item = try JSONDecoder().decode(PersonalEquipment.self, from: Data(#"{"identity":"e","name":"旧装备","ownedQuantity":1,"unitWeight":{"grams":100}}"#.utf8))
        XCTAssertNil(item.category)
        XCTAssertNil(item.equipmentType)
        XCTAssertNil(item.variant)
        XCTAssertNil(item.unitLabel)
        XCTAssertNil(item.weightScope)
        XCTAssertNil(item.unitWeightSource)
        XCTAssertNil(item.catalogEquipmentId)
        XCTAssertEqual(item.unitWeight?.grams, 100)
        let absent = try JSONDecoder().decode(PersonalEquipment.self, from: Data(#"{"identity":"e","name":"未称重","ownedQuantity":1}"#.utf8))
        XCTAssertNil(absent.unitWeight)
    }

    func testUnknownCodesFailDecodingWithoutFallback() {
        for extra in [#""category":"other""#, #""equipmentType":"unknown""#, #""unitLabel":"kg""#, #""unitWeightSource":"measured""#] {
            let json = #"{"identity":"e","name":"装备","ownedQuantity":1,"# + extra + "}"
            XCTAssertThrowsError(try JSONDecoder().decode(PersonalEquipment.self, from: Data(json.utf8)))
        }
    }

    func testNonFiniteWeightCannotBeSentAsJSON() {
        for grams in [Double.nan, .infinity, -.infinity] {
            XCTAssertThrowsError(try PersonalEquipmentAPI.Create(input: .init(name: "e", ownedQuantity: 1, unitWeight: .init(grams: grams))))
            XCTAssertThrowsError(try PersonalEquipmentAPI.Update(personalEquipmentID: "e", update: .init(unitWeight: .value(.init(grams: grams)))))
        }
    }

    func testFilteredCollectionKeepsServerAccountSummaryEvenWithNoMatches() async throws {
        let request = PersonalEquipmentAPI.Collection(category: .sleeping, missingWeight: true)
        let client = MockAPIClient(fixtures: [request.identifier: envelope("{\"items\":[],\"summary\":\(summaryJSON)}")])
        let service: any PersonalEquipmentManaging = EquipmentService(apiClient: client)
        let result = try await service.getPersonalEquipment(filter: .init(category: .sleeping, missingWeight: true))
        XCTAssertTrue(result.items.isEmpty)
        XCTAssertEqual(result.summary.equipmentItemCount, 5)
        XCTAssertEqual(result.summary.equipmentListCount, 2)
        XCTAssertEqual(result.summary.knownTotalWeight.grams, 142.5)
        XCTAssertEqual(result.summary.missingWeightItemCount, 1)
    }

    func testAllReadAndMutationEnvelopeShapesDecodeThroughAPIClient() async throws {
        let mutation = "{\"item\":\(itemJSON),\"summary\":\(summaryJSON)}"
        let listCreate = "{\"equipmentList\":\(listJSON),\"personalEquipmentSummary\":\(summaryJSON)}"
        let listMutation = "{\"equipmentList\":\(listJSON)}"
        let collection = try await execute(PersonalEquipmentAPI.Collection(), "{\"items\":[\(itemJSON)],\"summary\":\(summaryJSON)}")
        XCTAssertEqual(collection.items.first?.unitWeight?.grams, 12.5)
        let created = try await execute(PersonalEquipmentAPI.Create(name: "睡袋", ownedQuantity: 2, unitWeightGrams: nil), mutation)
        XCTAssertEqual(created.item.identity, "equipment-1")
        let adopted = try await execute(PersonalEquipmentAPI.FromCatalog(input: .init(catalogEquipmentId: "c", ownedQuantity: 1), idempotencyKey: "k"), mutation)
        XCTAssertEqual(adopted.item.catalogEquipmentId, "catalog-1")
        let detail = try await execute(PersonalEquipmentAPI.Detail(personalEquipmentID: "equipment-1"), itemJSON)
        XCTAssertEqual(detail.unitWeightSource, .catalogReference)
        let updated = try await execute(PersonalEquipmentAPI.Update(personalEquipmentID: "equipment-1", update: .init(name: "n")), mutation)
        XCTAssertEqual(updated.summary.knownTotalWeight.grams, 142.5)
        let impact = try await execute(PersonalEquipmentAPI.DeletionImpact(personalEquipmentID: "equipment-1"), #"{"personalEquipmentId":"equipment-1","equipmentListReferenceCount":1,"affectedEquipmentLists":[{"identity":"list-1","name":"清单"}]}"#)
        XCTAssertEqual(impact.affectedEquipmentLists.first?.identity, "list-1")
        let deleted = try await execute(PersonalEquipmentAPI.Delete(personalEquipmentID: "equipment-1"), "{\"deletedPersonalEquipmentId\":\"equipment-1\",\"removedEquipmentListReferenceCount\":1,\"summary\":\(summaryJSON)}")
        XCTAssertEqual(deleted.removedEquipmentListReferenceCount, 1)
        let lists = try await execute(EquipmentListAPI.Collection(), #"{"items":[{"identity":"list-1","name":"清单","summary":{"itemCount":1,"knownTotalWeight":{"grams":37.5},"missingWeightItemCount":0}}]}"#)
        XCTAssertEqual(lists.items.first?.summary.knownTotalWeight.grams, 37.5)
        let newList = try await execute(EquipmentListAPI.Create(name: "清单"), listCreate)
        XCTAssertEqual(newList.personalEquipmentSummary.equipmentItemCount, 5)
        let copied = try await execute(EquipmentListAPI.Copy(equipmentListID: "list-1", name: "副本", idempotencyKey: "k"), listCreate)
        XCTAssertEqual(copied.equipmentList.members.first?.catalogEquipmentId, "catalog-1")
        let list = try await execute(EquipmentListAPI.Detail(equipmentListID: "list-1"), listJSON)
        XCTAssertEqual(list.members.first?.quantity, 3)
        let renamed = try await execute(EquipmentListAPI.Rename(equipmentListID: "list-1", name: "新名称"), listMutation)
        XCTAssertEqual(renamed.equipmentList.summary.knownTotalWeight.grams, 37.5)
        let removedList = try await execute(EquipmentListAPI.Delete(equipmentListID: "list-1"), "{\"deletedEquipmentListId\":\"list-1\",\"personalEquipmentSummary\":\(summaryJSON)}")
        XCTAssertEqual(removedList.deletedEquipmentListId, "list-1")
        let memberAdded = try await execute(EquipmentListAPI.PutMember(equipmentListID: "list-1", personalEquipmentID: "equipment-1", quantity: 3), listMutation)
        XCTAssertEqual(memberAdded.equipmentList.members.first?.ownedQuantity, 2)
        let memberRemoved = try await execute(EquipmentListAPI.DeleteMember(equipmentListID: "list-1", personalEquipmentID: "equipment-1"), listMutation)
        XCTAssertEqual(memberRemoved.equipmentList.identity, "list-1")
    }

    func testManagingProtocolExposesTypedCreationAdoptionAndCopy() async throws {
        let mutation = "{\"item\":\(itemJSON),\"summary\":\(summaryJSON)}"
        let copyResult = "{\"equipmentList\":\(listJSON),\"personalEquipmentSummary\":\(summaryJSON)}"
        let spy = PersonalEquipmentRequestSpy(responses: [mutation, mutation, copyResult])
        let service: any PersonalEquipmentManaging = EquipmentService(apiClient: spy)
        _ = try await service.createPersonalEquipment(input: .init(name: "睡袋", ownedQuantity: 2, unitWeight: .init(grams: 12.5)))
        _ = try await service.createPersonalEquipmentFromCatalog(input: .init(catalogEquipmentId: "c", ownedQuantity: 2, unitWeight: .clear), idempotencyKey: "adopt-key")
        _ = try await service.copyEquipmentList(id: "l", name: "副本", idempotencyKey: "copy-key")
        XCTAssertEqual(spy.identifiers, ["POST /personal-equipment", "POST /personal-equipment:from-catalog", "POST /equipment-lists/l:copy"])
        XCTAssertEqual((try object(spy.bodies[0])["unitWeight"] as? [String: Double])?["grams"], 12.5)
        XCTAssertTrue(try object(spy.bodies[1])["unitWeight"] is NSNull)
        XCTAssertEqual(spy.headers[1], ["Idempotency-Key": "adopt-key"])
        XCTAssertEqual(spy.headers[2], ["Idempotency-Key": "copy-key"])
    }

    private let itemJSON = #"{"identity":"equipment-1","name":"睡袋","ownedQuantity":2,"unitWeight":{"grams":12.5},"category":"sleeping","equipmentType":"sleeping_bag","variant":"M","unitLabel":"件","weightScope":"含袋","unitWeightSource":"catalog_reference","catalogEquipmentId":"catalog-1"}"#
    private let summaryJSON = #"{"equipmentItemCount":5,"equipmentListCount":2,"knownTotalWeight":{"grams":142.5},"missingWeightItemCount":1}"#
    private var memberJSON: String { String(itemJSON.dropLast()) + ",\"quantity\":3}" }
    private var listJSON: String { "{\"identity\":\"list-1\",\"name\":\"清单\",\"members\":[\(memberJSON)],\"summary\":{\"itemCount\":1,\"knownTotalWeight\":{\"grams\":37.5},\"missingWeightItemCount\":0}}" }

    private func contract<Request: APIRequest>(_ request: Request, file: StaticString = #filePath, line: UInt = #line) -> String {
        XCTAssertEqual(request.responseEnvelope, .data, file: file, line: line)
        XCTAssertEqual(request.authenticationPolicy, .required, file: file, line: line)
        XCTAssertTrue(request.pathIsPercentEncoded, file: file, line: line)
        XCTAssertNil(request.offlineEligibility, file: file, line: line)
        XCTAssertFalse(request.query.contains { ["accountId", "ownerId", "userId"].contains($0.name) }, file: file, line: line)
        return request.identifier
    }

    private func object(_ body: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(body)) as? [String: Any])
    }

    private func envelope(_ json: String) -> Data { Data("{\"data\":\(json)}".utf8) }

    private func execute<Request: APIRequest>(_ request: Request, _ json: String) async throws -> Request.Response {
        try await MockAPIClient(fixtures: [request.identifier: envelope(json)]).execute(request)
    }
}

private final class PersonalEquipmentRequestSpy: APIClient {
    private var responses: [String]
    var identifiers: [String] = []
    var bodies: [Data?] = []
    var headers: [[String: String]] = []

    init(responses: [String]) { self.responses = responses }

    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        identifiers.append(request.identifier)
        bodies.append(request.body)
        headers.append(request.headers)
        let json = responses.removeFirst()
        return try APIJSONDecoder.decode(Request.Response.self, from: Data("{\"data\":\(json)}".utf8), envelope: request.responseEnvelope)
    }
}
