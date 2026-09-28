import Foundation
import XCTest
@testable import WalkData

final class EquipmentCatalogTests: XCTestCase {
    func testCatalogRequestsUseAuthenticatedDataEnvelopeWithoutOfflineStorage() throws {
        assertRead(EquipmentCatalogAPI.Brands(), path: "/equipment-catalog/brands")
        assertRead(try EquipmentCatalogAPI.Items(), path: "/equipment-catalog/items")
        assertRead(
            EquipmentCatalogAPI.Detail(equipmentID: "bag/A ?#%中文"),
            path: "/equipment-catalog/items/bag%2FA%20%3F%23%25%E4%B8%AD%E6%96%87"
        )
    }

    func testAllDocumentedFiltersArePreservedAsIndependentQueryItems() throws {
        let request = try EquipmentCatalogAPI.Items(
            keyword: "  TENT_50% & +  ", category: .sleeping,
            brandID: "Brand /?%", equipmentType: .sleepingBag,
            weightGrams: 12.5, minWeightGrams: 1.25, maxWeightGrams: 500.75,
            comfortTemperatureCelsius: 0, minComfortTemperatureCelsius: -12.5,
            maxComfortTemperatureCelsius: 2.25
        )
        XCTAssertEqual(Dictionary(uniqueKeysWithValues: request.query.map { ($0.name, $0.value!) }), [
            "keyword": "  TENT_50% & +  ", "category": "sleeping",
            "brandId": "Brand /?%", "equipmentType": "sleeping_bag",
            "weightGrams": "12.5", "minWeightGrams": "1.25", "maxWeightGrams": "500.75",
            "comfortTemperatureCelsius": "0.0", "minComfortTemperatureCelsius": "-12.5",
            "maxComfortTemperatureCelsius": "2.25"
        ])
        XCTAssertTrue(try EquipmentCatalogAPI.Items().query.isEmpty)
    }

    func testNonFiniteQueryNumbersAreRejectedBeforeTransport() {
        XCTAssertThrowsError(try EquipmentCatalogAPI.Items(weightGrams: .nan))
        XCTAssertThrowsError(try EquipmentCatalogAPI.Items(minWeightGrams: .infinity))
        XCTAssertThrowsError(try EquipmentCatalogAPI.Items(maxWeightGrams: -.infinity))
        XCTAssertThrowsError(try EquipmentCatalogAPI.Items(comfortTemperatureCelsius: .nan))
        XCTAssertThrowsError(try EquipmentCatalogAPI.Items(minComfortTemperatureCelsius: .infinity))
        XCTAssertThrowsError(try EquipmentCatalogAPI.Items(maxComfortTemperatureCelsius: -.infinity))
    }

