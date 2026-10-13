import XCTest
import WalkData
@testable import Walk

@MainActor
final class TripEquipmentSelectionTests: XCTestCase {
    func testDraftAcceptsFiniteFractionalGrams() {
        var draft = TripEquipmentState.Draft()
        draft.name = "修补贴"
        draft.unitWeight = "12.5"
        XCTAssertNil(draft.unitWeightError)
        XCTAssertTrue(draft.isValid)
    }

    func testSupplyOwnershipIsDisplayedAsNotApplicable() {
        let item = TripEquipmentItem(identity: "water", name: "饮水", quantity: 1, unitWeight: nil, note: nil, source: .userAdded, ownershipStatus: .unconfirmedOwned, ownershipCheckApplicable: false)
        XCTAssertEqual(equipmentItemProjection(item, editable: false).ownershipStatus.label, "不适用")
    }
}

extension TripEquipmentSelectionTests {
    func testDraftRejectsNonFiniteAndNonPositiveWeightButAllowsUnknown() {
        var draft = TripEquipmentState.Draft()
        draft.name = "物品"
        for text in ["nan", "inf", "-inf", "Infinity", "0", "-1", "1e999", "abc"] {
            draft.unitWeight = text
            XCTAssertNotNil(draft.unitWeightError, text)
            XCTAssertFalse(draft.isValid, text)
        }
        draft.unitWeight = "  "
        XCTAssertNil(draft.unitWeightError)
        XCTAssertTrue(draft.isValid)
    }

    func testPersonalSelectionUsesCurrentRevisionAndRequestedQuantity() async throws {
        let client = TripSelectionAPIClient()
        client.writeProjection = Self.snapshot(revision: "revision-2")
        let sut = model(client)
        await sut.load()
        await sut.beginSelectingSource(.equipment)
        XCTAssertEqual(sut.sourcePickerProjection?.candidates.map(\.identity), ["bag", "water"])
        XCTAssertNil(sut.state.selectedSourceID)
        XCTAssertFalse(try XCTUnwrap(sut.sourcePickerProjection).canSubmit)
        sut.selectSourceCandidate("bag")
        sut.updateSourceQuantity(2)
        let result = await sut.confirmSourceSelection()
        XCTAssertTrue(result)
        XCTAssertEqual(sut.projection?.revision, "revision-2")
        XCTAssertNil(sut.state.sourceMode)
        XCTAssertNil(sut.state.pendingSourceCommand)
        let request = try XCTUnwrap(client.writes.last)
        XCTAssertEqual(request.path, "/trips/trip-1/equipment/items:from-personal")
        XCTAssertEqual(request.headers, ["If-Match": "\"revision-1\"", "Idempotency-Key": "operation-key"])
        let body = try object(request.body)
        XCTAssertEqual(body["personalEquipmentId"] as? String, "bag")
        XCTAssertEqual(body["quantity"] as? Int, 2)
        XCTAssertEqual(Set(body.keys), ["personalEquipmentId", "quantity"])
    }

    func testSupplyCandidateCannotBeSelectedAsOrdinaryEquipment() async throws {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        await sut.beginSelectingSource(.equipment)
        let candidate = try XCTUnwrap(sut.sourcePickerProjection?.candidates.last)
        XCTAssertEqual(candidate.identity, "water")
        XCTAssertNotNil(candidate.unavailableReason)
        sut.selectSourceCandidate("water")
        XCTAssertNil(sut.state.selectedSourceID)
        let result = await sut.confirmSourceSelection()
        XCTAssertFalse(result)
        XCTAssertTrue(client.writes.isEmpty)
    }

    func testEmptyListCanBeAppendedAndOnlyItsIdentityIsSubmitted() async throws {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        await sut.beginSelectingSource(.list)
        sut.selectSourceCandidate("empty-list")
        let result = await sut.confirmSourceSelection()
        XCTAssertTrue(result)
        let request = try XCTUnwrap(client.writes.last)
        XCTAssertEqual(request.path, "/trips/trip-1/equipment:append-list")
        XCTAssertEqual(try object(request.body) as NSDictionary, ["equipmentListId": "empty-list"] as NSDictionary)
        XCTAssertEqual(request.headers["If-Match"], "\"revision-1\"")
        XCTAssertEqual(request.headers["Idempotency-Key"], "operation-key")
    }

