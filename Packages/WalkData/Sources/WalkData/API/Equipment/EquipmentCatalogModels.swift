import Foundation

/// Wire values owned by docs/data/equipment-schema.md.
public enum CatalogEquipmentCategory: String, Codable, CaseIterable {
    case backpack
    case tent
    case sleeping
    case clothing
    case hikingFootwear = "hiking_footwear"
    case walkingAids = "walking_aids"
    case campEssentials = "camp_essentials"
    case diningEquipment = "dining_equipment"
    case navigationCommunication = "navigation_communication"
    case lightingPower = "lighting_power"
    case safetyEmergency = "safety_emergency"
    case hygieneCare = "hygiene_care"
    case miscellaneous
    case food
    case drinkingWater = "drinking_water"
    case fuel
}

public enum CatalogEquipmentType: String, Codable, CaseIterable {
    case backpack
    case tent
    case sleepingBag = "sleeping_bag"
    case sleepingPad = "sleeping_pad"
    case backpackRainCover = "backpack_rain_cover"
    case groundsheet
    case tentPeg = "tent_peg"
    case sleepingQuilt = "sleeping_quilt"
    case pillow
    case sleepingBagLiner = "sleeping_bag_liner"
    case clothing
    case socks
    case hat
    case gloves
    case sunglasses
    case hikingShoes = "hiking_shoes"
    case trekkingPole = "trekking_pole"
    case crampon
    case tractionChain = "traction_chain"
    case snowshoe
    case riverCrossingShoes = "river_crossing_shoes"
    case campShoes = "camp_shoes"
    case campChair = "camp_chair"
    case campTable = "camp_table"
    case sitPad = "sit_pad"
    case tarp
    case stove
    case cookware
    case tableware
    case waterBottle = "water_bottle"
    case hydrationReservoir = "hydration_reservoir"
    case waterFilter = "water_filter"
    case storageBag = "storage_bag"
    case map
    case compass
    case gpsDevice = "gps_device"
    case twoWayRadio = "two_way_radio"
    case satelliteCommunicator = "satellite_communicator"
    case headlamp
    case flashlight
    case campLight = "camp_light"
    case powerBank = "power_bank"
    case battery
    case chargingCable = "charging_cable"
    case firstAidKit = "first_aid_kit"
    case whistle
    case emergencyBlanket = "emergency_blanket"
    case knife
    case repairTool = "repair_tool"
    case repairMaterial = "repair_material"
    case toothbrush
    case towel
    case toiletPaper = "toilet_paper"
    case trowel
    case sunscreen
    case insectRepellent = "insect_repellent"
    case menstrualProduct = "menstrual_product"
    case waistPack = "waist_pack"
    case key
    case document
    case food
    case drinkingWater = "drinking_water"
    case fuel
}

public enum EquipmentUnitLabel: String, Codable, CaseIterable {
    case item = "件"
    case piece = "只"
    case rod = "根"
    case pair = "对"
    case pairOfShoes = "双"
    case set = "套"
    case pack = "包"
    case bottle = "瓶"
    case can = "罐"
    case portion = "份"
}

public enum SleepingPadType: String, Codable, CaseIterable {
    case closedCellFoam = "closed_cell_foam"
    case air
    case selfInflating = "self_inflating"
}

public struct EquipmentCatalogFilter: Equatable {
    public let keyword: String?
    public let category: CatalogEquipmentCategory?
    public let brandID: String?
    public let equipmentType: CatalogEquipmentType?
    public let weightGrams: Double?
    public let minWeightGrams: Double?
    public let maxWeightGrams: Double?
    public let comfortTemperatureCelsius: Double?
    public let minComfortTemperatureCelsius: Double?
    public let maxComfortTemperatureCelsius: Double?

    public init(
        keyword: String? = nil,
        category: CatalogEquipmentCategory? = nil,
        brandID: String? = nil,
        equipmentType: CatalogEquipmentType? = nil,
        weightGrams: Double? = nil,
        minWeightGrams: Double? = nil,
        maxWeightGrams: Double? = nil,
        comfortTemperatureCelsius: Double? = nil,
        minComfortTemperatureCelsius: Double? = nil,
        maxComfortTemperatureCelsius: Double? = nil
    ) {
        self.keyword = keyword
        self.category = category
        self.brandID = brandID
        self.equipmentType = equipmentType
        self.weightGrams = weightGrams
        self.minWeightGrams = minWeightGrams
        self.maxWeightGrams = maxWeightGrams
        self.comfortTemperatureCelsius = comfortTemperatureCelsius
        self.minComfortTemperatureCelsius = minComfortTemperatureCelsius
        self.maxComfortTemperatureCelsius = maxComfortTemperatureCelsius
    }
}

