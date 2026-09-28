import Foundation

public protocol EquipmentServicing: AnyObject {
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

public protocol PersonalEquipmentManaging: EquipmentServicing {
    func getPersonalEquipment(filter: PersonalEquipmentFilter) async throws -> PersonalEquipmentCollection
    func createPersonalEquipment(input: PersonalEquipmentCreateRequest) async throws -> PersonalEquipmentMutation
    func createPersonalEquipmentFromCatalog(
        input: PersonalEquipmentFromCatalogRequest,
        idempotencyKey: String
    ) async throws -> PersonalEquipmentMutation
    func copyEquipmentList(id: String, name: String, idempotencyKey: String) async throws -> EquipmentListCreateResult
}

public final class EquipmentService: PersonalEquipmentManaging {
    private let apiClient: any APIClient

     public init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

     public func getPersonalEquipment() async throws -> PersonalEquipmentCollection {
        try await apiClient.execute(PersonalEquipmentAPI.Collection())
    }

    public func getPersonalEquipment(filter: PersonalEquipmentFilter) async throws -> PersonalEquipmentCollection {
        try await apiClient.execute(PersonalEquipmentAPI.Collection(filter: filter))
    }

    public func createPersonalEquipment(input: PersonalEquipmentCreateRequest) async throws -> PersonalEquipmentMutation {
        try await apiClient.execute(PersonalEquipmentAPI.Create(input: input))
    }

    public func createPersonalEquipmentFromCatalog(
        input: PersonalEquipmentFromCatalogRequest,
        idempotencyKey: String
    ) async throws -> PersonalEquipmentMutation {
        try await apiClient.execute(PersonalEquipmentAPI.FromCatalog(input: input, idempotencyKey: idempotencyKey))
    }

     public func createPersonalEquipment(
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

     public func getPersonalEquipment(id: String) async throws -> PersonalEquipment {
        try await apiClient.execute(PersonalEquipmentAPI.Detail(personalEquipmentID: id))
    }

     public func updatePersonalEquipment(
        id: String,
        update: PersonalEquipmentUpdate
    ) async throws -> PersonalEquipmentMutation {
        try await apiClient.execute(PersonalEquipmentAPI.Update(
            personalEquipmentID: id,
            update: update
        ))
    }

     public func getDeletionImpact(id: String) async throws -> PersonalEquipmentDeletionImpact {
        try await apiClient.execute(PersonalEquipmentAPI.DeletionImpact(personalEquipmentID: id))
    }

     public func deletePersonalEquipment(id: String) async throws -> PersonalEquipmentDeletionResult {
        try await apiClient.execute(PersonalEquipmentAPI.Delete(personalEquipmentID: id))
    }

     public func getEquipmentLists() async throws -> EquipmentListCollection {
        try await apiClient.execute(EquipmentListAPI.Collection())
    }

     public func createEquipmentList(name: String) async throws -> EquipmentListCreateResult {
        try await apiClient.execute(EquipmentListAPI.Create(name: name))
    }

    public func copyEquipmentList(
        id: String,
        name: String,
        idempotencyKey: String
    ) async throws -> EquipmentListCreateResult {
        try await apiClient.execute(EquipmentListAPI.Copy(
            equipmentListID: id,
            name: name,
            idempotencyKey: idempotencyKey
        ))
    }

     public func getEquipmentList(id: String) async throws -> EquipmentListDetail {
        try await apiClient.execute(EquipmentListAPI.Detail(equipmentListID: id))
    }

     public func renameEquipmentList(id: String, name: String) async throws -> EquipmentListMutation {
        try await apiClient.execute(EquipmentListAPI.Rename(equipmentListID: id, name: name))
    }

     public func deleteEquipmentList(id: String) async throws -> EquipmentListDeletionResult {
        try await apiClient.execute(EquipmentListAPI.Delete(equipmentListID: id))
    }

     public func putListMember(
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

     public func removeListMember(
        equipmentListID: String,
        personalEquipmentID: String
    ) async throws -> EquipmentListMutation {
        try await apiClient.execute(EquipmentListAPI.DeleteMember(
            equipmentListID: equipmentListID,
            personalEquipmentID: personalEquipmentID
        ))
    }
}