    func testBrandCollectionDecodesOpaqueIdentity() throws {
        let result = try decode(EquipmentBrandCollection.self, #"{"items":[{"identity":"Brand/甲","name":"品牌"}]}"#)
        XCTAssertEqual(result.items.first?.identity, "Brand/甲")
        XCTAssertEqual(result.items.first?.name, "品牌")
        XCTAssertTrue(try decode(EquipmentBrandCollection.self, #"{"items":[]}"#).items.isEmpty)
    }

    func testSummaryPreservesMissingSpecificationsAndFractionalMeasurement() throws {
        let result = try decode(CatalogEquipmentCollection.self, #"{"items":[{"identity":"unknown","name":"背包","category":"backpack","equipmentType":"backpack"},{"identity":"pair","name":"徒步鞋","category":"hiking_footwear","equipmentType":"hiking_shoes","brand":{"identity":"b","name":"品牌"},"model":"M","specifications":{"unitLabel":"双","variant":"42","unitWeight":{"grams":12.5},"weightScope":"一双"}}]}"#)
        XCTAssertNil(result.items[0].specifications)
        XCTAssertNil(result.items[0].brand)
        XCTAssertNil(result.items[0].model)
        XCTAssertEqual(result.items[1].specifications?.unitWeight?.grams, 12.5)
        XCTAssertEqual(result.items[1].specifications?.unitLabel, .pairOfShoes)
        XCTAssertEqual(result.items[1].specifications?.weightScope, "一双")
    }

    func testBackpackDetailUsesTypedCapacity() throws {
        let result = try detail(type: "backpack", category: "backpack", specifications: #"{"unitLabel":"只","capacityLiters":50.5}"#)
        guard case let .backpack(specifications)? = result.specifications else { return XCTFail("Expected backpack specifications") }
        XCTAssertEqual(specifications.capacityLiters, 50.5)
        XCTAssertNil(specifications.unitWeight)
    }

    func testTentDetailUsesIntegerPersonCapacity() throws {
        let result = try detail(type: "tent", category: "tent", specifications: #"{"unitLabel":"套","capacityPersons":2}"#)
        guard case let .tent(specifications)? = result.specifications else { return XCTFail("Expected tent specifications") }
        XCTAssertEqual(specifications.capacityPersons, 2)
        XCTAssertThrowsError(try detail(type: "tent", category: "tent", specifications: #"{"unitLabel":"套","capacityPersons":2.5}"#))
    }

    func testSleepingBagPreservesZeroNegativeAndIndependentUnknownTemperatures() throws {
        let result = try detail(type: "sleeping_bag", category: "sleeping", specifications: #"{"unitLabel":"件","comfortTemperatureCelsius":0,"limitTemperatureCelsius":-12.5}"#)
        guard case let .sleepingBag(specifications)? = result.specifications else { return XCTFail("Expected sleeping bag specifications") }
        XCTAssertEqual(specifications.comfortTemperatureCelsius, 0)
        XCTAssertEqual(specifications.limitTemperatureCelsius, -12.5)
        let unknown = try detail(type: "sleeping_bag", category: "sleeping", specifications: #"{"unitLabel":"件","comfortTemperatureCelsius":0}"#)
        guard case let .sleepingBag(unknownSpecifications)? = unknown.specifications else { return XCTFail("Expected sleeping bag specifications") }
        XCTAssertNil(unknownSpecifications.limitTemperatureCelsius)
    }

    func testSleepingPadDecodesItsOwnTypedFields() throws {
        let result = try detail(type: "sleeping_pad", category: "sleeping", specifications: #"{"unitLabel":"件","padType":"air","rValue":0,"lengthCm":183.5,"maxWidthCm":64,"thicknessCm":7.6}"#)
        guard case let .sleepingPad(specifications)? = result.specifications else { return XCTFail("Expected sleeping pad specifications") }
        XCTAssertEqual(specifications.padType, .air)
        XCTAssertEqual(specifications.rValue, 0)
        XCTAssertEqual(specifications.lengthCm, 183.5)
        XCTAssertEqual(specifications.maxWidthCm, 64)
        XCTAssertEqual(specifications.thicknessCm, 7.6)
        let unknown = try detail(type: "sleeping_pad", category: "sleeping", specifications: #"{"unitLabel":"件"}"#)
        guard case let .sleepingPad(unknownSpecifications)? = unknown.specifications else { return XCTFail("Expected sleeping pad specifications") }
        XCTAssertNil(unknownSpecifications.padType)
        XCTAssertNil(unknownSpecifications.rValue)
    }

    func testSimpleDetailUsesOnlyMeasurementProjection() throws {
        let result = try detail(type: "headlamp", category: "lighting_power", specifications: #"{"unitLabel":"只","unitWeight":{"grams":42.25},"weightScope":"含电池"}"#)
        guard case let .measurement(specifications)? = result.specifications else { return XCTFail("Expected simple measurement projection") }
        XCTAssertEqual(specifications.unitWeight?.grams, 42.25)
        XCTAssertEqual(specifications.weightScope, "含电池")
    }

    func testDetailKeepsMissingSpecificationsAbsent() throws {
        let result = try decode(CatalogEquipmentDetail.self, #"{"identity":"e","name":"背包","category":"backpack","equipmentType":"backpack"}"#)
        XCTAssertNil(result.specifications)
        XCTAssertNil(result.brand)
        XCTAssertNil(result.model)
    }

    func testAllRegisteredCodesAreStrictWithoutFallback() throws {
        XCTAssertEqual(CatalogEquipmentCategory.allCases.count, 16)
        XCTAssertEqual(CatalogEquipmentType.allCases.count, 63)
        XCTAssertEqual(Set(EquipmentUnitLabel.allCases.map(\.rawValue)), Set(["件", "只", "根", "对", "双", "套", "包", "瓶", "罐", "份"]))
        XCTAssertNil(CatalogEquipmentType(rawValue: "unknown"))
        XCTAssertNil(CatalogEquipmentCategory(rawValue: "BACKPACK"))
        XCTAssertNil(EquipmentUnitLabel(rawValue: "kg"))
        XCTAssertThrowsError(try detail(type: "unknown", category: "miscellaneous", specifications: #"{"unitLabel":"件"}"#))
        XCTAssertThrowsError(try detail(type: "headlamp", category: "unknown", specifications: #"{"unitLabel":"只"}"#))
        XCTAssertThrowsError(try detail(type: "sleeping_pad", category: "sleeping", specifications: #"{"unitLabel":"件","padType":"unknown"}"#))
    }

    func testCatalogServiceForwardsAllThreeTypedRequestsAndReturnsDecodedResults() async throws {
        let client = CatalogRecordingClient()
        let service: any EquipmentCatalogServicing = EquipmentCatalogService(apiClient: client)
        let brands = try await service.getBrands()
        let items = try await service.getEquipment(filter: EquipmentCatalogFilter(keyword: "tent_50%", category: .tent))
        let detail = try await service.getEquipment(id: "tent/A")
        XCTAssertEqual(brands.items.first?.identity, "brand")
        XCTAssertTrue(items.items.isEmpty)
        XCTAssertEqual(detail.identity, "tent/A")
        XCTAssertEqual(client.identifiers, [
            "GET /equipment-catalog/brands",
            "GET /equipment-catalog/items?category=tent&keyword=tent_50%",
            "GET /equipment-catalog/items/tent%2FA"
        ])
    }

    private func assertRead<Request: APIRequest>(_ request: Request, path: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(request.method, .get, file: file, line: line)
        XCTAssertEqual(request.path, path, file: file, line: line)
        XCTAssertTrue(request.pathIsPercentEncoded, file: file, line: line)
        XCTAssertEqual(request.responseEnvelope, .data, file: file, line: line)
        XCTAssertEqual(request.authenticationPolicy, .required, file: file, line: line)
        XCTAssertEqual(request.storagePolicy, .none, file: file, line: line)
        XCTAssertNil(request.offlineEligibility, file: file, line: line)
        XCTAssertNil(request.body, file: file, line: line)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, _ payload: String) throws -> Value {
        try APIJSONDecoder.decode(type, from: Data("{\"data\":\(payload)}".utf8), envelope: .data)
    }

    private func detail(type: String, category: String, specifications: String) throws -> CatalogEquipmentDetail {
        try decode(CatalogEquipmentDetail.self, "{\"identity\":\"equipment\",\"name\":\"装备\",\"category\":\"\(category)\",\"equipmentType\":\"\(type)\",\"specifications\":\(specifications)}")
    }
}

private final class CatalogRecordingClient: APIClient {
    var identifiers: [String] = []

    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        identifiers.append(request.identifier)
        let payload: String
        switch request.path {
        case "/equipment-catalog/brands":
            payload = #"{"data":{"items":[{"identity":"brand","name":"品牌"}]}}"#
        case "/equipment-catalog/items":
            payload = #"{"data":{"items":[]}}"#
        case "/equipment-catalog/items/tent%2FA":
            payload = #"{"data":{"identity":"tent/A","name":"帐篷","category":"tent","equipmentType":"tent"}}"#
        default:
            throw APIClientError.mockNotFound(request.identifier)
        }
        return try APIJSONDecoder.decode(Request.Response.self, from: Data(payload.utf8), envelope: request.responseEnvelope)
    }
}