public struct EquipmentBrand: Codable, Equatable, Identifiable {
    public let identity: String
    public let name: String
    public var id: String { identity }

    public init(identity: String, name: String) {
        self.identity = identity
        self.name = name
    }
}

public struct EquipmentBrandCollection: Codable, Equatable {
    public let items: [EquipmentBrand]

    public init(items: [EquipmentBrand]) {
        self.items = items
    }
}

/// The catalog API's measurement projection, not a standalone specification entity.
public struct CatalogEquipmentMeasurement: Codable, Equatable {
    public let unitLabel: EquipmentUnitLabel
    public let variant: String?
    public let unitWeight: EquipmentWeight?
    public let weightScope: String?

    public init(
        unitLabel: EquipmentUnitLabel,
        variant: String? = nil,
        unitWeight: EquipmentWeight? = nil,
        weightScope: String? = nil
    ) {
        self.unitLabel = unitLabel
        self.variant = variant
        self.unitWeight = unitWeight
        self.weightScope = weightScope
    }
}

public struct CatalogEquipmentSummary: Codable, Equatable, Identifiable {
    public let identity: String
    public let name: String
    public let category: CatalogEquipmentCategory
    public let equipmentType: CatalogEquipmentType
    public let brand: EquipmentBrand?
    public let model: String?
    public let specifications: CatalogEquipmentMeasurement?
    public var id: String { identity }

    public init(
        identity: String,
        name: String,
        category: CatalogEquipmentCategory,
        equipmentType: CatalogEquipmentType,
        brand: EquipmentBrand? = nil,
        model: String? = nil,
        specifications: CatalogEquipmentMeasurement? = nil
    ) {
        self.identity = identity
        self.name = name
        self.category = category
        self.equipmentType = equipmentType
        self.brand = brand
        self.model = model
        self.specifications = specifications
    }
}

public struct CatalogEquipmentCollection: Codable, Equatable {
    public let items: [CatalogEquipmentSummary]

    public init(items: [CatalogEquipmentSummary]) {
        self.items = items
    }
}

public struct BackpackSpecifications: Codable, Equatable {
    public let unitLabel: EquipmentUnitLabel
    public let variant: String?
    public let unitWeight: EquipmentWeight?
    public let weightScope: String?
    public let capacityLiters: Double?

    public init(
        unitLabel: EquipmentUnitLabel,
        variant: String? = nil,
        unitWeight: EquipmentWeight? = nil,
        weightScope: String? = nil,
        capacityLiters: Double? = nil
    ) {
        self.unitLabel = unitLabel
        self.variant = variant
        self.unitWeight = unitWeight
        self.weightScope = weightScope
        self.capacityLiters = capacityLiters
    }
}

public struct TentSpecifications: Codable, Equatable {
    public let unitLabel: EquipmentUnitLabel
    public let variant: String?
    public let unitWeight: EquipmentWeight?
    public let weightScope: String?
    public let capacityPersons: Int?

    public init(
        unitLabel: EquipmentUnitLabel,
        variant: String? = nil,
        unitWeight: EquipmentWeight? = nil,
        weightScope: String? = nil,
        capacityPersons: Int? = nil
    ) {
        self.unitLabel = unitLabel
        self.variant = variant
        self.unitWeight = unitWeight
        self.weightScope = weightScope
        self.capacityPersons = capacityPersons
    }
}

public struct SleepingBagSpecifications: Codable, Equatable {
    public let unitLabel: EquipmentUnitLabel
    public let variant: String?
    public let unitWeight: EquipmentWeight?
    public let weightScope: String?
    public let comfortTemperatureCelsius: Double?
    public let limitTemperatureCelsius: Double?

    public init(
        unitLabel: EquipmentUnitLabel,
        variant: String? = nil,
        unitWeight: EquipmentWeight? = nil,
        weightScope: String? = nil,
        comfortTemperatureCelsius: Double? = nil,
        limitTemperatureCelsius: Double? = nil
    ) {
        self.unitLabel = unitLabel
        self.variant = variant
        self.unitWeight = unitWeight
        self.weightScope = weightScope
        self.comfortTemperatureCelsius = comfortTemperatureCelsius
        self.limitTemperatureCelsius = limitTemperatureCelsius
    }
}

