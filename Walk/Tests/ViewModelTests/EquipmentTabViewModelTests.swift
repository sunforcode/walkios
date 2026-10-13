import XCTest
import WalkData
@testable import Walk

@MainActor
final class EquipmentTabViewModelTests: XCTestCase {
    func testAddEquipmentRemainsAvailableDuringInitialLoad() {
        var state = EquipmentListState()
        state.isLoading = true

        XCTAssertTrue(state.showsPrimaryAction(isEquipmentSection: true))
        XCTAssertFalse(state.isMutating, "读取列表不应禁用新增装备")
        XCTAssertFalse(state.showsPrimaryAction(isEquipmentSection: false))
    }

    func testAddEquipmentRemainsAvailableAfterInitialLoadFailure() {
        var state = EquipmentListState()
        state.loadErrorMessage = "装备服务暂不可用"

        XCTAssertTrue(state.showsPrimaryAction(isEquipmentSection: true))
        XCTAssertFalse(state.isMutating, "读取失败不应禁用独立新增表单")
        XCTAssertFalse(state.showsPrimaryAction(isEquipmentSection: false))
    }

    func testEmptyLibraryKeepsBothCreationActionsAvailable() {
        let state = EquipmentListState()

        XCTAssertTrue(state.showsPrimaryAction(isEquipmentSection: true))
        XCTAssertTrue(state.showsPrimaryAction(isEquipmentSection: false))
    }

    func testClassificationOptionsCoverControlledVocabularyWithoutDefaults() {
        XCTAssertEqual(EquipmentClassificationOptions.categories, CatalogEquipmentCategory.allCases)
        XCTAssertEqual(EquipmentClassificationOptions.categories.count, 16)
        XCTAssertTrue(EquipmentClassificationOptions.types(for: nil).isEmpty)

        let allTypes = EquipmentClassificationOptions.categories.flatMap {
            EquipmentClassificationOptions.types(for: $0)
        }
        XCTAssertEqual(Set(allTypes), Set(CatalogEquipmentType.allCases))
        XCTAssertEqual(Set(allTypes).count, 63)
        for type in CatalogEquipmentType.allCases {
            let occurrences = allTypes.filter { $0 == type }.count
            XCTAssertEqual(occurrences, type == .storageBag ? 2 : 1, type.rawValue)
            XCTAssertFalse(EquipmentClassificationOptions.label(for: type).isEmpty)
        }
        XCTAssertEqual(EquipmentClassificationOptions.label(for: CatalogEquipmentCategory.sleeping), "睡眠系统")
        XCTAssertEqual(EquipmentClassificationOptions.label(for: CatalogEquipmentType.sleepingBag), "睡袋")
        XCTAssertEqual(EquipmentClassificationOptions.types(for: .backpack), [.backpack, .backpackRainCover])
        XCTAssertEqual(EquipmentClassificationOptions.types(for: .hikingFootwear), [.hikingShoes])
        XCTAssertTrue(EquipmentClassificationOptions.types(for: .walkingAids).contains(.riverCrossingShoes))
        XCTAssertTrue(EquipmentClassificationOptions.types(for: .campEssentials).contains(.campShoes))
        XCTAssertFalse(EquipmentClassificationOptions.types(for: .food).contains(.storageBag))
    }

