import SwiftUI

@MainActor
final class EquipmentListViewModel: ObservableObject {
    @Published var items: [PersonalEquipment] = []
    @Published var equipmentLists: [EquipmentListOverview] = []
    @Published var summary: PersonalEquipmentSummary?
    @Published var selectedEquipmentList: EquipmentListDetail?
    @Published var editingEquipment: PersonalEquipment?
    @Published var deletionImpact: PersonalEquipmentDeletionImpact?
    @Published var lastMutationSucceeded = false
    @Published var isLoading = false
    @Published var isMutating = false
    @Published var errorMessage: String?

    private let service: any EquipmentServicing

    init(service: any EquipmentServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let equipment = try await service.getPersonalEquipment()
            let lists = try await service.getEquipmentLists()
            items = equipment.items
            summary = equipment.summary
            equipmentLists = lists.items
        } catch {
            errorMessage = message(for: error, operation: "加载")
        }
    }

    func loadEquipment(id: String) async {
        await mutate(operation: "加载") {
            editingEquipment = try await service.getPersonalEquipment(id: id)
        }
    }

    func createEquipment(name: String, ownedQuantity: Int, unitWeightGrams: Int?) async {
        await mutate(operation: "添加") {
            let result = try await service.createPersonalEquipment(
                name: name,
                ownedQuantity: ownedQuantity,
                unitWeightGrams: unitWeightGrams
            )
            upsert(result.item)
            summary = result.summary
        }
    }

    func updateEquipment(id: String, update: PersonalEquipmentUpdate) async {
        await mutate(operation: "更新") {
            let result = try await service.updatePersonalEquipment(id: id, update: update)
            upsert(result.item)
            editingEquipment = result.item
            summary = result.summary
            replaceMemberProjection(for: result.item)
        }
    }

    func loadDeletionImpact(id: String) async {
        await mutate(operation: "读取删除影响") {
            deletionImpact = try await service.getDeletionImpact(id: id)
        }
    }

    func deleteEquipment(id: String) async {
        await mutate(operation: "删除") {
            let result = try await service.deletePersonalEquipment(id: id)
            items.removeAll { $0.identity == result.deletedPersonalEquipmentId }
            editingEquipment = nil
            summary = result.summary
            deletionImpact = nil
            selectedEquipmentList = nil
        }
    }

    func loadEquipmentList(id: String) async {
        await mutate(operation: "加载清单") {
            selectedEquipmentList = try await service.getEquipmentList(id: id)
        }
    }

    func createEquipmentList(name: String) async {
        await mutate(operation: "创建清单") {
            let result = try await service.createEquipmentList(name: name)
            selectedEquipmentList = result.equipmentList
            summary = result.personalEquipmentSummary
            upsertList(result.equipmentList)
        }
    }

    func renameEquipmentList(id: String, name: String) async {
        await mutate(operation: "重命名清单") {
            let result = try await service.renameEquipmentList(id: id, name: name)
            selectedEquipmentList = result.equipmentList
            upsertList(result.equipmentList)
        }
    }

    func deleteEquipmentList(id: String) async {
        await mutate(operation: "删除清单") {
            let result = try await service.deleteEquipmentList(id: id)
            equipmentLists.removeAll { $0.identity == result.deletedEquipmentListId }
            if selectedEquipmentList?.identity == id { selectedEquipmentList = nil }
            summary = result.personalEquipmentSummary
        }
    }

    func putMember(equipmentListID: String, personalEquipmentID: String, quantity: Int) async {
        await mutate(operation: "更新清单成员") {
            let result = try await service.putListMember(
                equipmentListID: equipmentListID,
                personalEquipmentID: personalEquipmentID,
                quantity: quantity
            )
            selectedEquipmentList = result.equipmentList
            upsertList(result.equipmentList)
        }
    }

    func removeMember(equipmentListID: String, personalEquipmentID: String) async {
        await mutate(operation: "移除清单成员") {
            let result = try await service.removeListMember(
                equipmentListID: equipmentListID,
                personalEquipmentID: personalEquipmentID
            )
            selectedEquipmentList = result.equipmentList
            upsertList(result.equipmentList)
        }
    }

    private func mutate(operation: String, action: () async throws -> Void) async {
        isMutating = true
        errorMessage = nil
        lastMutationSucceeded = false
        defer { isMutating = false }

        do {
            try await action()
            lastMutationSucceeded = true
        } catch {
            errorMessage = message(for: error, operation: operation)
        }
    }

    private func upsert(_ item: PersonalEquipment) {
        if let index = items.firstIndex(where: { $0.identity == item.identity }) {
            items[index] = item
        } else {
            items.append(item)
        }
    }

    private func upsertList(_ detail: EquipmentListDetail) {
        let overview = EquipmentListOverview(
            identity: detail.identity,
            name: detail.name,
            summary: detail.summary
        )
        if let index = equipmentLists.firstIndex(where: { $0.identity == detail.identity }) {
            equipmentLists[index] = overview
        } else {
            equipmentLists.append(overview)
        }
    }

    private func replaceMemberProjection(for item: PersonalEquipment) {
        guard let selectedEquipmentList,
              let memberIndex = selectedEquipmentList.members.firstIndex(where: { $0.identity == item.identity }) else {
            return
        }
        var members = selectedEquipmentList.members
        let current = members[memberIndex]
        members[memberIndex] = EquipmentListMember(
            identity: item.identity,
            name: item.name,
            ownedQuantity: item.ownedQuantity,
            unitWeight: item.unitWeight,
            quantity: current.quantity
        )
        self.selectedEquipmentList = EquipmentListDetail(
            identity: selectedEquipmentList.identity,
            name: selectedEquipmentList.name,
            members: members,
            summary: selectedEquipmentList.summary
        )
    }

    private func message(for error: Error, operation: String) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "\(operation)失败：\(error.localizedDescription)"
    }
}
