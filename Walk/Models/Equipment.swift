import Foundation

/// 装备模型
struct Equipment: Codable, Identifiable, Equatable {
    let id: String
    let name: String?
    let category: EquipmentCategory?
    let weight: Double?
    let quantity: Int?
    let isChecked: Bool?
    let description: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case weight
        case quantity
        case isChecked = "is_checked"
        case description
        case createdAt = "created_at"
    }

    /// 重量描述
    var weightDescription: String {
        guard let weight = weight else { return "" }
        return weight >= 1000 ? String(format: "%.1f kg", weight / 1000) : String(format: "%.0f g", weight)
    }

    /// 数量描述
    var quantityDescription: String {
        guard let quantity = quantity else { return "" }
        return "×\(quantity)"
    }
}

/// 装备分类
enum EquipmentCategory: String, Codable, CaseIterable {
    case clothing = "clothing"
    case footwear = "footwear"
    case shelter = "shelter"
    case cooking = "cooking"
    case navigation = "navigation"
    case safety = "safety"
    case electronics = "electronics"
    case personal = "personal"
    case other = "other"

    var displayName: String {
        switch self {
        case .clothing: return "服装"
        case .footwear: return "鞋靴"
        case .shelter: return "帐篷/庇护"
        case .cooking: return "炊具"
        case .navigation: return "导航"
        case .safety: return "安全/急救"
        case .electronics: return "电子设备"
        case .personal: return "个人用品"
        case .other: return "其他"
        }
    }

    var icon: String {
        switch self {
        case .clothing: return "tshirt"
        case .footwear: return "shoe"
        case .shelter: return "tent"
        case .cooking: return "flame"
        case .navigation: return "location"
        case .safety: return "cross.case"
        case .electronics: return "bolt"
        case .personal: return "person"
        case .other: return "bag"
        }
    }
}

/// 装备清单（按分类分组）
struct EquipmentChecklist: Codable {
    let tripId: String?
    let items: [Equipment]
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case items
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// 按分类分组
    func groupedByCategory() -> [(EquipmentCategory, [Equipment])] {
        var grouped: [EquipmentCategory: [Equipment]] = [:]
        for item in items {
            let cat = item.category ?? .other
            grouped[cat, default: []].append(item)
        }
        return grouped.sorted { $0.key.rawValue < $1.key.rawValue }
    }
}
