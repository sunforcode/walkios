import Foundation

public protocol TripEquipmentServicing {
    func getEquipment(tripID: String) async throws -> TripEquipmentProjection
    func addItem(
        tripID: String,
        name: String,
        quantity: Int,
        unitWeightGrams: Int?,
        note: String?
    ) async throws -> TripEquipmentProjection
    func updateItem(
        tripID: String,
        itemID: String,
        update: TripEquipmentItemUpdate
    ) async throws -> TripEquipmentProjection
    func deleteItem(tripID: String, itemID: String) async throws -> TripEquipmentProjection
    func recheckOwnership(tripID: String) async throws -> TripEquipmentProjection
}

/// 准备能力单独扩展，既有页面和测试替身仍可只实现旧协议。
public protocol TripEquipmentPreparing: TripEquipmentServicing {
    func getPreparation(tripID: String) async throws -> TripEquipmentPreparation
    func addItem(tripID: String, input: TripEquipmentItemCreate, revision: String) async throws -> TripEquipmentProjection
    func updateItem(tripID: String, itemID: String, update: TripEquipmentItemUpdate, revision: String) async throws -> TripEquipmentProjection
    func deleteItem(tripID: String, itemID: String, revision: String) async throws -> TripEquipmentProjection
    func recheckOwnership(tripID: String, revision: String) async throws -> TripEquipmentProjection
    func addFromPersonal(tripID: String, personalEquipmentID: String, quantity: Int, revision: String, idempotencyKey: String) async throws -> TripEquipmentProjection
    func appendList(tripID: String, equipmentListID: String, revision: String, idempotencyKey: String) async throws -> TripEquipmentProjection
    func replaceWithPersonal(tripID: String, itemID: String, personalEquipmentID: String, quantity: Int, revision: String) async throws -> TripEquipmentProjection
    func setPacking(tripID: String, itemID: String, packedQuantity: Int, revision: String) async throws -> TripEquipmentProjection
    func resetPacking(tripID: String, revision: String) async throws -> TripEquipmentProjection
}

public struct TripEquipmentService: TripEquipmentPreparing {
     public let apiClient: any APIClient

     public func getEquipment(tripID: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.Current(tripID: tripID))
    }

     public func addItem(
        tripID: String,
        name: String,
        quantity: Int,
        unitWeightGrams: Int?,
        note: String?
    ) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.CreateItem(
            tripID: tripID,
            name: name,
            quantity: quantity,
            unitWeightGrams: unitWeightGrams,
            note: note
        ))
    }

     public func updateItem(
        tripID: String,
        itemID: String,
        update: TripEquipmentItemUpdate
    ) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.UpdateItem(
            tripID: tripID,
            itemID: itemID,
            update: update
        ))
    }

     public func deleteItem(tripID: String, itemID: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.DeleteItem(tripID: tripID, itemID: itemID))
    }

     public func recheckOwnership(tripID: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.RecheckOwnership(tripID: tripID))
    }

    public init(
        apiClient: any APIClient
    ) {
        self.apiClient = apiClient
    }
}


public extension TripEquipmentService {
    func getPreparation(tripID: String) async throws -> TripEquipmentPreparation {
        try await apiClient.execute(TripEquipmentAPI.Preparation(tripID: tripID))
    }

    func addItem(tripID: String, input: TripEquipmentItemCreate, revision: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.CreateItem(tripID: tripID, input: input, revision: revision))
    }

    func updateItem(tripID: String, itemID: String, update: TripEquipmentItemUpdate, revision: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.UpdateItem(tripID: tripID, itemID: itemID, update: update, revision: revision))
    }

    func deleteItem(tripID: String, itemID: String, revision: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.DeleteItem(tripID: tripID, itemID: itemID, revision: revision))
    }

    func recheckOwnership(tripID: String, revision: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.RecheckOwnership(tripID: tripID, revision: revision))
    }

    func addFromPersonal(tripID: String, personalEquipmentID: String, quantity: Int, revision: String, idempotencyKey: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.FromPersonal(tripID: tripID, personalEquipmentID: personalEquipmentID, quantity: quantity, revision: revision, idempotencyKey: idempotencyKey))
    }

    func appendList(tripID: String, equipmentListID: String, revision: String, idempotencyKey: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.AppendList(tripID: tripID, equipmentListID: equipmentListID, revision: revision, idempotencyKey: idempotencyKey))
    }

    func replaceWithPersonal(tripID: String, itemID: String, personalEquipmentID: String, quantity: Int, revision: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.ReplaceWithPersonal(tripID: tripID, itemID: itemID, personalEquipmentID: personalEquipmentID, quantity: quantity, revision: revision))
    }

    func setPacking(tripID: String, itemID: String, packedQuantity: Int, revision: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.SetPacking(tripID: tripID, itemID: itemID, packedQuantity: packedQuantity, revision: revision))
    }

    func resetPacking(tripID: String, revision: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.ResetPacking(tripID: tripID, revision: revision))
    }
}
