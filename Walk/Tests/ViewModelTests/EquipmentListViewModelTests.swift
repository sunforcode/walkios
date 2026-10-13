import XCTest
import WalkData
import WalkDesignSystem
@testable import Walk

@MainActor
final class EquipmentListViewModelTests: XCTestCase {
    func testInitialStateIsEmptyAndIdle() {
        let sut = EquipmentListViewModel(service: EquipmentServiceStub())

        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertTrue(sut.equipmentLists.isEmpty)
        XCTAssertNil(sut.summary)
        XCTAssertEqual(sut.state.editing, .none)
        XCTAssertFalse(sut.isMutating)
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
        let sut = EquipmentEditViewModel(service: service, equipmentID: "equipment-42")

        await sut.load()

        XCTAssertEqual(sut.state.loadedEquipment, item)
        XCTAssertEqual(sut.state.draft.name, "冰爪")
        XCTAssertEqual(sut.state.draft.quantityText, "2")
        XCTAssertEqual(sut.state.draft.unitWeightGrams, "410")
        XCTAssertFalse(sut.state.isDirty)
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

    func testCreateEquipmentPreservesReturnedMutationAndSummary() async {
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
        let sut = EquipmentEditViewModel(service: service)
        sut.updateName("帐篷")

        let saved = await sut.save()

        XCTAssertTrue(saved)
        XCTAssertEqual(sut.state.savedMutation?.item, created)
        XCTAssertEqual(sut.state.savedMutation?.summary.missingWeightItemCount, 1)
        XCTAssertFalse(sut.state.isDirty)
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
        let updated = await sut.putMember(equipmentListID: "list-1", personalEquipmentID: "equipment-1", quantity: 1)

        XCTAssertTrue(updated)
        XCTAssertEqual(sut.selectedEquipmentList, populatedDetail)
        XCTAssertEqual(sut.selectedEquipmentList?.members[0].quantity, 1)
    }

    func testListNameEditorsRemainActiveUntilSaveSucceeds() async {
        let service = EquipmentServiceStub(error: APIClientError.invalidResponse)
        let sut = EquipmentListViewModel(service: service)
        sut.startCreatingList()
        sut.updateListName("  周末露营  ")

        let failedCreate = await sut.saveListName()
        XCTAssertFalse(failedCreate)
        XCTAssertEqual(sut.state.editing, .create(name: "  周末露营  "))
        XCTAssertNotNil(sut.state.listNameSaveError)
        XCTAssertEqual(service.savedListNames, ["周末露营"])

        service.error = nil
        let created = await sut.saveListName()
        XCTAssertTrue(created)
        XCTAssertEqual(sut.state.editing, .none)
        XCTAssertEqual(sut.summary, service.equipmentCollection.summary)
        let list = sut.equipmentLists[0]
        sut.startRenamingList(list)
        sut.updateListName("三日清单")
        service.error = APIClientError.invalidResponse
        let failedRename = await sut.saveListName()
        XCTAssertFalse(failedRename)
        XCTAssertEqual(sut.state.editing, .rename(id: list.identity, name: "三日清单"))
        XCTAssertEqual(sut.equipmentLists[0], list)

        service.error = nil
        let renamed = await sut.saveListName()
        XCTAssertTrue(renamed)
        XCTAssertEqual(sut.state.editing, .none)
        XCTAssertEqual(sut.equipmentLists[0].name, service.listMutation.equipmentList.name)
    }

    func testListNameValidationCancelAndMutualExclusion() async {
        let service = EquipmentServiceStub()
        let sut = EquipmentListViewModel(service: service)
        sut.startCreatingList()
        sut.updateListName("  ")
        XCTAssertEqual(sut.state.listNameFieldError, "请输入清单名称")
        let saved = await sut.saveListName()
        XCTAssertFalse(saved)
        XCTAssertTrue(service.savedListNames.isEmpty)
        sut.cancelEditing()
        XCTAssertEqual(sut.state.editing, .none)
        XCTAssertEqual(sut.state.activeListName, "")
        let list = EquipmentListOverview(identity: "list", name: "清单", summary: service.listDetail.summary)
        sut.requestDeletion(list)
        XCTAssertEqual(sut.state.deletingList, list)
        sut.startRenamingList(list)
        XCTAssertNil(sut.state.deletingList)
        XCTAssertEqual(sut.state.editing, .rename(id: "list", name: "清单"))
    }

    func testMemberFailureKeepsServerProjectionAndTargetsOnlyFailedList() async {
        let service = EquipmentServiceStub()
        let sut = EquipmentListViewModel(service: service)
        await sut.loadEquipmentList(id: "list")
        service.error = APIClientError.invalidResponse
        let removed = await sut.removeMember(equipmentListID: "list", personalEquipmentID: "equipment")
        XCTAssertFalse(removed)
        XCTAssertEqual(sut.selectedEquipmentList, service.listDetail)
        XCTAssertEqual(sut.state.failedListID, "list")
        sut.clearSelectedEquipmentList()
        XCTAssertNil(sut.state.failedListID)
    }

    func testListDeletionKeepsConfirmationOnFailureAndClearsOnlyAfterSuccess() async {
        let service = EquipmentServiceStub()
        let sut = EquipmentListViewModel(service: service)
        sut.startCreatingList()
        sut.updateListName("清单")
        _ = await sut.saveListName()
        let list = sut.equipmentLists[0]
        sut.requestDeletion(list)
        service.error = APIClientError.invalidResponse
        let failed = await sut.deleteEquipmentList(id: list.identity)
        XCTAssertFalse(failed)
        XCTAssertEqual(sut.state.deletingList, list)
        XCTAssertEqual(sut.equipmentLists, [list])
        service.error = nil
        let deleted = await sut.deleteEquipmentList(id: list.identity)
        XCTAssertTrue(deleted)
        XCTAssertNil(sut.state.deletingList)
        XCTAssertTrue(sut.equipmentLists.isEmpty)
    }

    func testMyEquipmentPageComposesApprovedBusinessComponentsWithoutPrivateDuplicates() throws {
        let source = try productionSource(at: "Features/Equipment/EquipmentListView.swift")

        XCTAssertTrue(source.contains("EquipmentListRow("))
        XCTAssertTrue(source.contains("projection: .personalAsset("))
        XCTAssertTrue(source.contains("InlineListNameEditor("))
        XCTAssertTrue(source.contains("ChecklistPanel("))
        XCTAssertTrue(source.contains("ChecklistItemRowProjection("))
        XCTAssertTrue(source.contains("if isEditingListName { return \"保存清单\" }"))
        XCTAssertFalse(source.contains("tripSnapshot"))
        XCTAssertFalse(source.contains("private struct PersonalEquipmentRow"))
        XCTAssertFalse(source.contains("private struct EquipmentListMemberRow"))
        XCTAssertFalse(source.contains("private var listNameEditor"))
        XCTAssertFalse(source.contains("private func checklistPanel"))
        XCTAssertFalse(source.contains("private func checklistSummaryText"))
        XCTAssertTrue(source.contains("ScrollViewReader"))
        XCTAssertFalse(source.contains("ScrollView {"), "页面只使用 UtilityPage 拥有的纵向滚动")
        XCTAssertTrue(source.contains(".scrollView(axis: .vertical)"), "锚点以壳的滚动视口为坐标参考")
    }

    func testEquipmentEditPageComposesApprovedBusinessComponentsWithoutPrivateFormUI() throws {
        let source = try productionSource(at: "Features/Equipment/AddEquipmentView.swift")

        XCTAssertTrue(source.contains("PersonalEquipmentForm("))
        XCTAssertTrue(source.contains("PersonalEquipmentFormProjection("))
        XCTAssertTrue(source.contains("EquipmentDeletionImpact("))
        XCTAssertTrue(source.contains("viewModel.state.deletionImpact"))
        XCTAssertFalse(source.contains("private var equipmentForm"))
        XCTAssertFalse(source.contains("\n            FormField("))
        XCTAssertFalse(source.contains("TextField("))
        XCTAssertFalse(source.contains("NoticeView("))
    }

    func testEquipmentEditModeIsDeterminedOnlyByEquipmentID() {
        XCTAssertEqual(EquipmentEditMode(equipmentID: nil), .create)
        XCTAssertEqual(EquipmentEditMode(equipmentID: "equipment-1"), .edit(equipmentID: "equipment-1"))
    }

    func testEditLoadFailureExposesFailedStateAndNeverFallsBackToCreate() async {
        let service = EquipmentServiceStub(error: APIClientError.api(
            code: "personal_equipment_unavailable",
            message: "装备加载失败",
            retryable: true
        ))
        let sut = EquipmentEditViewModel(service: service, equipmentID: "equipment-1")

        await sut.load()
        sut.updateName("帐篷")
        let saved = await sut.save()

        XCTAssertEqual(sut.state.loadState, .failed)
        XCTAssertNil(sut.state.loadedEquipment)
        XCTAssertEqual(service.createCallCount, 0)
        XCTAssertEqual(service.updateCallCount, 0)
        XCTAssertFalse(saved)
    }

    func testEquipmentNameConflictKeepsTypedCodeForFieldPresentation() async {
        let service = EquipmentServiceStub(error: APIClientError.api(
            code: "equipment_name_conflict",
            message: "已存在同名装备",
            retryable: false
        ))
        let sut = EquipmentEditViewModel(service: service)
        sut.updateName("帐篷")
        let saved = await sut.save()

        XCTAssertEqual(sut.state.errorCode, "equipment_name_conflict")
        XCTAssertEqual(sut.state.nameFieldError, "已存在同名装备")
        XCTAssertFalse(saved)
        XCTAssertTrue(sut.state.isDirty)
        XCTAssertEqual(sut.state.draft.name, "帐篷")
        sut.updateName("双人帐篷")
        XCTAssertNil(sut.state.nameFieldError)
        XCTAssertTrue(sut.state.isInputValid)
    }

    func testEquipmentEditFormDirtyStateComparesAgainstLoadedSnapshot() async {
        let service = EquipmentServiceStub()
        let sut = EquipmentEditViewModel(service: service, equipmentID: "equipment")
        await sut.load()
        XCTAssertFalse(sut.state.isDirty)
        sut.updateName("双人帐篷")
        XCTAssertTrue(sut.state.isDirty)
        await sut.load()
        XCTAssertEqual(sut.state.draft.name, "双人帐篷", "重复生命周期加载不得覆盖草稿")
        XCTAssertEqual(service.loadedEquipmentIDs.count, 1)
        sut.updateName("  装备  ")
        XCTAssertFalse(sut.state.isDirty)
        sut.updateQuantity("2")
        XCTAssertFalse(sut.requestDismissal())
        XCTAssertEqual(sut.state.confirmation, .discard)
        sut.cancelConfirmation()
        XCTAssertTrue(sut.state.isDirty)
        sut.discardChanges()
        XCTAssertFalse(sut.state.isDirty)
        XCTAssertTrue(sut.requestDismissal())
    }

    func testEditInitialStateAndTouchedValidationPreventInvalidSave() async {
        let service = EquipmentServiceStub()
        let sut = EquipmentEditViewModel(service: service)
        XCTAssertTrue(sut.state.isFormAvailable)
        XCTAssertFalse(sut.state.isDirty)
        XCTAssertEqual(sut.state.draft.quantityText, "1")
        XCTAssertNil(sut.state.nameFieldError)
        sut.updateName(" ")
        sut.updateQuantity("0")
        sut.updateWeight("bad")
        XCTAssertEqual(sut.state.nameFieldError, "请输入装备名称")
        XCTAssertEqual(sut.state.quantityFieldError, "请输入大于零的正整数")
        XCTAssertEqual(sut.state.weightFieldError, "请输入大于零的克重")
        let invalid = await sut.save()
        XCTAssertFalse(invalid)
        XCTAssertEqual(service.createCallCount, 0)
        sut.updateName("帐篷")
        sut.updateQuantity("2")
        sut.updateWeight("")
        XCTAssertTrue(sut.state.isInputValid)
    }

    func testEditWeightUpdateDistinguishesClearUnchangedAndValue() async {
        for weight in [nil, EquipmentWeight(grams: 410)] {
            let service = EquipmentServiceStub()
            service.createResult = PersonalEquipmentMutation(
                item: PersonalEquipment(identity: "equipment", name: "冰爪", ownedQuantity: 2, unitWeight: weight),
                summary: service.equipmentCollection.summary
            )
            let sut = EquipmentEditViewModel(service: service, equipmentID: "equipment")
            await sut.load()
            sut.updateWeight("")
            let saved = await sut.save()
            XCTAssertTrue(saved)
            XCTAssertEqual(service.lastUpdate?.unitWeight, weight == nil ? .unchanged : .clear)
            XCTAssertEqual(service.createCallCount, 0)
            sut.updateWeight(" 500 ")
            let weighted = await sut.save()
            XCTAssertTrue(weighted)
            XCTAssertEqual(service.lastUpdate?.unitWeight, .value(EquipmentWeight(grams: 500)))
        }
    }

    func testDeletionRequiresLoadedImpactAndReturnsEachAttemptResult() async {
        let service = EquipmentServiceStub()
        let sut = EquipmentEditViewModel(service: service, equipmentID: "equipment")
        await sut.load()
        let premature = await sut.deleteEquipment()
        XCTAssertFalse(premature)
        XCTAssertEqual(service.deleteCallCount, 0)
        service.error = APIClientError.invalidResponse
        let failedImpact = await sut.prepareDeletion()
        XCTAssertFalse(failedImpact)
        XCTAssertEqual(sut.state.confirmation, .none)
        XCTAssertNotNil(sut.state.deletionErrorMessage)
        service.error = nil
        let prepared = await sut.prepareDeletion()
        XCTAssertTrue(prepared)
        XCTAssertEqual(sut.state.confirmation, .deletion)
        service.error = APIClientError.invalidResponse
        let failedDelete = await sut.deleteEquipment()
        XCTAssertFalse(failedDelete)
        XCTAssertNotNil(sut.state.loadedEquipment)
        XCTAssertNotNil(sut.state.deletionErrorMessage)
        XCTAssertEqual(sut.state.confirmation, .none)
        service.error = nil
        _ = await sut.prepareDeletion()
        let deleted = await sut.deleteEquipment()
        XCTAssertTrue(deleted)
        XCTAssertEqual(sut.state.deletionResult?.deletedPersonalEquipmentId, "equipment")
    }

    func testCancelledEditSaveDoesNotApplyReturnedMutation() async {
        let service = EquipmentServiceStub()
        let started = expectation(description: "save started")
        var continuation: CheckedContinuation<PersonalEquipmentMutation, Never>?
        service.createHandler = {
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
        }
        let sut = EquipmentEditViewModel(service: service)
        sut.updateName("草稿")
        let task = Task { await sut.save() }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        continuation?.resume(returning: service.createResult)
        let saved = await task.value
        XCTAssertFalse(saved)
        XCTAssertNil(sut.state.savedMutation)
        XCTAssertEqual(sut.state.draft.name, "草稿")
        XCTAssertTrue(sut.state.isDirty)
        XCTAssertFalse(sut.state.isMutating)
        XCTAssertNil(sut.state.errorMessage)
    }

    func testSaveFailureAfterSuccessReturnsFalseAndPreservesNewDraft() async {
        let service = EquipmentServiceStub()
        let sut = EquipmentEditViewModel(service: service, equipmentID: "equipment")
        await sut.load()
        let first = await sut.save()
        XCTAssertTrue(first)
        sut.updateName("未保存的新草稿")
        service.error = APIClientError.invalidResponse
        let second = await sut.save()
        XCTAssertFalse(second)
        XCTAssertTrue(sut.state.isDirty)
        XCTAssertEqual(sut.state.draft.name, "未保存的新草稿")
        XCTAssertEqual(sut.state.loadedEquipment, service.createResult.item)
        XCTAssertNotNil(sut.state.saveErrorMessage)
    }

    func testInvalidatedDeletionKeepsWriteLockedUntilServiceReturns() async {
        let service = EquipmentServiceStub()
        let sut = EquipmentEditViewModel(service: service, equipmentID: "equipment")
        await sut.load()
        _ = await sut.prepareDeletion()
        let impact = sut.state.deletionImpact
        let started = expectation(description: "delete started")
        var continuation: CheckedContinuation<PersonalEquipmentDeletionResult, Never>?
        service.deleteHandler = {
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
        }
        let task = Task { await sut.deleteEquipment() }
        await fulfillment(of: [started], timeout: 1)
        sut.invalidatePendingOperations()
        service.deleteHandler = nil
        XCTAssertTrue(sut.state.isMutating)
        let duplicateDelete = await sut.deleteEquipment()
        let overlappingSave = await sut.save()
        XCTAssertFalse(duplicateDelete)
        XCTAssertFalse(overlappingSave)
        XCTAssertEqual(service.deleteCallCount, 1)
        XCTAssertEqual(service.updateCallCount, 0)
        sut.updateName("新草稿")
        sut.cancelConfirmation()
        sut.discardChanges()
        await sut.load()
        XCTAssertFalse(sut.requestDismissal())
        XCTAssertEqual(sut.state.draft.name, "装备")
        XCTAssertEqual(sut.state.confirmation, .deletion)
        XCTAssertEqual(sut.state.deletionImpact, impact)
        continuation?.resume(returning: PersonalEquipmentDeletionResult(
            deletedPersonalEquipmentId: "equipment", removedEquipmentListReferenceCount: 0,
            summary: service.equipmentCollection.summary
        ))
        let deleted = await task.value
        XCTAssertFalse(deleted)
        XCTAssertFalse(sut.state.isMutating)
        XCTAssertEqual(sut.state.confirmation, .deletion, "失效响应不得关闭确认层")
        XCTAssertNil(sut.state.deletionResult)
        XCTAssertNotNil(sut.state.loadedEquipment)
        XCTAssertNil(sut.state.errorMessage)
        sut.updateName("新草稿")
        XCTAssertFalse(sut.requestDismissal())
        XCTAssertEqual(sut.state.confirmation, .discard)
        XCTAssertEqual(sut.state.draft.name, "新草稿")
    }

    func testLateListDetailCannotOverwriteNewSelection() async {
        let service = EquipmentServiceStub()
        let started = expectation(description: "first detail started")
        var continuation: CheckedContinuation<EquipmentListDetail, Never>?
        service.listDetailHandler = { id in
            if id == "first" {
                return await withCheckedContinuation {
                    continuation = $0
                    started.fulfill()
                }
            }
            return service.listDetail
        }
        let sut = EquipmentListViewModel(service: service)
        let task = Task { await sut.loadEquipmentList(id: "first") }
        await fulfillment(of: [started], timeout: 1)
        await sut.loadEquipmentList(id: "list")
        continuation?.resume(returning: EquipmentListDetail(
            identity: "first", name: "迟到清单", members: [], summary: service.listDetail.summary
        ))
        await task.value
        XCTAssertEqual(sut.selectedEquipmentListID, "list")
        XCTAssertEqual(sut.selectedEquipmentList, service.listDetail)
        XCTAssertFalse(sut.isLoadingEquipmentList)
    }

    func testLoadRefreshesSelectedListAfterEquipmentDeletion() async {
        let service = EquipmentServiceStub()
        let refreshedDetail = service.listDetail
        let originalDetail = EquipmentListDetail(
            identity: "list", name: "清单",
            members: [EquipmentListMember(
                identity: "equipment", name: "装备", ownedQuantity: 1, unitWeight: nil, quantity: 1
            )],
            summary: EquipmentListSummary(itemCount: 1, knownTotalWeight: EquipmentWeight(grams: 0), missingWeightItemCount: 1)
        )
        service.listDetail = originalDetail
        service.equipmentCollection = PersonalEquipmentCollection(
            items: [service.createResult.item],
            summary: PersonalEquipmentSummary(
                equipmentItemCount: 1, equipmentListCount: 1,
                knownTotalWeight: EquipmentWeight(grams: 0), missingWeightItemCount: 1
            )
        )
        service.listCollection = EquipmentListCollection(items: [EquipmentListOverview(
            identity: "list", name: "清单", summary: originalDetail.summary
        )])
        let sut = EquipmentListViewModel(service: service)
        await sut.load()
        await sut.loadEquipmentList(id: "list")
        XCTAssertEqual(sut.selectedEquipmentList, originalDetail)
        sut.invalidatePendingOperations()
        service.equipmentCollection = PersonalEquipmentCollection(
            items: [],
            summary: PersonalEquipmentSummary(
                equipmentItemCount: 0, equipmentListCount: 1,
                knownTotalWeight: EquipmentWeight(grams: 0), missingWeightItemCount: 0
            )
        )
        service.listCollection = EquipmentListCollection(items: [EquipmentListOverview(
            identity: "list", name: "清单", summary: refreshedDetail.summary
        )])
        let started = expectation(description: "selected detail refresh started")
        var continuation: CheckedContinuation<EquipmentListDetail, Never>?
        service.listDetailHandler = { _ in
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
        }
        let refresh = Task { await sut.load() }
        await fulfillment(of: [started], timeout: 1)
        XCTAssertEqual(service.loadedListIDs, ["list", "list"])
        XCTAssertTrue(sut.isLoadingEquipmentList)
        XCTAssertNil(sut.selectedEquipmentList, "返回后不得继续展示删除前的成员")
        continuation?.resume(returning: refreshedDetail)
        await refresh.value
        XCTAssertEqual(sut.selectedEquipmentListID, "list")
        XCTAssertEqual(sut.selectedEquipmentList, refreshedDetail)
        XCTAssertEqual(sut.equipmentLists, service.listCollection.items)
        XCTAssertEqual(sut.summary, service.equipmentCollection.summary)
        XCTAssertTrue(sut.items.isEmpty)
        XCTAssertFalse(sut.isLoadingEquipmentList)
    }

    func testLoadRefreshUsesSelectionAtCollectionCompletion() async {
        let service = EquipmentServiceStub()
        let otherDetail = EquipmentListDetail(
            identity: "other", name: "另一清单", members: [], summary: service.listDetail.summary
        )
        service.listCollection = EquipmentListCollection(items: [service.listDetail, otherDetail].map {
            EquipmentListOverview(identity: $0.identity, name: $0.name, summary: $0.summary)
        })
        let sut = EquipmentListViewModel(service: service)
        await sut.loadEquipmentList(id: "list")
        let started = expectation(description: "overview refresh started")
        var continuation: CheckedContinuation<EquipmentListCollection, Never>?
        service.listCollectionHandler = {
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
        }
        let refresh = Task { await sut.load() }
        await fulfillment(of: [started], timeout: 1)
        service.listDetail = otherDetail
        await sut.loadEquipmentList(id: "other")
        continuation?.resume(returning: service.listCollection)
        await refresh.value
        XCTAssertEqual(service.loadedListIDs, ["list", "other", "other"])
        XCTAssertEqual(sut.selectedEquipmentListID, "other")
        XCTAssertEqual(sut.selectedEquipmentList, otherDetail)
    }

    func testCreatingAnotherListPreservesPendingSelectedDetail() async {
        let service = EquipmentServiceStub()
        let selectedDetail = service.listDetail
        let createdDetail = EquipmentListDetail(
            identity: "new-list", name: "新清单", members: [], summary: selectedDetail.summary
        )
        service.listCollection = EquipmentListCollection(items: [EquipmentListOverview(
            identity: "list", name: selectedDetail.name, summary: selectedDetail.summary
        )])
        let started = expectation(description: "selected detail started")
        var continuation: CheckedContinuation<EquipmentListDetail, Never>?
        service.listDetailHandler = { _ in
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
        }
        service.createListHandler = { _ in
            EquipmentListCreateResult(
                equipmentList: createdDetail,
                personalEquipmentSummary: PersonalEquipmentSummary(
                    equipmentItemCount: 0, equipmentListCount: 2,
                    knownTotalWeight: EquipmentWeight(grams: 0), missingWeightItemCount: 0
                )
            )
        }
        let sut = EquipmentListViewModel(service: service)
        await sut.load()
        let detail = Task { await sut.loadEquipmentList(id: "list") }
        await fulfillment(of: [started], timeout: 1)
        sut.startCreatingList()
        sut.updateListName("新清单")
        let saved = await sut.saveListName()
        XCTAssertTrue(saved)
        XCTAssertEqual(sut.selectedEquipmentListID, "list")
        XCTAssertTrue(sut.isLoadingEquipmentList, "创建其他清单不得取消当前详情读取")
        continuation?.resume(returning: selectedDetail)
        await detail.value
        XCTAssertEqual(service.loadedListIDs, ["list"])
        XCTAssertEqual(sut.selectedEquipmentList, selectedDetail)
        XCTAssertEqual(sut.equipmentLists.map(\.identity), ["list", "new-list"])
        XCTAssertEqual(sut.summary?.equipmentListCount, 2)
        XCTAssertFalse(sut.isLoadingEquipmentList)
    }

    func testOlderDetailCannotOverwriteMemberMutationResult() async {
        let service = EquipmentServiceStub()
        let oldDetail = EquipmentListDetail(
            identity: "list", name: "清单",
            members: [EquipmentListMember(
                identity: "equipment", name: "装备", ownedQuantity: 1, unitWeight: nil, quantity: 1
            )],
            summary: EquipmentListSummary(itemCount: 1, knownTotalWeight: EquipmentWeight(grams: 0), missingWeightItemCount: 1)
        )
        let started = expectation(description: "old detail started")
        var continuation: CheckedContinuation<EquipmentListDetail, Never>?
        service.listDetailHandler = { _ in
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
        }
        let sut = EquipmentListViewModel(service: service)
        let detail = Task { await sut.loadEquipmentList(id: "list") }
        await fulfillment(of: [started], timeout: 1)
        let removed = await sut.removeMember(equipmentListID: "list", personalEquipmentID: "equipment")
        XCTAssertTrue(removed)
        XCTAssertEqual(sut.selectedEquipmentList, service.listMutation.equipmentList)
        XCTAssertFalse(sut.isLoadingEquipmentList)
        continuation?.resume(returning: oldDetail)
        await detail.value
        XCTAssertEqual(sut.selectedEquipmentList, service.listMutation.equipmentList)
        XCTAssertFalse(sut.isLoadingEquipmentList)
    }

    func testInvalidatedListSaveKeepsWriteLockedUntilServiceReturns() async {
        let service = EquipmentServiceStub()
        let started = expectation(description: "invalidated list save started")
        var continuation: CheckedContinuation<EquipmentListCreateResult, Never>?
        service.createListHandler = { _ in
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
        }
        let sut = EquipmentListViewModel(service: service)
        sut.startCreatingList()
        sut.updateListName("草稿")
        let save = Task { await sut.saveListName() }
        await fulfillment(of: [started], timeout: 1)
        sut.invalidatePendingOperations()
        service.createListHandler = nil
        XCTAssertTrue(sut.isMutating)
        await sut.load()
        let duplicate = await sut.saveListName()
        XCTAssertFalse(duplicate)
        XCTAssertEqual(service.savedListNames, ["草稿"])
        sut.cancelEditing()
        sut.updateListName("另一草稿")
        XCTAssertEqual(sut.state.editing, .create(name: "草稿"))
        continuation?.resume(returning: EquipmentListCreateResult(
            equipmentList: service.listDetail, personalEquipmentSummary: service.equipmentCollection.summary
        ))
        let saved = await save.value
        XCTAssertFalse(saved)
        XCTAssertFalse(sut.isMutating)
        XCTAssertTrue(sut.equipmentLists.isEmpty)
        XCTAssertEqual(sut.state.editing, .create(name: "草稿"))
        XCTAssertNil(sut.errorMessage)
        let retried = await sut.saveListName()
        XCTAssertTrue(retried)
        XCTAssertEqual(service.savedListNames, ["草稿", "草稿"])
    }

    func testCancelledListSaveKeepsDraftAndDoesNotApplyResult() async {
        let service = EquipmentServiceStub()
        let started = expectation(description: "list save started")
        var continuation: CheckedContinuation<EquipmentListCreateResult, Never>?
        service.createListHandler = { _ in
            await withCheckedContinuation {
                continuation = $0
                started.fulfill()
            }
        }
        let sut = EquipmentListViewModel(service: service)
        sut.startCreatingList()
        sut.updateListName("未提交草稿")
        let task = Task { await sut.saveListName() }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        continuation?.resume(returning: EquipmentListCreateResult(
            equipmentList: service.listDetail, personalEquipmentSummary: service.equipmentCollection.summary
        ))
        let saved = await task.value
        XCTAssertFalse(saved)
        XCTAssertEqual(sut.state.editing, .create(name: "未提交草稿"))
        XCTAssertTrue(sut.equipmentLists.isEmpty)
        XCTAssertFalse(sut.isMutating)
        XCTAssertNil(sut.errorMessage)
    }

    func testServiceCancellationDoesNotBecomeVisibleFailure() async {
        let service = EquipmentServiceStub(error: APIClientError.transport(.cancelled))
        let editor = EquipmentEditViewModel(service: service, equipmentID: "equipment")
        await editor.load()
        XCTAssertEqual(editor.state.loadState, .idle)
        XCTAssertNil(editor.state.errorMessage)
        let creator = EquipmentEditViewModel(service: service)
        creator.updateName("帐篷")
        let created = await creator.save()
        XCTAssertFalse(created)
        XCTAssertNil(creator.state.saveErrorMessage)
        XCTAssertEqual(creator.state.operation, .idle)
        let list = EquipmentListViewModel(service: service)
        await list.load()
        XCTAssertNil(list.loadErrorMessage)
        await list.loadEquipmentList(id: "list")
        XCTAssertNil(list.state.listLoadErrorMessage)
        list.startCreatingList()
        list.updateListName("草稿")
        let saved = await list.saveListName()
        XCTAssertFalse(saved)
        XCTAssertEqual(list.state.editing, .create(name: "草稿"))
        XCTAssertNil(list.state.listNameSaveError)
        XCTAssertEqual(list.state.operation, .idle)
    }

    func testEquipmentEditSourceGuardsLoadingFailureSaveAndDiscard() throws {
        let source = try productionSource(at: "Features/Equipment/AddEquipmentView.swift")

        XCTAssertTrue(source.contains("case .idle, .loading:"))
        XCTAssertTrue(source.contains("case .failed"))
        XCTAssertTrue(source.contains("ErrorView"))
        XCTAssertTrue(source.contains("viewModel.load()"))
        XCTAssertTrue(source.contains("navigationBarBackButtonHidden(true)"))
        XCTAssertTrue(source.contains("interactiveDismissDisabled(viewModel.state.isDirty)"))
        XCTAssertTrue(source.contains("放弃未保存的修改？"))
        XCTAssertFalse(source.contains("保存成功"))
        XCTAssertFalse(source.contains("EquipmentListViewModel"))
        XCTAssertTrue(source.contains("if await viewModel.save()"))
        XCTAssertTrue(source.contains("if await viewModel.deleteEquipment()"))
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private final class EquipmentServiceStub: PersonalEquipmentManaging {
    var equipmentCollection: PersonalEquipmentCollection
    var listCollection: EquipmentListCollection
    var createResult: PersonalEquipmentMutation
    var listDetail: EquipmentListDetail
    var listMutation: EquipmentListMutation
    var error: Error?
    private(set) var loadedEquipmentIDs: [String] = []
    private(set) var loadedListIDs: [String] = []
    private(set) var createCallCount = 0
    private(set) var updateCallCount = 0
    private(set) var deleteCallCount = 0
    private(set) var lastUpdate: PersonalEquipmentUpdate?
    private(set) var savedListNames: [String] = []
    var createHandler: (() async -> PersonalEquipmentMutation)?
    var deleteHandler: (() async -> PersonalEquipmentDeletionResult)?
    var createListHandler: ((String) async -> EquipmentListCreateResult)?
    var listDetailHandler: ((String) async -> EquipmentListDetail)?
    var listCollectionHandler: (() async -> EquipmentListCollection)?

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

    func getPersonalEquipment(filter: PersonalEquipmentFilter) async throws -> PersonalEquipmentCollection {
        try await getPersonalEquipment()
    }

    func createPersonalEquipment(input: PersonalEquipmentCreateRequest) async throws -> PersonalEquipmentMutation {
        createCallCount += 1
        if let createHandler { return await createHandler() }
        if let error { throw error }
        return createResult
    }

    func createPersonalEquipmentFromCatalog(input: PersonalEquipmentFromCatalogRequest, idempotencyKey: String) async throws -> PersonalEquipmentMutation {
        throw APIClientError.invalidResponse
    }

    func copyEquipmentList(id: String, name: String, idempotencyKey: String) async throws -> EquipmentListCreateResult {
        throw APIClientError.invalidResponse
    }

    func getPersonalEquipment() async throws -> PersonalEquipmentCollection {
        if let error { throw error }
        return equipmentCollection
    }

    func createPersonalEquipment(name: String, ownedQuantity: Int, unitWeightGrams: Int?) async throws -> PersonalEquipmentMutation {
        createCallCount += 1
        if let createHandler { return await createHandler() }
        if let error { throw error }
        return createResult
    }

    func getPersonalEquipment(id: String) async throws -> PersonalEquipment {
        loadedEquipmentIDs.append(id)
        if let error { throw error }
        return createResult.item
    }

    func updatePersonalEquipment(id: String, update: PersonalEquipmentUpdate) async throws -> PersonalEquipmentMutation {
        updateCallCount += 1
        lastUpdate = update
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
        deleteCallCount += 1
        if let deleteHandler { return await deleteHandler() }
        if let error { throw error }
        return PersonalEquipmentDeletionResult(
            deletedPersonalEquipmentId: id,
            removedEquipmentListReferenceCount: 0,
            summary: equipmentCollection.summary
        )
    }

    func getEquipmentLists() async throws -> EquipmentListCollection {
        if let listCollectionHandler { return await listCollectionHandler() }
        if let error { throw error }
        return listCollection
    }

    func createEquipmentList(name: String) async throws -> EquipmentListCreateResult {
        savedListNames.append(name)
        if let createListHandler { return await createListHandler(name) }
        if let error { throw error }
        return EquipmentListCreateResult(
            equipmentList: listDetail,
            personalEquipmentSummary: equipmentCollection.summary
        )
    }

    func getEquipmentList(id: String) async throws -> EquipmentListDetail {
        loadedListIDs.append(id)
        if let listDetailHandler { return await listDetailHandler(id) }
        if let error { throw error }
        return listDetail
    }

    func renameEquipmentList(id: String, name: String) async throws -> EquipmentListMutation {
        savedListNames.append(name)
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
    func testEditorValidationAndFailedSaveKeepDraftThenSuccessCloses() async {
        let initial = tripEquipmentProjection(revision: "revision-1", name: "帐篷")
        let service = TripEquipmentServiceStub(projection: initial)
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)
        await sut.load()
        sut.beginAdding()
        let invalid = await sut.saveEditor()
        XCTAssertFalse(invalid)
        XCTAssertEqual(service.mutationCount, 0)
        XCTAssertNotNil(sut.editorNameError)
        sut.updateName("  水  ")
        sut.updateQuantity(2)
        sut.updateUnitWeight("500")
        sut.updateNote("  饮用  ")
        service.error = APIClientError.invalidResponse
        let failed = await sut.saveEditor()
        XCTAssertFalse(failed)
        XCTAssertNotNil(sut.state.editor)
        XCTAssertEqual(sut.state.draft.name, "  水  ")
        XCTAssertEqual(sut.projection, initial)
        service.error = nil
        let saved = await sut.saveEditor()
        XCTAssertTrue(saved)
        XCTAssertNil(sut.state.editor)
        XCTAssertEqual(service.addedName, "水")
        XCTAssertEqual(service.addedQuantity, 2)
        XCTAssertEqual(service.addedWeight, 500)
        XCTAssertEqual(service.addedNote, "饮用")
    }

    func testNameEditingPreservesOptionalFieldsAndFailedDeleteKeepsDialog() async {
        let initial = tripEquipmentProjection(revision: "revision-1", name: "帐篷")
        let service = TripEquipmentServiceStub(projection: initial)
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)
        await sut.load()
        sut.beginEditing(initial.snapshot.items[0])
        sut.updateName("新帐篷")
        let saved = await sut.saveEditor()
        XCTAssertTrue(saved)
        XCTAssertEqual(service.lastUpdate?.unitWeight, .unchanged)
        XCTAssertEqual(service.lastUpdate?.note, .unchanged)
        sut.requestDelete(initial.snapshot.items[0])
        service.error = APIClientError.invalidResponse
        let deleted = await sut.confirmDeletion()
        XCTAssertFalse(deleted)
        XCTAssertEqual(sut.state.deletingItem?.identity, "item-1")
        XCTAssertNotNil(sut.state.deletionError)
        XCTAssertEqual(sut.projection, initial)
        service.error = nil
        let retried = await sut.confirmDeletion()
        XCTAssertTrue(retried)
        XCTAssertNil(sut.state.deletingItem)
    }

    func testLateReadCannotOverwriteMutationAndDuplicateWriteIsRejected() async {
        let initial = tripEquipmentProjection(revision: "revision-1", name: "帐篷")
        let replacement = tripEquipmentProjection(revision: "revision-2", name: "水")
        let service = TripEquipmentServiceStub(projection: initial)
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)
        await sut.load()
        let readStarted = expectation(description: "read started")
        let writeStarted = expectation(description: "write started")
        var read: CheckedContinuation<TripEquipmentProjection, Never>?
        var write: CheckedContinuation<TripEquipmentProjection, Never>?
        service.loadHandler = {
            await withCheckedContinuation { read = $0; readStarted.fulfill() }
        }
        service.mutationHandler = {
            await withCheckedContinuation { write = $0; writeStarted.fulfill() }
        }
        let loading = Task { await sut.load() }
        await fulfillment(of: [readStarted], timeout: 1)
        let mutation = Task { await sut.deleteItem(itemID: "item-1") }
        await fulfillment(of: [writeStarted], timeout: 1)
        let duplicate = await sut.deleteItem(itemID: "item-1")
        await sut.load()
        XCTAssertFalse(duplicate)
        XCTAssertEqual(service.mutationCount, 1)
        XCTAssertEqual(service.loadCount, 2, "mutation 期间不启动新的 read")
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(sut.isMutating)
        write?.resume(returning: replacement)
        let succeeded = await mutation.value
        XCTAssertTrue(succeeded)
        read?.resume(returning: initial)
        await loading.value
        XCTAssertEqual(sut.projection, replacement)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isMutating)
    }

