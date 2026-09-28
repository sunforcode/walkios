import Foundation

public struct TripCarryAllocation: Codable, Equatable {
    public let backpackQuantity: Int
    public let wornQuantity: Int
    public let handheldQuantity: Int

    public init(backpackQuantity: Int, wornQuantity: Int, handheldQuantity: Int) {
        self.backpackQuantity = backpackQuantity
        self.wornQuantity = wornQuantity
        self.handheldQuantity = handheldQuantity
    }
}

public enum TripSupplyKind: String, Codable, Equatable {
    case food
    case drinkingWater = "drinking_water"
    case fuel
}

public enum TripSupplyAmountUnit: String, Codable, Equatable {
    case gram, milliliter, portion
}

public enum TripSupplyContainerMode: String, Codable, Equatable {
    case included, excluded
}

public struct TripSupplyAmount: Codable, Equatable {
    public let value: Double
    public let unit: TripSupplyAmountUnit

    public init(value: Double, unit: TripSupplyAmountUnit) {
        self.value = value
        self.unit = unit
    }
}

public struct TripSupply: Codable, Equatable {
    public let kind: TripSupplyKind
    public let amount: TripSupplyAmount
    public let containerMode: TripSupplyContainerMode

    public init(kind: TripSupplyKind, amount: TripSupplyAmount, containerMode: TripSupplyContainerMode) {
        self.kind = kind
        self.amount = amount
        self.containerMode = containerMode
    }
}

public struct EquipmentWeightBucket: Codable, Equatable {
    public let knownWeight: EquipmentWeight
    public let missingWeightItemCount: Int

    public init(knownWeight: EquipmentWeight, missingWeightItemCount: Int) {
        self.knownWeight = knownWeight
        self.missingWeightItemCount = missingWeightItemCount
    }
}

public struct TripEquipmentWeightBreakdown: Codable, Equatable {
    public let backpack: EquipmentWeightBucket
    public let worn: EquipmentWeightBucket
    public let handheld: EquipmentWeightBucket
    public let unallocated: EquipmentWeightBucket

    public init(backpack: EquipmentWeightBucket, worn: EquipmentWeightBucket, handheld: EquipmentWeightBucket, unallocated: EquipmentWeightBucket) {
        self.backpack = backpack
        self.worn = worn
        self.handheld = handheld
        self.unallocated = unallocated
    }
}

public struct TripEquipmentBackpackBreakdown: Codable, Equatable {
    public let equipment: EquipmentWeightBucket
    public let food: EquipmentWeightBucket
    public let drinkingWater: EquipmentWeightBucket
    public let fuel: EquipmentWeightBucket
    public let unclassified: EquipmentWeightBucket

    public init(equipment: EquipmentWeightBucket, food: EquipmentWeightBucket, drinkingWater: EquipmentWeightBucket, fuel: EquipmentWeightBucket, unclassified: EquipmentWeightBucket) {
        self.equipment = equipment
        self.food = food
        self.drinkingWater = drinkingWater
        self.fuel = fuel
        self.unclassified = unclassified
    }
}

public struct TripEquipmentPacking: Codable, Equatable {
    public let backpackQuantity: Int
    public let packedQuantity: Int
    public let unpackedQuantity: Int
    public let unallocatedItemCount: Int

    public init(backpackQuantity: Int, packedQuantity: Int, unpackedQuantity: Int, unallocatedItemCount: Int) {
        self.backpackQuantity = backpackQuantity
        self.packedQuantity = packedQuantity
        self.unpackedQuantity = unpackedQuantity
        self.unallocatedItemCount = unallocatedItemCount
    }
}

/// 服务端在同一 revision 下返回的分项事实；客户端不从条目重算或补零。
public struct TripEquipmentPreparation: Codable, Equatable {
    public let tripID: String
    public let revision: String
    public let weightBreakdown: TripEquipmentWeightBreakdown
    public let backpackBreakdown: TripEquipmentBackpackBreakdown
    public let packing: TripEquipmentPacking

    public enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case revision, weightBreakdown, backpackBreakdown, packing
    }

    public init(tripID: String, revision: String, weightBreakdown: TripEquipmentWeightBreakdown, backpackBreakdown: TripEquipmentBackpackBreakdown, packing: TripEquipmentPacking) {
        self.tripID = tripID
        self.revision = revision
        self.weightBreakdown = weightBreakdown
        self.backpackBreakdown = backpackBreakdown
        self.packing = packing
    }
}
