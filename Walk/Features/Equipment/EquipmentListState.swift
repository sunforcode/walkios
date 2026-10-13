import Foundation
import WalkData

struct EquipmentListState {
    enum Editing: Equatable {
        case none
        case create(name: String)
        case rename(id: String, name: String)
        case deletion(EquipmentListOverview)
    }

    enum Intent: Equatable {
        case saveName
        case deleteList(id: String)
        case updateMember(listID: String)
    }

    enum Operation: Equatable {
        case idle
        case running(Intent)
        case failed(Intent)
    }

    var items: [PersonalEquipment] = []
    var equipmentLists: [EquipmentListOverview] = []
    var summary: PersonalEquipmentSummary?
    var isLoading = false
    var loadErrorMessage: String?
    var selectedEquipmentListID: String?
    var selectedEquipmentList: EquipmentListDetail?
    var isLoadingEquipmentList = false
    var listLoadErrorMessage: String?
    var editing: Editing = .none
    var operation: Operation = .idle
    var errorCode: String?
    var errorMessage: String?

    func showsPrimaryAction(isEquipmentSection: Bool) -> Bool {
        // 手动新增不依赖装备或清单读取成功；读取状态只替换内容区。
        if isEquipmentSection { return true }
        let hasNoLoadedContent = items.isEmpty && equipmentLists.isEmpty
        return !(isLoading && hasNoLoadedContent)
            && !(loadErrorMessage != nil && hasNoLoadedContent)
    }

    var isMutating: Bool {
        if case .running = operation { return true }
        return false
    }

    var isEditingListName: Bool {
        switch editing {
        case .create, .rename: return true
        case .none, .deletion: return false
        }
    }

    var isRenamingList: Bool {
        if case .rename = editing { return true }
        return false
    }

    var activeListName: String {
        switch editing {
        case let .create(name), let .rename(_, name): return name
        case .none, .deletion: return ""
        }
    }

    var canSaveListName: Bool {
        isEditingListName && !activeListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isMutating
    }

    var listNameFieldError: String? {
        guard !activeListName.isEmpty,
              activeListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return "请输入清单名称"
    }

    var listNameSaveError: String? {
        operation == .failed(.saveName) ? errorMessage : nil
    }

    var failedListID: String? {
        if case let .failed(.updateMember(listID)) = operation { return listID }
        return nil
    }

    var deletingList: EquipmentListOverview? {
        if case let .deletion(list) = editing { return list }
        return nil
    }

    var listDeletionMessage: String {
        let impact = "只会删除这份清单和成员关系，不会删除任何个人装备。"
        if let deletingList, operation == .failed(.deleteList(id: deletingList.identity)), let errorMessage {
            return "\(impact) 删除失败：\(errorMessage)"
        }
        return impact
    }
}
