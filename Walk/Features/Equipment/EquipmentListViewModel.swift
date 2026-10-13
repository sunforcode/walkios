import Foundation
import Observation
import WalkData

@MainActor
@Observable
final class EquipmentListViewModel {
    private(set) var state = EquipmentListState()

    var items: [PersonalEquipment] { state.items }
    var equipmentLists: [EquipmentListOverview] { state.equipmentLists }
    var summary: PersonalEquipmentSummary? { state.summary }
    var selectedEquipmentListID: String? { state.selectedEquipmentListID }
    var selectedEquipmentList: EquipmentListDetail? { state.selectedEquipmentList }
    var isLoading: Bool { state.isLoading }
    var isLoadingEquipmentList: Bool { state.isLoadingEquipmentList }
    var isMutating: Bool { state.isMutating }
    var loadErrorMessage: String? { state.loadErrorMessage }
    var errorMessage: String? { state.errorMessage ?? state.listLoadErrorMessage ?? state.loadErrorMessage }

    private let service: any EquipmentServicing
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var detailGeneration = 0
    @ObservationIgnored private var mutationGeneration = 0

    init(service: any EquipmentServicing) {
        self.service = service
    }

    func load() async {
        guard !isMutating, !Task.isCancelled else { return }
        loadGeneration += 1
        let request = loadGeneration
        state.isLoading = true
        state.loadErrorMessage = nil
        defer {
            if loadGeneration == request { state.isLoading = false }
        }
        do {
            async let equipmentRequest = service.getPersonalEquipment()
            async let listsRequest = service.getEquipmentLists()
            let (equipment, lists) = try await (equipmentRequest, listsRequest)
            guard loadGeneration == request, !Task.isCancelled else { return }
            state.items = equipment.items
            state.summary = equipment.summary
            state.equipmentLists = lists.items
            state.isLoading = false
            // 使用集合返回时仍选中的身份，不能保留装备编辑前的成员投影。
            await refreshSelectedEquipmentList()
        } catch {
            guard loadGeneration == request, !Task.isCancelled, !isCancellation(error) else { return }
            state.loadErrorMessage = message(for: error, operation: "加载")
        }
    }

    func loadEquipmentList(id: String) async {
        guard !isMutating, !Task.isCancelled else { return }
        state.selectedEquipmentListID = id
        clearMutationError()
        await refreshSelectedEquipmentList()
    }

    private func refreshSelectedEquipmentList() async {
        guard let id = selectedEquipmentListID, !isMutating, !Task.isCancelled else { return }
        detailGeneration += 1
        let request = detailGeneration
        state.selectedEquipmentList = nil
        state.isLoadingEquipmentList = true
        state.listLoadErrorMessage = nil
        defer {
            if detailGeneration == request { state.isLoadingEquipmentList = false }
        }
        do {
            let detail = try await service.getEquipmentList(id: id)
            guard detailGeneration == request, selectedEquipmentListID == id, !Task.isCancelled else { return }
            state.selectedEquipmentList = detail
        } catch {
            guard detailGeneration == request, selectedEquipmentListID == id,
                  !Task.isCancelled, !isCancellation(error) else { return }
            state.listLoadErrorMessage = message(for: error, operation: "加载清单")
        }
    }

    func clearSelectedEquipmentList() {
        guard !isMutating else { return }
        clearSelection()
        clearMutationError()
    }

    func startCreatingList() {
        guard !isMutating else { return }
        state.editing = .create(name: "")
        clearMutationError()
    }

    func startRenamingList(_ list: EquipmentListOverview) {
        guard !isMutating else { return }
        state.editing = .rename(id: list.identity, name: list.name)
        clearMutationError()
    }

    func updateListName(_ value: String) {
        guard !isMutating else { return }
        switch state.editing {
        case .create: state.editing = .create(name: value)
        case let .rename(id, _): state.editing = .rename(id: id, name: value)
        case .none, .deletion: return
        }
        clearMutationError()
    }

    func cancelEditing() {
        guard !isMutating else { return }
        state.editing = .none
        clearMutationError()
    }

    func saveListName() async -> Bool {
        guard state.canSaveListName else { return false }
        let name = state.activeListName.trimmingCharacters(in: .whitespacesAndNewlines)
        switch state.editing {
        case .create:
            return await mutate(intent: .saveName, operation: "创建清单") {
                try await self.service.createEquipmentList(name: name)
            } applyResult: { result in
                self.state.summary = result.personalEquipmentSummary
                self.upsertList(result.equipmentList)
                self.state.editing = .none
            }
        case let .rename(id, _):
            return await mutate(intent: .saveName, operation: "重命名清单") {
                try await self.service.renameEquipmentList(id: id, name: name)
            } applyResult: { result in
                self.acceptList(result.equipmentList, requestedID: id)
                self.state.editing = .none
            }
        case .none, .deletion:
            return false
        }
    }

