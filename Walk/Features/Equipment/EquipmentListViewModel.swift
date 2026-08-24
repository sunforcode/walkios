import SwiftUI

/// 装备清单 ViewModel
@MainActor
final class EquipmentListViewModel: ObservableObject {
    @Published var checklist: EquipmentChecklist?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedTripId: String?
    @Published var checkedItems: Set<String> = []

    private let service = EquipmentService()

    /// 加载装备清单
    func loadChecklist(tripId: String? = nil) async {
        isLoading = true
        errorMessage = nil

        do {
            if let id = tripId ?? selectedTripId {
                checklist = try await service.getChecklist(tripId: id)
                checkedItems = Set(checklist?.items.filter { $0.isChecked == true }.map { $0.id } ?? [])
            } else {
                // 加载推荐装备（无特定行程）
                let recommended = try await service.getRecommendedEquipment(routeId: "default")
                checklist = EquipmentChecklist(tripId: nil, items: recommended, createdAt: nil, updatedAt: nil)
                checkedItems = []
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch let error as NetworkError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "加载失败：\(error.localizedDescription)"
        }

        isLoading = false
    }

    /// 切换装备勾选状态
    func toggleCheck(equipmentId: String) async {
        let newState = !checkedItems.contains(equipmentId)

        // 乐观更新
        if newState {
            checkedItems.insert(equipmentId)
        } else {
            checkedItems.remove(equipmentId)
        }

        // 同步到后端
        do {
            _ = try await service.updateCheckStatus(equipmentId: equipmentId, isChecked: newState)
        } catch {
            // 失败时回滚
            if newState {
                checkedItems.remove(equipmentId)
            } else {
                checkedItems.insert(equipmentId)
            }
            errorMessage = "更新失败"
        }
    }

    /// 全选/取消全选
    func toggleAll(in category: EquipmentCategory) async {
        let categoryItems = checklist?.items.filter { $0.category == category } ?? []
        let categoryIds = Set(categoryItems.map { $0.id })
        let allSelected = categoryIds.isSubset(of: checkedItems)

        if allSelected {
            // 取消全选
            checkedItems.subtract(categoryIds)
        } else {
            // 全选
            checkedItems.formUnion(categoryIds)
        }

        // 同步到后端
        do {
            _ = try await service.batchUpdateCheckStatus(
                ids: Array(categoryIds),
                isChecked: !allSelected
            )
        } catch {
            // 回滚
            if allSelected {
                checkedItems.formUnion(categoryIds)
            } else {
                checkedItems.subtract(categoryIds)
            }
            errorMessage = "批量更新失败"
        }
    }

    /// 计算完成进度
    var progress: Double {
        guard let items = checklist?.items, !items.isEmpty else { return 0 }
        return Double(checkedItems.count) / Double(items.count)
    }

    /// 勾选数量
    var checkedCount: Int {
        checkedItems.count
    }

    /// 总数量
    var totalCount: Int {
        checklist?.items.count ?? 0
    }
}