    func testCancelledSaveKeepsEditorAndDoesNotPublishLateResult() async {
        let initial = tripEquipmentProjection(revision: "revision-1", name: "帐篷")
        let service = TripEquipmentServiceStub(projection: initial)
        let started = expectation(description: "save started")
        var continuation: CheckedContinuation<TripEquipmentProjection, Never>?
        service.mutationHandler = {
            await withCheckedContinuation { continuation = $0; started.fulfill() }
        }
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)
        await sut.load()
        sut.beginAdding()
        sut.updateName("水")
        let task = Task { await sut.saveEditor() }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        let duplicate = await sut.saveEditor()
        await sut.load()
        XCTAssertFalse(duplicate)
        XCTAssertTrue(sut.isMutating)
        XCTAssertEqual(service.mutationCount, 1)
        XCTAssertEqual(service.loadCount, 1)
        continuation?.resume(returning: tripEquipmentProjection(revision: "late", name: "水"))
        let saved = await task.value
        XCTAssertFalse(saved)
        XCTAssertEqual(sut.projection, initial)
        XCTAssertNotNil(sut.state.editor)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isMutating)
    }

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
        let service = TripEquipmentServiceStub(projection: initial)
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)
        await sut.load()
        service.projection = replacement

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
        let service = TripEquipmentServiceStub(projection: initial)
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)
        await sut.load()
        service.error = APIClientError.api(
            code: "trip_equipment_read_only",
            message: "该行程装备已只读",
            retryable: false
        )

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
        let service = TripEquipmentServiceStub(projection: readOnly)
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)
        await sut.load()
        sut.beginAdding()
        sut.requestDelete(readOnly.snapshot.items[0])
        let deleted = await sut.deleteItem(itemID: "item-1")
        let added = await sut.addItem(name: "水", quantity: 1, unitWeightGrams: nil, note: nil)
        let updated = await sut.updateItem(itemID: "item-1", update: TripEquipmentItemUpdate(name: "水"))
        let rechecked = await sut.recheckOwnership()
        XCTAssertFalse(sut.isEditable)
        XCTAssertNil(sut.state.editor)
        XCTAssertNil(sut.state.deletingItem)
        XCTAssertFalse(deleted)
        XCTAssertFalse(added)
        XCTAssertFalse(updated)
        XCTAssertFalse(rechecked)
        XCTAssertEqual(service.mutationCount, 0)
        XCTAssertEqual(service.recheckCount, 0)
    }

    func testCancelledReadCanBeReplacedWithoutLateProjectionOverwrite() async {
        let initial = tripEquipmentProjection(revision: "revision-1", name: "帐篷")
        let replacement = tripEquipmentProjection(revision: "revision-2", name: "水")
        let service = TripEquipmentServiceStub(projection: initial)
        let started = expectation(description: "read started")
        var continuation: CheckedContinuation<TripEquipmentProjection, Never>?
        service.loadHandler = {
            await withCheckedContinuation { continuation = $0; started.fulfill() }
        }
        let sut = TripEquipmentViewModel(tripID: "trip-1", service: service)
        let first = Task { await sut.handleAppearance() }
        await fulfillment(of: [started], timeout: 1)
        await sut.handleAppearance()
        XCTAssertEqual(service.loadCount, 1)
        first.cancel()
        service.loadHandler = nil
        service.projection = replacement
        await sut.handleAppearance()
        continuation?.resume(returning: initial)
        await first.value
        XCTAssertEqual(sut.projection, replacement)
        XCTAssertEqual(service.loadCount, 2)
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.errorMessage)
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

    func testTripEquipmentPageUsesProductionInlineEditorWithoutCrossBoundaryRows() throws {
        let source = try productionSource(at: "Features/Trips/TripEquipment.swift")

        XCTAssertTrue(source.contains("SharedBusinessComponents.InlineEquipmentEditor("))
        XCTAssertTrue(source.contains("InlineEquipmentEditorProjection("))
        XCTAssertTrue(source.contains("name: viewModel.state.draft.name"))
        XCTAssertTrue(source.contains("quantity: viewModel.state.draft.quantity"))
        XCTAssertTrue(source.contains("unitWeight: viewModel.state.draft.unitWeight"))
        XCTAssertTrue(source.contains("note: viewModel.state.draft.note"))
        XCTAssertTrue(source.contains("saveError: viewModel.errorMessage"))
        XCTAssertTrue(source.contains("onChangeField:"))
        XCTAssertTrue(source.contains("onChangeQuantity: viewModel.updateQuantity"))
        XCTAssertTrue(source.contains("onCancel: viewModel.cancelEditing"))
        XCTAssertFalse(source.contains("private struct InlineEquipmentEditor: View"))
        XCTAssertFalse(source.contains("AccountEquipmentBusinessComponents.EquipmentListRow("))
        XCTAssertFalse(source.contains("projection: .tripSnapshot("))
        XCTAssertTrue(source.contains("TripBusinessComponents.TripEquipmentOverview("), "使用生产 TripEquipmentOverview")
        XCTAssertTrue(source.contains("TripEquipmentOverviewProjection("), "构造 TripEquipmentOverviewProjection")
        XCTAssertTrue(source.contains("TripBusinessComponents.TripEquipmentItemRow("), "使用生产 TripEquipmentItemRow")
        XCTAssertTrue(source.contains("equipmentItemProjection("), "页面构造条目投影")
        XCTAssertFalse(source.contains("TripEquipmentMetricGrid("), "不再保留私有 TripEquipmentMetricGrid")
        XCTAssertFalse(source.contains("TripSnapshotEquipmentListRow("), "不再保留私有 TripSnapshotEquipmentListRow")
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private final class TripEquipmentServiceStub: TripEquipmentPreparing {
    var projection: TripEquipmentProjection
    let recheckedProjection: TripEquipmentProjection
    var error: Error?
    private(set) var loadCount = 0
    private(set) var recheckCount = 0
    private(set) var mutationCount = 0
    private(set) var addedName: String?
    private(set) var addedQuantity: Int?
    private(set) var addedWeight: Double?
    private(set) var addedNote: String?
    private(set) var lastUpdate: TripEquipmentItemUpdate?
    var loadHandler: (() async -> TripEquipmentProjection)?
    var mutationHandler: (() async -> TripEquipmentProjection)?

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
        if let loadHandler { return await loadHandler() }
        return try result()
    }

    func addItem(
        tripID: String,
        name: String,
        quantity: Int,
        unitWeightGrams: Int?,
        note: String?
    ) async throws -> TripEquipmentProjection {
        mutationCount += 1
        addedName = name
        addedQuantity = quantity
        addedWeight = unitWeightGrams.map(Double.init)
        addedNote = note
        if let mutationHandler { return await mutationHandler() }
        return try result()
    }

    func updateItem(
        tripID: String,
        itemID: String,
        update: TripEquipmentItemUpdate
    ) async throws -> TripEquipmentProjection {
        mutationCount += 1
        lastUpdate = update
        if let mutationHandler { return await mutationHandler() }
        return try result()
    }

    func deleteItem(tripID: String, itemID: String) async throws -> TripEquipmentProjection {
        mutationCount += 1
        if let mutationHandler { return await mutationHandler() }
        return try result()
    }

    func recheckOwnership(tripID: String) async throws -> TripEquipmentProjection {
        recheckCount += 1
        if let error { throw error }
        return recheckedProjection
    }

    func getPreparation(tripID: String) async throws -> TripEquipmentPreparation {
        throw APIClientError.invalidResponse
    }

    func addItem(tripID: String, input: TripEquipmentItemCreate, revision: String) async throws -> TripEquipmentProjection {
        mutationCount += 1
        addedName = input.name
        addedQuantity = input.quantity
        addedWeight = input.unitWeight?.grams
        addedNote = input.note
        if let mutationHandler { return await mutationHandler() }
        return try result()
    }

    func updateItem(tripID: String, itemID: String, update: TripEquipmentItemUpdate, revision: String) async throws -> TripEquipmentProjection {
        try await updateItem(tripID: tripID, itemID: itemID, update: update)
    }

    func deleteItem(tripID: String, itemID: String, revision: String) async throws -> TripEquipmentProjection {
        try await deleteItem(tripID: tripID, itemID: itemID)
    }

    func recheckOwnership(tripID: String, revision: String) async throws -> TripEquipmentProjection {
        try await recheckOwnership(tripID: tripID)
    }

    func addFromPersonal(tripID: String, personalEquipmentID: String, quantity: Int, revision: String, idempotencyKey: String) async throws -> TripEquipmentProjection { throw APIClientError.invalidResponse }
    func appendList(tripID: String, equipmentListID: String, revision: String, idempotencyKey: String) async throws -> TripEquipmentProjection { throw APIClientError.invalidResponse }
    func replaceWithPersonal(tripID: String, itemID: String, personalEquipmentID: String, quantity: Int, revision: String) async throws -> TripEquipmentProjection { throw APIClientError.invalidResponse }
    func setPacking(tripID: String, itemID: String, packedQuantity: Int, revision: String) async throws -> TripEquipmentProjection { throw APIClientError.invalidResponse }
    func resetPacking(tripID: String, revision: String) async throws -> TripEquipmentProjection { throw APIClientError.invalidResponse }

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