    func requestDeletion(_ list: EquipmentListOverview) {
        guard !isMutating, !state.isEditingListName else { return }
        state.editing = .deletion(list)
        clearMutationError()
    }

    func deleteEquipmentList(id: String) async -> Bool {
        guard state.deletingList?.identity == id else { return false }
        return await mutate(intent: .deleteList(id: id), operation: "删除清单") {
            try await self.service.deleteEquipmentList(id: id)
        } applyResult: { result in
            self.state.equipmentLists.removeAll { $0.identity == result.deletedEquipmentListId }
            if self.selectedEquipmentListID == result.deletedEquipmentListId { self.clearSelection() }
            self.state.summary = result.personalEquipmentSummary
            self.state.editing = .none
        }
    }

    func putMember(equipmentListID: String, personalEquipmentID: String, quantity: Int) async -> Bool {
        guard state.editing == .none else { return false }
        return await mutate(intent: .updateMember(listID: equipmentListID), operation: "更新清单成员") {
            try await self.service.putListMember(
                equipmentListID: equipmentListID,
                personalEquipmentID: personalEquipmentID,
                quantity: quantity
            )
        } applyResult: { result in
            self.acceptList(result.equipmentList, requestedID: equipmentListID)
        }
    }

    func removeMember(equipmentListID: String, personalEquipmentID: String) async -> Bool {
        guard state.editing == .none else { return false }
        return await mutate(intent: .updateMember(listID: equipmentListID), operation: "移除清单成员") {
            try await self.service.removeListMember(
                equipmentListID: equipmentListID,
                personalEquipmentID: personalEquipmentID
            )
        } applyResult: { result in
            self.acceptList(result.equipmentList, requestedID: equipmentListID)
        }
    }

    func invalidatePendingOperations() {
        loadGeneration += 1
        detailGeneration += 1
        mutationGeneration += 1
        state.isLoading = false
        state.isLoadingEquipmentList = false
        // 响应失效不代表请求结束；running 由实际在途写入的收尾释放。
    }

    private func mutate<Result>(
        intent: EquipmentListState.Intent,
        operation: String,
        request: () async throws -> Result,
        applyResult: (Result) -> Void
    ) async -> Bool {
        guard !isMutating, !Task.isCancelled else { return false }
        // 集合读取会覆盖写入结果；详情读取只在同一清单成功写入时淘汰。
        loadGeneration += 1
        state.isLoading = false
        mutationGeneration += 1
        let requestGeneration = mutationGeneration
        clearMutationError()
        state.operation = .running(intent)
        defer {
            if state.operation == .running(intent) {
                state.operation = .idle
            }
        }
        do {
            let result = try await request()
            guard mutationGeneration == requestGeneration, !Task.isCancelled else { return false }
            applyResult(result)
            return true
        } catch {
            guard mutationGeneration == requestGeneration, !Task.isCancelled, !isCancellation(error) else { return false }
            if case let APIClientError.api(code, _, _, _) = error {
                state.errorCode = code
            }
            state.errorMessage = message(for: error, operation: operation)
            state.operation = .failed(intent)
            return false
        }
    }

    private func clearSelection() {
        detailGeneration += 1
        state.selectedEquipmentListID = nil
        state.selectedEquipmentList = nil
        state.isLoadingEquipmentList = false
        state.listLoadErrorMessage = nil
    }

    private func clearMutationError() {
        state.operation = .idle
        state.errorCode = nil
        state.errorMessage = nil
    }

    private func acceptList(_ detail: EquipmentListDetail, requestedID: String) {
        if selectedEquipmentListID == requestedID {
            detailGeneration += 1
            state.isLoadingEquipmentList = false
            state.listLoadErrorMessage = nil
            state.selectedEquipmentList = detail
        }
        upsertList(detail)
    }

    private func upsertList(_ detail: EquipmentListDetail) {
        let overview = EquipmentListOverview(identity: detail.identity, name: detail.name, summary: detail.summary)
        if let index = state.equipmentLists.firstIndex(where: { $0.identity == detail.identity }) {
            state.equipmentLists[index] = overview
        } else {
            state.equipmentLists.append(overview)
        }
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? APIClientError) == .transport(.cancelled)
    }

    private func message(for error: Error, operation: String) -> String {
        (error as? LocalizedError)?.errorDescription ?? "\(operation)失败：\(error.localizedDescription)"
    }
}
