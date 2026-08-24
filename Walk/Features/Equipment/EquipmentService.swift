import Foundation

/// 装备服务
/// Debug 模式下返回 Mock 数据，Release 模式调用真实 API
final class EquipmentService {
    private let client = LegacyAPIClient.shared

    /// 获取装备清单
    func getChecklist(tripId: String) async throws -> EquipmentChecklist {
        #if DEBUG
            try await Task.sleep(nanoseconds: 300_000_000)
            return MockData.equipmentChecklist
        #else
            let checklist: EquipmentChecklist = try await client.request(
                APIEndpoints.equipment,
                method: .get,
                parameters: ["trip_id": tripId]
            )
            return checklist
        #endif
    }

    /// 获取推荐装备
    func getRecommendedEquipment(routeId: String) async throws -> [Equipment] {
        #if DEBUG
            try await Task.sleep(nanoseconds: 300_000_000)
            return MockData.equipment
        #else
            let equipment: [Equipment] = try await client.request(
                APIEndpoints.equipment,
                method: .get,
                parameters: ["route_id": routeId]
            )
            return equipment
        #endif
    }

    /// 更新装备勾选状态
    func updateCheckStatus(equipmentId: String, isChecked: Bool) async throws -> Equipment {
        #if DEBUG
            try await Task.sleep(nanoseconds: 200_000_000)
            return MockData.equipment.first(where: { $0.id == equipmentId }) ?? Equipment(
                id: equipmentId, name: nil, category: nil, weight: nil, quantity: nil,
                isChecked: isChecked, description: nil, createdAt: nil
            )
        #else
            let equipment: Equipment = try await client.request(
                "/equipment/\(equipmentId)",
                method: .patch,
                parameters: ["is_checked": isChecked]
            )
            return equipment
        #endif
    }

    /// 批量更新装备状态
    func batchUpdateCheckStatus(ids: [String], isChecked: Bool) async throws -> [Equipment] {
        #if DEBUG
            try await Task.sleep(nanoseconds: 200_000_000)
            return MockData.equipment.filter { ids.contains($0.id) }
        #else
            let equipment: [Equipment] = try await client.request(
                "/equipment/batch",
                method: .patch,
                parameters: ["ids": ids, "is_checked": isChecked]
            )
            return equipment
        #endif
    }
}
