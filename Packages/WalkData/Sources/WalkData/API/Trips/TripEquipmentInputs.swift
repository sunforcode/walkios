import Foundation

/// 新增请求只表达可编辑字段；不接受来源、汇总或打包状态。
public struct TripEquipmentItemCreate: Encodable, Equatable {
    public let name: String
    public let quantity: Int
    public let unitWeight: EquipmentWeight?
    public let note: String?
    public let category: CatalogEquipmentCategory?
    public let equipmentType: CatalogEquipmentType?
    public let variant: String?
    public let unitLabel: EquipmentUnitLabel?
    public let weightScope: String?
    public let carryAllocation: TripCarryAllocation?
    public let supply: TripSupply?

    public init(
        name: String,
        quantity: Int,
        unitWeight: EquipmentWeight? = nil,
        note: String? = nil,
        category: CatalogEquipmentCategory? = nil,
        equipmentType: CatalogEquipmentType? = nil,
        variant: String? = nil,
        unitLabel: EquipmentUnitLabel? = nil,
        weightScope: String? = nil,
        carryAllocation: TripCarryAllocation? = nil,
        supply: TripSupply? = nil
    ) {
        self.name = name
        self.quantity = quantity
        self.unitWeight = unitWeight
        self.note = note
        self.category = category
        self.equipmentType = equipmentType
        self.variant = variant
        self.unitLabel = unitLabel
        self.weightScope = weightScope
        self.carryAllocation = carryAllocation
        self.supply = supply
    }
}

public enum TripEquipmentUpdateField<Value: Encodable & Equatable>: Encodable, Equatable {
    case unchanged
    case value(Value)
    case clear

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .unchanged, .clear:
            try container.encodeNil()
        case .value(let value):
            try container.encode(value)
        }
    }
}

/// 可选字段区分省略、替换和清除；嵌套对象整体替换。
public struct TripEquipmentItemUpdate: Encodable, Equatable {
    public let name: String?
    public let quantity: Int?
    public let unitWeight: TripEquipmentUpdateField<EquipmentWeight>
    public let note: TripEquipmentUpdateField<String>
    public let category: TripEquipmentUpdateField<CatalogEquipmentCategory>
    public let equipmentType: TripEquipmentUpdateField<CatalogEquipmentType>
    public let variant: TripEquipmentUpdateField<String>
    public let unitLabel: TripEquipmentUpdateField<EquipmentUnitLabel>
    public let weightScope: TripEquipmentUpdateField<String>
    public let carryAllocation: TripEquipmentUpdateField<TripCarryAllocation>
    public let supply: TripEquipmentUpdateField<TripSupply>

    public init(
        name: String? = nil,
        quantity: Int? = nil,
        unitWeight: TripEquipmentUpdateField<EquipmentWeight> = .unchanged,
        note: TripEquipmentUpdateField<String> = .unchanged,
        category: TripEquipmentUpdateField<CatalogEquipmentCategory> = .unchanged,
        equipmentType: TripEquipmentUpdateField<CatalogEquipmentType> = .unchanged,
        variant: TripEquipmentUpdateField<String> = .unchanged,
        unitLabel: TripEquipmentUpdateField<EquipmentUnitLabel> = .unchanged,
        weightScope: TripEquipmentUpdateField<String> = .unchanged,
        carryAllocation: TripEquipmentUpdateField<TripCarryAllocation> = .unchanged,
        supply: TripEquipmentUpdateField<TripSupply> = .unchanged
    ) {
        self.name = name
        self.quantity = quantity
        self.unitWeight = unitWeight
        self.note = note
        self.category = category
        self.equipmentType = equipmentType
        self.variant = variant
        self.unitLabel = unitLabel
        self.weightScope = weightScope
        self.carryAllocation = carryAllocation
        self.supply = supply
    }

    var requiresRevision: Bool {
        category != .unchanged ||
        equipmentType != .unchanged ||
        variant != .unchanged ||
        unitLabel != .unchanged ||
        weightScope != .unchanged ||
        carryAllocation != .unchanged ||
        supply != .unchanged
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name { try container.encode(name, forKey: .name) }
        if let quantity { try container.encode(quantity, forKey: .quantity) }
        if unitWeight != .unchanged { try container.encode(unitWeight, forKey: .unitWeight) }
        if note != .unchanged { try container.encode(note, forKey: .note) }
        if category != .unchanged { try container.encode(category, forKey: .category) }
        if equipmentType != .unchanged { try container.encode(equipmentType, forKey: .equipmentType) }
        if variant != .unchanged { try container.encode(variant, forKey: .variant) }
        if unitLabel != .unchanged { try container.encode(unitLabel, forKey: .unitLabel) }
        if weightScope != .unchanged { try container.encode(weightScope, forKey: .weightScope) }
        if carryAllocation != .unchanged { try container.encode(carryAllocation, forKey: .carryAllocation) }
        if supply != .unchanged { try container.encode(supply, forKey: .supply) }
    }

    private enum CodingKeys: String, CodingKey {
        case name, quantity, unitWeight, note
        case category, equipmentType, variant, unitLabel, weightScope, carryAllocation, supply
    }
}