    func testCreatePersistsExplicitCategoryAndTypeSelections() async throws {
        let client = EquipmentTabAPIClient()
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client))
        model.updateName("我的睡袋")
        model.updateCategory(.sleeping)
        model.updateEquipmentType(.sleepingBag)

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertEqual(client.lastBody?["category"] as? String, "sleeping")
        XCTAssertEqual(client.lastBody?["equipmentType"] as? String, "sleeping_bag")
        XCTAssertNil(client.lastBody?["unitWeight"])
    }

    func testUnknownClassificationRemainsMissingOnCreateAndLegacyLoad() async {
        let client = EquipmentTabAPIClient(weightSource: nil)
        let creator = EquipmentEditViewModel(service: EquipmentService(apiClient: client))
        creator.updateName("未分类装备")
        XCTAssertNil(creator.state.draft.category)
        XCTAssertNil(creator.state.draft.equipmentType)
        let saved = await creator.save()
        XCTAssertTrue(saved)
        XCTAssertNil(client.lastBody?["category"])
        XCTAssertNil(client.lastBody?["equipmentType"])

        let editor = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await editor.load()
        XCTAssertNil(editor.state.draft.category)
        XCTAssertNil(editor.state.draft.equipmentType)
        XCTAssertFalse(editor.state.isDirty)
    }

    func testCategoryOnlySelectionDoesNotInventAType() async {
        let client = EquipmentTabAPIClient()
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client))
        model.updateName("背包")
        model.updateCategory(.backpack)

        XCTAssertNil(model.state.draft.equipmentType)
        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertEqual(client.lastBody?["category"] as? String, "backpack")
        XCTAssertNil(client.lastBody?["equipmentType"])
    }

    func testChangingCategoryClearsIncompatibleTypeAndClearingCategoryClearsBoth() {
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: EquipmentTabAPIClient()))
        model.updateCategory(.backpack)
        model.updateEquipmentType(.backpack)
        model.updateCategory(.sleeping)
        XCTAssertEqual(model.state.draft.category, .sleeping)
        XCTAssertNil(model.state.draft.equipmentType)

        model.updateEquipmentType(.sleepingBag)
        model.updateCategory(nil)
        XCTAssertNil(model.state.draft.category)
        XCTAssertNil(model.state.draft.equipmentType)
    }

    func testStorageBagCanRetainTypeAcrossItsTwoAllowedCategories() {
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: EquipmentTabAPIClient()))
        model.updateCategory(.clothing)
        model.updateEquipmentType(.storageBag)
        model.updateCategory(.diningEquipment)
        XCTAssertEqual(model.state.draft.equipmentType, .storageBag)

        model.updateCategory(.food)
        XCTAssertNil(model.state.draft.equipmentType)
    }

    func testInvalidTypeSelectionCannotCreateAnIllegalCombination() {
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: EquipmentTabAPIClient()))
        model.updateEquipmentType(.sleepingBag)
        XCTAssertNil(model.state.draft.equipmentType)
        model.updateCategory(.backpack)
        model.updateEquipmentType(.sleepingBag)
        XCTAssertNil(model.state.draft.equipmentType)
        model.updateEquipmentType(.backpack)
        model.updateEquipmentType(.campShoes)
        XCTAssertEqual(model.state.draft.equipmentType, .backpack)

        var malformed = EquipmentEditState(mode: .create)
        malformed.draft.name = "非法组合"
        malformed.draft.equipmentType = .sleepingBag
        XCTAssertFalse(malformed.isInputValid)
        malformed.draft.category = .backpack
        XCTAssertFalse(malformed.isInputValid)
    }

    func testEditingRestoresSelectionsAndRenamingDoesNotResubmitClassification() async {
        let client = EquipmentTabAPIClient(category: .sleeping, equipmentType: .sleepingBag)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        XCTAssertEqual(model.state.draft.category, .sleeping)
        XCTAssertEqual(model.state.draft.equipmentType, .sleepingBag)
        model.updateName("我的冬季睡袋")

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertNil(client.lastBody?["category"])
        XCTAssertNil(client.lastBody?["equipmentType"])
        XCTAssertNil(client.lastBody?["unitWeight"])
    }

    func testChangingOnlyTypePatchesOnlyTypeAndLeavesUserWeightUnchanged() async {
        let client = EquipmentTabAPIClient(category: .sleeping, equipmentType: .sleepingBag, weightSource: .userRecorded)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateEquipmentType(.sleepingQuilt)

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertNil(client.lastBody?["category"])
        XCTAssertEqual(client.lastBody?["equipmentType"] as? String, "sleeping_quilt")
        XCTAssertNil(client.lastBody?["unitWeight"])
    }

    func testChangingCategoryPatchesNewCategoryAndClearsOldType() async {
        let client = EquipmentTabAPIClient(category: .backpack, equipmentType: .backpack, weightSource: nil)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateCategory(.sleeping)

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertEqual(client.lastBody?["category"] as? String, "sleeping")
        XCTAssertTrue(client.lastBody?["equipmentType"] is NSNull)
        XCTAssertNil(client.lastBody?["unitWeight"])
    }

    func testClearingClassificationPatchesExplicitNullForBothFields() async {
        let client = EquipmentTabAPIClient(category: .sleeping, equipmentType: .sleepingBag, weightSource: .userRecorded)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateCategory(nil)

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertTrue(client.lastBody?["category"] is NSNull)
        XCTAssertTrue(client.lastBody?["equipmentType"] is NSNull)
    }

    func testClearingOnlyTypeRetainsCategoryAndPatchesOnlyType() async {
        let client = EquipmentTabAPIClient(category: .sleeping, equipmentType: .sleepingBag, weightSource: .userRecorded)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateEquipmentType(nil)

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertNil(client.lastBody?["category"])
        XCTAssertTrue(client.lastBody?["equipmentType"] is NSNull)
        XCTAssertNil(client.lastBody?["unitWeight"])
    }

    func testSaveFailureRetainsClassificationDraftAndWeightConfirmation() async {
        let client = EquipmentTabAPIClient(category: .sleeping, equipmentType: .sleepingBag)
        client.mutationError = APIClientError.api(
            code: "personal_equipment_unavailable", message: "暂时无法保存", retryable: true
        )
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateEquipmentType(.sleepingQuilt)
        model.updateWeight("12.5")

        let saved = await model.save()

        XCTAssertFalse(saved)
        XCTAssertEqual(model.state.draft.category, .sleeping)
        XCTAssertEqual(model.state.draft.equipmentType, .sleepingQuilt)
        XCTAssertEqual(model.state.draft.unitWeightGrams, "12.5")
        XCTAssertEqual(model.state.saveErrorMessage, "暂时无法保存")
        XCTAssertTrue(model.state.isDirty)
        XCTAssertTrue(model.state.isInputValid, "可使用相同选择和明确重量重试")
    }

    func testReferenceWeightRequiresConfirmationAfterTheLastClassificationChange() async {
        let client = EquipmentTabAPIClient(category: .sleeping, equipmentType: .sleepingBag)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateWeight("12.5")
        model.updateCategory(.backpack)
        XCTAssertFalse(model.state.isInputValid, "配置变化之前触碰重量不算确认")
        XCTAssertEqual(model.state.weightFieldError, "更改分类或类型后，请重新输入或清空参考重量")
        let savedWithoutConfirmation = await model.save()
        XCTAssertFalse(savedWithoutConfirmation)
        XCTAssertNil(client.lastBody)

        model.updateWeight("12.5")
        XCTAssertTrue(model.state.isInputValid)
        model.updateEquipmentType(.backpack)
        XCTAssertFalse(model.state.isInputValid, "后来再次修改类型应重新要求确认")
        model.updateWeight("12.5")
        XCTAssertTrue(model.state.isInputValid)
        XCTAssertNil(model.state.weightFieldError)
        let saved = await model.save()
        XCTAssertTrue(saved)
        XCTAssertEqual((client.lastBody?["unitWeight"] as? [String: Double])?["grams"], 12.5)
    }

    func testReferenceWeightCanBeClearedWhenClassificationChanges() async {
        let client = EquipmentTabAPIClient(category: .sleeping, equipmentType: .sleepingBag)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateCategory(nil)
        model.updateWeight("")

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertTrue(client.lastBody?["unitWeight"] is NSNull)
        XCTAssertTrue(client.lastBody?["category"] is NSNull)
        XCTAssertTrue(client.lastBody?["equipmentType"] is NSNull)
    }

    func testRestoringOriginalClassificationDoesNotRequireReferenceWeightConfirmation() async {
        let client = EquipmentTabAPIClient(category: .sleeping, equipmentType: .sleepingBag)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateEquipmentType(.sleepingQuilt)
        XCTAssertFalse(model.state.isInputValid)
        model.updateEquipmentType(.sleepingBag)

        XCTAssertTrue(model.state.isInputValid)
        XCTAssertNil(model.state.weightFieldError)
        XCTAssertFalse(model.state.isDirty)
    }

    func testRepeatedIdenticalSelectionDoesNotInvalidateWeightConfirmation() async {
        let client = EquipmentTabAPIClient(category: .sleeping, equipmentType: .sleepingBag)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateEquipmentType(.sleepingQuilt)
        model.updateWeight("12.5")
        model.updateCategory(.sleeping)
        model.updateEquipmentType(.sleepingQuilt)

        XCTAssertTrue(model.state.isInputValid)
    }

    func testClassificationChangeParticipatesInDiscardConfirmationAndRestoresInitialDraft() async {
        let client = EquipmentTabAPIClient(category: .sleeping, equipmentType: .sleepingBag)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateCategory(.backpack)
        XCTAssertTrue(model.state.isDirty)
        XCTAssertFalse(model.requestDismissal())
        XCTAssertEqual(model.state.confirmation, .discard)
        model.cancelConfirmation()
        XCTAssertEqual(model.state.draft.category, .backpack)
        XCTAssertTrue(model.state.isDirty)

        model.discardChanges()
        XCTAssertEqual(model.state.draft.category, .sleeping)
        XCTAssertEqual(model.state.draft.equipmentType, .sleepingBag)
        XCTAssertFalse(model.state.isDirty)
        XCTAssertTrue(model.state.isInputValid)
        XCTAssertTrue(model.requestDismissal())
    }

    func testCreateSendsFiniteFractionalWeightWithoutTruncation() async throws {
        let client = EquipmentTabAPIClient()
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client))
        model.updateName("修补贴")
        model.updateQuantity("2")
        model.updateWeight("12.5")

        XCTAssertTrue(model.state.isInputValid)
        let saved = await model.save()

        XCTAssertTrue(saved)
        let body = try XCTUnwrap(client.lastBody)
        XCTAssertEqual((body["unitWeight"] as? [String: Double])?["grams"], 12.5)
        XCTAssertEqual(body["ownedQuantity"] as? Int, 2)
    }

    func testInvalidWeightsNeverEnableSave() {
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: EquipmentTabAPIClient()))
        model.updateName("修补贴")
        for input in ["0", "-1", "NaN", "Infinity", "1e400", "不是数字"] {
            model.updateWeight(input)
            XCTAssertFalse(model.state.isInputValid, input)
        }
        model.updateWeight("")
        XCTAssertTrue(model.state.isInputValid)
        model.updateWeight("  12.5  ")
        XCTAssertTrue(model.state.isInputValid)
    }

    func testChangingFractionalWeightSendsTheExactNewValue() async throws {
        let client = EquipmentTabAPIClient()
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateWeight("13.75")

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertEqual((client.lastBody?["unitWeight"] as? [String: Double])?["grams"], 13.75)
    }

    func testClearingKnownWeightRemainsAnExplicitNull() async throws {
        let client = EquipmentTabAPIClient()
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateWeight("")

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertTrue(client.lastBody?["unitWeight"] is NSNull)
    }

    func testRenamingCatalogEquipmentLeavesReferenceWeightUnchanged() async throws {
        let client = EquipmentTabAPIClient(grams: 12)
        let model = EquipmentEditViewModel(service: EquipmentService(apiClient: client), equipmentID: "equipment-1")
        await model.load()
        model.updateName("我的修补贴")

        let saved = await model.save()

        XCTAssertTrue(saved)
        XCTAssertEqual(client.lastBody?["name"] as? String, "我的修补贴")
        XCTAssertNil(client.lastBody?["unitWeight"])
    }
}

