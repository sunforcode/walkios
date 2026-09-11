import Foundation

protocol EquipmentServicing: AnyObject {
    func getPersonalEquipment() async throws -> PersonalEquipmentCollection
    func createPersonalEquipment(name: String, ownedQuantity: Int, unitWeightGrams: Int?) async throws -> PersonalEquipmentMutation
    func getPersonalEquipment(id: String) async throws -> PersonalEquipment
    func updatePersonalEquipment(id: String, update: PersonalEquipmentUpdate) async throws -> PersonalEquipmentMutation
    func getDeletionImpact(id: String) async throws -> PersonalEquipmentDeletionImpact
    func deletePersonalEquipment(id: String) async throws -> PersonalEquipmentDeletionResult

    func getEquipmentLists() async throws -> EquipmentListCollection
    func createEquipmentList(name: String) async throws -> EquipmentListCreateResult
    func getEquipmentList(id: String) async throws -> EquipmentListDetail
    func renameEquipmentList(id: String, name: String) async throws -> EquipmentListMutation
    func deleteEquipmentList(id: String) async throws -> EquipmentListDeletionResult
    func putListMember(equipmentListID: String, personalEquipmentID: String, quantity: Int) async throws -> EquipmentListMutation
    func removeListMember(equipmentListID: String, personalEquipmentID: String) async throws -> EquipmentListMutation
}

final class EquipmentService: EquipmentServicing {
    private let apiClient: any APIClient

    init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    func getPersonalEquipment() async throws -> PersonalEquipmentCollection {
        try await apiClient.execute(PersonalEquipmentAPI.Collection())
    }

    func createPersonalEquipment(
        name: String,
        ownedQuantity: Int,
        unitWeightGrams: Int?
    ) async throws -> PersonalEquipmentMutation {
        try await apiClient.execute(PersonalEquipmentAPI.Create(
            name: name,
            ownedQuantity: ownedQuantity,
            unitWeightGrams: unitWeightGrams
        ))
    }

    func getPersonalEquipment(id: String) async throws -> PersonalEquipment {
        try await apiClient.execute(PersonalEquipmentAPI.Detail(personalEquipmentID: id))
    }

    func updatePersonalEquipment(
        id: String,
        update: PersonalEquipmentUpdate
    ) async throws -> PersonalEquipmentMutation {
        try await apiClient.execute(PersonalEquipmentAPI.Update(
            personalEquipmentID: id,
            update: update
        ))
    }

    func getDeletionImpact(id: String) async throws -> PersonalEquipmentDeletionImpact {
        try await apiClient.execute(PersonalEquipmentAPI.DeletionImpact(personalEquipmentID: id))
    }

    func deletePersonalEquipment(id: String) async throws -> PersonalEquipmentDeletionResult {
        try await apiClient.execute(PersonalEquipmentAPI.Delete(personalEquipmentID: id))
    }

    func getEquipmentLists() async throws -> EquipmentListCollection {
        try await apiClient.execute(EquipmentListAPI.Collection())
    }

    func createEquipmentList(name: String) async throws -> EquipmentListCreateResult {
        try await apiClient.execute(EquipmentListAPI.Create(name: name))
    }

    func getEquipmentList(id: String) async throws -> EquipmentListDetail {
        try await apiClient.execute(EquipmentListAPI.Detail(equipmentListID: id))
    }

    func renameEquipmentList(id: String, name: String) async throws -> EquipmentListMutation {
        try await apiClient.execute(EquipmentListAPI.Rename(equipmentListID: id, name: name))
    }

    func deleteEquipmentList(id: String) async throws -> EquipmentListDeletionResult {
        try await apiClient.execute(EquipmentListAPI.Delete(equipmentListID: id))
    }

    func putListMember(
        equipmentListID: String,
        personalEquipmentID: String,
        quantity: Int
    ) async throws -> EquipmentListMutation {
        try await apiClient.execute(EquipmentListAPI.PutMember(
            equipmentListID: equipmentListID,
            personalEquipmentID: personalEquipmentID,
            quantity: quantity
        ))
    }

    func removeListMember(
        equipmentListID: String,
        personalEquipmentID: String
    ) async throws -> EquipmentListMutation {
        try await apiClient.execute(EquipmentListAPI.DeleteMember(
            equipmentListID: equipmentListID,
            personalEquipmentID: personalEquipmentID
        ))
    }
}