public struct SleepingPadSpecifications: Codable, Equatable {
    public let unitLabel: EquipmentUnitLabel
    public let variant: String?
    public let unitWeight: EquipmentWeight?
    public let weightScope: String?
    public let padType: SleepingPadType?
    public let rValue: Double?
    public let lengthCm: Double?
    public let maxWidthCm: Double?
    public let thicknessCm: Double?

    public init(
        unitLabel: EquipmentUnitLabel,
        variant: String? = nil,
        unitWeight: EquipmentWeight? = nil,
        weightScope: String? = nil,
        padType: SleepingPadType? = nil,
        rValue: Double? = nil,
        lengthCm: Double? = nil,
        maxWidthCm: Double? = nil,
        thicknessCm: Double? = nil
    ) {
        self.unitLabel = unitLabel
        self.variant = variant
        self.unitWeight = unitWeight
        self.weightScope = weightScope
        self.padType = padType
        self.rValue = rValue
        self.lengthCm = lengthCm
        self.maxWidthCm = maxWidthCm
        self.thicknessCm = thicknessCm
    }
}

/// Detail decoding selects a concrete projection using its containing equipmentType.
public enum CatalogEquipmentSpecifications: Equatable {
    case backpack(BackpackSpecifications)
    case tent(TentSpecifications)
    case sleepingBag(SleepingBagSpecifications)
    case sleepingPad(SleepingPadSpecifications)
    case measurement(CatalogEquipmentMeasurement)
}

public struct CatalogEquipmentDetail: Codable, Equatable, Identifiable {
    public let identity: String
    public let name: String
    public let category: CatalogEquipmentCategory
    public let equipmentType: CatalogEquipmentType
    public let brand: EquipmentBrand?
    public let model: String?
    public let specifications: CatalogEquipmentSpecifications?
    public var id: String { identity }

    public init(
        identity: String,
        name: String,
        category: CatalogEquipmentCategory,
        equipmentType: CatalogEquipmentType,
        brand: EquipmentBrand? = nil,
        model: String? = nil,
        specifications: CatalogEquipmentSpecifications? = nil
    ) {
        self.identity = identity
        self.name = name
        self.category = category
        self.equipmentType = equipmentType
        self.brand = brand
        self.model = model
        self.specifications = specifications
    }

    private enum CodingKeys: String, CodingKey {
        case identity, name, category, equipmentType, brand, model, specifications
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identity = try container.decode(String.self, forKey: .identity)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(CatalogEquipmentCategory.self, forKey: .category)
        equipmentType = try container.decode(CatalogEquipmentType.self, forKey: .equipmentType)
        brand = try container.decodeIfPresent(EquipmentBrand.self, forKey: .brand)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        switch equipmentType {
        case .backpack:
            specifications = try container.decodeIfPresent(BackpackSpecifications.self, forKey: .specifications).map(CatalogEquipmentSpecifications.backpack)
        case .tent:
            specifications = try container.decodeIfPresent(TentSpecifications.self, forKey: .specifications).map(CatalogEquipmentSpecifications.tent)
        case .sleepingBag:
            specifications = try container.decodeIfPresent(SleepingBagSpecifications.self, forKey: .specifications).map(CatalogEquipmentSpecifications.sleepingBag)
        case .sleepingPad:
            specifications = try container.decodeIfPresent(SleepingPadSpecifications.self, forKey: .specifications).map(CatalogEquipmentSpecifications.sleepingPad)
        default:
            specifications = try container.decodeIfPresent(CatalogEquipmentMeasurement.self, forKey: .specifications).map(CatalogEquipmentSpecifications.measurement)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identity, forKey: .identity)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encode(equipmentType, forKey: .equipmentType)
        try container.encodeIfPresent(brand, forKey: .brand)
        try container.encodeIfPresent(model, forKey: .model)
        switch specifications {
        case .backpack(let value): try container.encode(value, forKey: .specifications)
        case .tent(let value): try container.encode(value, forKey: .specifications)
        case .sleepingBag(let value): try container.encode(value, forKey: .specifications)
        case .sleepingPad(let value): try container.encode(value, forKey: .specifications)
        case .measurement(let value): try container.encode(value, forKey: .specifications)
        case nil: break
        }
    }
}
