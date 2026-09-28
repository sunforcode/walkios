import Foundation

public protocol EquipmentCatalogServicing: AnyObject {
    func getBrands() async throws -> EquipmentBrandCollection
    func getEquipment(filter: EquipmentCatalogFilter) async throws -> CatalogEquipmentCollection
    func getEquipment(id: String) async throws -> CatalogEquipmentDetail
}

public final class EquipmentCatalogService: EquipmentCatalogServicing {
    private let apiClient: any APIClient

    public init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    public func getBrands() async throws -> EquipmentBrandCollection {
        try await apiClient.execute(EquipmentCatalogAPI.Brands())
    }

    public func getEquipment(filter: EquipmentCatalogFilter = .init()) async throws -> CatalogEquipmentCollection {
        try await apiClient.execute(EquipmentCatalogAPI.Items(filter: filter))
    }

    public func getEquipment(id: String) async throws -> CatalogEquipmentDetail {
        try await apiClient.execute(EquipmentCatalogAPI.Detail(equipmentID: id))
    }
}