    func testUncertainSelectionRetryReusesFirstContentRevisionAndKey() async throws {
        let client = TripSelectionAPIClient()
        var keyCount = 0
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: TripEquipmentService(apiClient: client),
            equipmentService: EquipmentService(apiClient: client), makeIdempotencyKey: { keyCount += 1; return "key-\(keyCount)" })
        await sut.load()
        await sut.beginSelectingSource(.equipment)
        sut.selectSourceCandidate("bag")
        sut.updateSourceQuantity(2)
        client.writeError = APIClientError.transport(.connectionLost)
        let failed = await sut.confirmSourceSelection()
        XCTAssertFalse(failed)
        XCTAssertNotNil(sut.state.pendingSourceCommand)
        XCTAssertTrue(try XCTUnwrap(sut.sourcePickerProjection).inputsLocked)
        sut.updateSourceQuantity(7)
        sut.selectSourceCandidate("water")
        sut.cancelSourceSelection()
        await sut.beginSelectingSource(.list)
        client.projection = Self.snapshot(revision: "unseen-later-revision")
        await sut.load()
        await sut.handleAppearance()
        XCTAssertEqual(sut.projection?.revision, "revision-1")
        XCTAssertEqual(sut.state.sourceMode, .equipment)
        XCTAssertEqual(sut.state.sourceQuantity, 2)
        client.writeError = nil
        client.writeProjection = Self.snapshot(revision: "first-command-result")
        let success = await sut.confirmSourceSelection()
        XCTAssertTrue(success)
        XCTAssertEqual(keyCount, 1)
        XCTAssertEqual(client.writes.count, 2)
        XCTAssertEqual(client.writes[0].headers, client.writes[1].headers)
        XCTAssertEqual(try object(client.writes[0].body) as NSDictionary, try object(client.writes[1].body) as NSDictionary)
        XCTAssertEqual(sut.projection?.revision, "first-command-result")
        XCTAssertNil(sut.state.pendingSourceCommand)
    }

    func testAppendUncertainRetryAlsoKeepsOriginalCommand() async throws {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        await sut.beginSelectingSource(.list)
        sut.selectSourceCandidate("empty-list")
        client.writeError = APIClientError.invalidResponse
        _ = await sut.confirmSourceSelection()
        let pending = try XCTUnwrap(sut.state.pendingSourceCommand)
        XCTAssertEqual(pending.mode, .list)
        client.writeError = nil
        await sut.retrySource()
        XCTAssertEqual(client.writes.count, 2)
        XCTAssertEqual(client.writes[0].headers, client.writes[1].headers)
        XCTAssertNil(sut.state.pendingSourceCommand)
    }

    func testStructuredInternalErrorKeepsOriginalCommandForRetry() async throws {
        try await assertUncertainErrorKeepsCommand(.api(code: "internal_error", message: "服务内部错误", retryable: false), mode: .equipment)
    }

    func testUnknownErrorCodeKeepsOriginalCommandForRetry() async throws {
        try await assertUncertainErrorKeepsCommand(.api(code: "unrecognized_failure", message: "请求未完成", retryable: false), mode: .list)
    }

    func testRequestTimeoutKeepsOriginalCommandForRetry() async throws {
        try await assertUncertainErrorKeepsCommand(.http(statusCode: 408), mode: .equipment)
    }

    func testUnavailableErrorWithoutRetryHintKeepsOriginalCommandForRetry() async throws {
        try await assertUncertainErrorKeepsCommand(.api(code: "trip_equipment_unavailable", message: "本次装备暂不可用", retryable: false), mode: .list)
    }

    func testDefiniteRejectionCodesReleasePendingButKeepSelection() async {
        for code in ["invalid_request", "authentication_required", "resource_not_found", "concurrent_modification",
                     "idempotency_conflict", "equipment_name_conflict", "trip_equipment_read_only",
                     "relationship_inconsistent", "validation_failed"] {
            let client = TripSelectionAPIClient()
            let sut = model(client)
            await sut.load()
            await sut.beginSelectingSource(.equipment)
            sut.selectSourceCandidate("bag")
            sut.updateSourceQuantity(2)
            client.writeError = APIClientError.api(code: code, message: "明确拒绝", retryable: false)
            let succeeded = await sut.confirmSourceSelection()
            XCTAssertFalse(succeeded, code)
            XCTAssertNil(sut.state.pendingSourceCommand, code)
            XCTAssertEqual(sut.state.selectedSourceID, "bag", code)
            XCTAssertEqual(sut.state.sourceQuantity, 2, code)
        }
    }

    func testConcurrentConflictRequiresExplicitReloadAndKeepsSourceDraft() async throws {
        let client = TripSelectionAPIClient()
        var keyCount = 0
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: TripEquipmentService(apiClient: client),
            equipmentService: EquipmentService(apiClient: client), makeIdempotencyKey: { keyCount += 1; return "key-\(keyCount)" })
        await sut.load()
        await sut.beginSelectingSource(.equipment)
        sut.selectSourceCandidate("bag")
        sut.updateSourceQuantity(2)
        client.writeError = APIClientError.api(code: "concurrent_modification", message: "版本过期", retryable: false)
        let first = await sut.confirmSourceSelection()
        XCTAssertFalse(first)
        XCTAssertTrue(sut.state.requiresReload)
        XCTAssertTrue(sut.state.offersReload)
        XCTAssertNil(sut.state.pendingSourceCommand)
        XCTAssertEqual(sut.state.selectedSourceID, "bag")
        XCTAssertEqual(sut.state.sourceQuantity, 2)
        let rejected = await sut.confirmSourceSelection()
        XCTAssertFalse(rejected)
        XCTAssertEqual(client.writes.count, 1)
        client.projection = Self.snapshot(revision: "revision-2")
        client.writeProjection = Self.snapshot(revision: "revision-3")
        client.writeError = nil
        await sut.reloadAfterConflict()
        XCTAssertFalse(sut.state.requiresReload)
        XCTAssertEqual(client.writes.count, 1, "重载不自动重新提交")
        XCTAssertEqual(sut.state.selectedSourceID, "bag")
        let second = await sut.confirmSourceSelection()
        XCTAssertTrue(second)
        XCTAssertEqual(client.writes.last?.headers["If-Match"], "\"revision-2\"")
        XCTAssertEqual(client.writes.last?.headers["Idempotency-Key"], "key-2")
    }

    func testRejectedListPreservesSnapshotAndDoesNotSkipMembers() async {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        let initial = sut.projection
        await sut.beginSelectingSource(.list)
        sut.selectSourceCandidate("empty-list")
        client.writeError = APIClientError.api(code: "validation_failed", message: "请填写本次实际补给量", retryable: false)
        let result = await sut.confirmSourceSelection()
        XCTAssertFalse(result)
        XCTAssertEqual(sut.projection, initial)
        XCTAssertEqual(sut.state.selectedSourceID, "empty-list")
        XCTAssertNil(sut.state.pendingSourceCommand)
        XCTAssertEqual(sut.errorMessage, "请填写本次实际补给量")
        XCTAssertEqual(client.writes.count, 1)
    }

    func testDuplicateNameKeepsSelectionAndOffersReloadWithoutMerging() async {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        let initial = sut.projection
        await sut.beginSelectingSource(.equipment)
        sut.selectSourceCandidate("bag")
        client.writeError = APIClientError.api(code: "equipment_name_conflict", message: "重名", retryable: false)
        let result = await sut.confirmSourceSelection()
        XCTAssertFalse(result)
        XCTAssertEqual(sut.projection, initial)
        XCTAssertEqual(sut.state.selectedSourceID, "bag")
        XCTAssertTrue(sut.state.offersReload)
        XCTAssertNil(sut.state.pendingSourceCommand)
        XCTAssertEqual(client.writes.count, 1)
    }

    func testFractionalEditorUsesTypedCreateAndEveryWriteHasCurrentRevision() async throws {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        sut.beginAdding()
        sut.updateName("修补贴")
        sut.updateUnitWeight("12.5")
        client.writeProjection = Self.snapshot(revision: "revision-2")
        let saved = await sut.saveEditor()
        XCTAssertTrue(saved)
        let create = try XCTUnwrap(client.writes.last)
        XCTAssertEqual((try object(create.body)["unitWeight"] as? [String: Double])?["grams"], 12.5)
        XCTAssertEqual(create.headers["If-Match"], "\"revision-1\"")
        _ = await sut.recheckOwnership()
        _ = await sut.deleteItem(itemID: "item-1")
        XCTAssertTrue(client.writes.dropFirst().allSatisfy { $0.headers["If-Match"] == "\"revision-2\"" })
    }

    func testQuantityEditDoesNotClearCarryAllocationAndValidationKeepsDraft() async throws {
        let client = TripSelectionAPIClient()
        client.projection = Self.snapshot(revision: "revision-1", carry: .init(backpackQuantity: 1, wornQuantity: 1, handheldQuantity: 0))
        let sut = model(client)
        await sut.load()
        sut.beginEditing(try XCTUnwrap(sut.projection?.snapshot.items.first))
        sut.updateQuantity(1)
        sut.updateUnitWeight("25.5")
        client.writeError = APIClientError.api(code: "validation_failed", message: "数量与携带分配不一致", retryable: false)
        let saved = await sut.saveEditor()
        XCTAssertFalse(saved)
        XCTAssertNotNil(sut.state.editor)
        XCTAssertEqual(sut.state.draft.quantity, 1)
        XCTAssertEqual(sut.state.draft.unitWeight, "25.5")
        let body = try object(XCTUnwrap(client.writes.last).body)
        XCTAssertNil(body["carryAllocation"])
        XCTAssertNil(body["category"])
        XCTAssertNil(body["supply"])
        XCTAssertEqual((body["unitWeight"] as? [String: Double])?["grams"], 25.5)
        XCTAssertEqual(sut.projection?.snapshot.items.first?.carryAllocation?.wornQuantity, 1)
    }

    func testEditorConflictReloadKeepsDraftAndWaitsForExplicitSave() async throws {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        sut.beginEditing(try XCTUnwrap(sut.projection?.snapshot.items.first))
        sut.updateName("保留这份草稿")
        sut.updateUnitWeight("35.5")
        client.writeError = APIClientError.api(code: "concurrent_modification", message: "版本过期", retryable: false)
        _ = await sut.saveEditor()
        client.projection = Self.snapshot(revision: "revision-2")
        await sut.reloadAfterConflict()
        XCTAssertEqual(sut.state.draft.name, "保留这份草稿")
        XCTAssertEqual(sut.state.draft.unitWeight, "35.5")
        XCTAssertNotNil(sut.state.editor)
        XCTAssertEqual(client.writes.count, 1)
    }

    func testNameEditDoesNotResubmitUnchangedWeightQuantityOrNote() async throws {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        sut.beginEditing(try XCTUnwrap(sut.projection?.snapshot.items.first))
        sut.updateName("仅修改名称")
        let saved = await sut.saveEditor()
        XCTAssertTrue(saved)
        let body = try object(XCTUnwrap(client.writes.last).body)
        XCTAssertEqual(Set(body.keys), ["name"])
        XCTAssertEqual(body["name"] as? String, "仅修改名称")
    }

    func testUnchangedEditorClosesWithoutSendingEmptyPatch() async throws {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        sut.beginEditing(try XCTUnwrap(sut.projection?.snapshot.items.first))
        let saved = await sut.saveEditor()
        XCTAssertTrue(saved)
        XCTAssertNil(sut.state.editor)
        XCTAssertTrue(client.writes.isEmpty)
    }

    func testReloadToReadonlyKeepsDraftButPreventsSave() async throws {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        sut.beginEditing(try XCTUnwrap(sut.projection?.snapshot.items.first))
        sut.updateName("尚未提交的名称")
        client.projection = Self.snapshot(revision: "completed-revision", editable: false)
        await sut.reloadAfterConflict()
        XCTAssertEqual(sut.state.draft.name, "尚未提交的名称")
        XCTAssertNotNil(sut.state.editor)
        let saved = await sut.saveEditor()
        XCTAssertFalse(saved)
        XCTAssertTrue(client.writes.isEmpty)
    }

    func testOrdinaryAppearanceRefreshesCachedSnapshot() async {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.handleAppearance()
        client.projection = Self.snapshot(revision: "latest-revision")
        await sut.handleAppearance()
        XCTAssertEqual(sut.projection?.revision, "latest-revision")
        XCTAssertTrue(client.writes.isEmpty)
    }

    func testReturningToUnsubmittedPickerReloadsCandidatesWithoutLosingQuantity() async throws {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        await sut.beginSelectingSource(.equipment)
        sut.selectSourceCandidate("bag")
        sut.updateSourceQuantity(2)
        client.personalHandler = {
            .init(items: [], summary: .init(equipmentItemCount: 0, equipmentListCount: 1,
                knownTotalWeight: .init(grams: 0), missingWeightItemCount: 0))
        }
        await sut.handleAppearance()
        XCTAssertTrue(try XCTUnwrap(sut.sourcePickerProjection).candidates.isEmpty)
        XCTAssertEqual(sut.state.selectedSourceID, "bag")
        XCTAssertEqual(sut.state.sourceQuantity, 2)
        XCTAssertFalse(try XCTUnwrap(sut.sourcePickerProjection).canSubmit)
        XCTAssertTrue(client.writes.isEmpty)
    }

    func testReadOnlyAndInFlightSourceCommandsDoNotStartExtraMutations() async {
        let client = TripSelectionAPIClient()
        client.projection = Self.snapshot(revision: "r1", editable: false)
        let sut = model(client)
        await sut.load()
        await sut.beginSelectingSource(.equipment)
        XCTAssertNil(sut.state.sourceMode)
        let readonly = await sut.confirmSourceSelection()
        XCTAssertFalse(readonly)
        client.projection = Self.snapshot(revision: "r2")
        await sut.load()
        await sut.beginSelectingSource(.equipment)
        sut.selectSourceCandidate("bag")
        let started = expectation(description: "source write started")
        var continuation: CheckedContinuation<TripEquipmentProjection, Never>?
        client.writeHandler = { _ in
            await withCheckedContinuation { continuation = $0; started.fulfill() }
        }
        let task = Task { await sut.confirmSourceSelection() }
        await fulfillment(of: [started], timeout: 1)
        let duplicate = await sut.confirmSourceSelection()
        XCTAssertFalse(duplicate)
        XCTAssertEqual(client.writes.count, 1)
        continuation?.resume(returning: Self.snapshot(revision: "r3"))
        let success = await task.value
        XCTAssertTrue(success)
    }

    func testCancelledCandidateLoadCannotFillClosedPicker() async {
        let client = TripSelectionAPIClient()
        let sut = model(client)
        await sut.load()
        let started = expectation(description: "candidate load started")
        var continuation: CheckedContinuation<PersonalEquipmentCollection, Never>?
        client.personalHandler = {
            await withCheckedContinuation { continuation = $0; started.fulfill() }
        }
        let task = Task { await sut.beginSelectingSource(.equipment) }
        await fulfillment(of: [started], timeout: 1)
        sut.cancelSourceSelection()
        continuation?.resume(returning: client.personal)
        await task.value
        XCTAssertNil(sut.state.sourceMode)
        XCTAssertTrue(sut.state.personalCandidates.isEmpty)
        XCTAssertFalse(sut.state.isSourceLoading)
    }

    private func assertUncertainErrorKeepsCommand(_ error: APIClientError, mode: TripEquipmentSourceMode,
                                                 file: StaticString = #filePath, line: UInt = #line) async throws {
        let client = TripSelectionAPIClient()
        var keyCount = 0
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: TripEquipmentService(apiClient: client),
            equipmentService: EquipmentService(apiClient: client), makeIdempotencyKey: { keyCount += 1; return "key-\(keyCount)" })
        await sut.load()
        await sut.beginSelectingSource(mode)
        sut.selectSourceCandidate(mode == .equipment ? "bag" : "empty-list")
        if mode == .equipment { sut.updateSourceQuantity(2) }
        client.writeError = error
        let succeeded = await sut.confirmSourceSelection()
        XCTAssertFalse(succeeded, file: file, line: line)
        XCTAssertNotNil(sut.state.pendingSourceCommand, file: file, line: line)
        XCTAssertTrue(try XCTUnwrap(sut.sourcePickerProjection).inputsLocked, file: file, line: line)
        let firstRequest = try XCTUnwrap(client.writes.first)
        client.writeError = nil
        let recovered = await sut.confirmSourceSelection()
        XCTAssertTrue(recovered, file: file, line: line)
        XCTAssertEqual(keyCount, 1, file: file, line: line)
        XCTAssertEqual(client.writes.count, 2, file: file, line: line)
        XCTAssertEqual(firstRequest.headers, client.writes.last?.headers, file: file, line: line)
        XCTAssertEqual(try object(firstRequest.body) as NSDictionary,
                       try object(XCTUnwrap(client.writes.last).body) as NSDictionary, file: file, line: line)
    }

    private func model(_ client: TripSelectionAPIClient) -> TripEquipmentViewModel {
        TripEquipmentViewModel(tripID: "trip-1", service: TripEquipmentService(apiClient: client),
                               equipmentService: EquipmentService(apiClient: client), makeIdempotencyKey: { "operation-key" })
    }

    private func object(_ data: Data?) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(data)) as? [String: Any])
    }

    fileprivate static func snapshot(revision: String, carry: TripCarryAllocation? = nil, editable: Bool = true) -> TripEquipmentProjection {
        let item = TripEquipmentItem(identity: "item-1", name: "帐篷", quantity: 2, unitWeight: .init(grams: 500.25), note: nil, source: .userAdded, ownershipStatus: .owned, carryAllocation: carry)
        return .init(trip: .init(identity: "trip-1", status: editable ? .planned : .completed,
                                routeName: "路线", startDate: .init(year: 2026, month: 10, day: 1), endDate: .init(year: 2026, month: 10, day: 2)),
                     revision: revision, editable: editable,
                     snapshot: .init(identity: "snapshot-1", items: [item],
                                     summary: .init(itemCount: 1, knownTotalWeight: .init(grams: 1000.5), missingWeightItemCount: 0, ownedItemCount: 1, unconfirmedOwnedItemCount: 0)))
    }
}