private final class EquipmentTabAPIClient: APIClient {
    var lastBody: [String: Any]?
    var mutationError: Error?
    private let grams: Double
    private let category: CatalogEquipmentCategory?
    private let equipmentType: CatalogEquipmentType?
    private let weightSource: EquipmentWeightSource?

    init(
        grams: Double = 12.5,
        category: CatalogEquipmentCategory? = nil,
        equipmentType: CatalogEquipmentType? = nil,
        weightSource: EquipmentWeightSource? = .catalogReference
    ) {
        self.grams = grams
        self.category = category
        self.equipmentType = equipmentType
        self.weightSource = weightSource
    }

    private var item: String {
        var fields: [String: Any] = [
            "identity": "equipment-1", "name": "修补贴", "ownedQuantity": 2,
            "unitWeight": ["grams": grams], "unitLabel": "件", "weightScope": "一份修补贴",
            "catalogEquipmentId": "catalog-1"
        ]
        fields["category"] = category?.rawValue
        fields["equipmentType"] = equipmentType?.rawValue
        fields["unitWeightSource"] = weightSource?.rawValue
        let data = try! JSONSerialization.data(withJSONObject: fields)
        return String(decoding: data, as: UTF8.self)
    }
    private var summary: String {
        "{\"equipmentItemCount\":1,\"equipmentListCount\":0,\"knownTotalWeight\":{\"grams\":\(grams * 2)},\"missingWeightItemCount\":0}"
    }

    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        if let body = request.body {
            lastBody = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        }
        if request.method != .get, let mutationError { throw mutationError }
        let payload = request.method == .get ? item : "{\"item\":\(item),\"summary\":\(summary)}"
        return try APIJSONDecoder.decode(Request.Response.self, from: Data("{\"data\":\(payload)}".utf8), envelope: request.responseEnvelope)
    }
}