@MainActor
private final class TripSelectionAPIClient: APIClient {
    struct Record {
        let path: String
        let body: Data?
        let headers: [String: String]
    }
    var projection = TripEquipmentSelectionTests.snapshot(revision: "revision-1")
    var writeProjection = TripEquipmentSelectionTests.snapshot(revision: "revision-1")
    var writeError: Error?
    var writeHandler: ((Record) async throws -> TripEquipmentProjection)?
    var personalHandler: (() async throws -> PersonalEquipmentCollection)?
    private(set) var writes: [Record] = []
    let personal = PersonalEquipmentCollection(items: [
        .init(identity: "bag", name: "背包", ownedQuantity: 1, unitWeight: .init(grams: 650.5), category: .backpack, equipmentType: .backpack),
        .init(identity: "water", name: "饮水参考", ownedQuantity: 1, unitWeight: nil, category: .drinkingWater, equipmentType: .drinkingWater)
    ], summary: .init(equipmentItemCount: 2, equipmentListCount: 1, knownTotalWeight: .init(grams: 650.5), missingWeightItemCount: 1))
    let lists = EquipmentListCollection(items: [
        .init(identity: "empty-list", name: "空清单", summary: .init(itemCount: 0, knownTotalWeight: .init(grams: 0), missingWeightItemCount: 0))
    ])

    func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        let data: Data
        if request.method == .get {
            switch request.path {
            case "/personal-equipment":
                let response = try await personalHandler?() ?? personal
                data = try JSONEncoder().encode(response)
            case "/equipment-lists": data = try JSONEncoder().encode(lists)
            default: data = try JSONEncoder().encode(projection)
            }
        } else {
            let record = Record(path: request.path, body: request.body, headers: request.headers)
            writes.append(record)
            if let writeError { throw writeError }
            let response = try await writeHandler?(record) ?? writeProjection
            data = try JSONEncoder().encode(response)
        }
        return try JSONDecoder().decode(Request.Response.self, from: data)
    }
}
