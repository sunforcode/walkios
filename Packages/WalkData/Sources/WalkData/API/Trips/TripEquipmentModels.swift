import Foundation

public struct TripEquipmentTrip: Codable, Equatable {
     public let identity: String
     public let status: PersonalTripStatus
     public let routeName: String
     public let startDate: LocalDate
     public let endDate: LocalDate

    public init(
        identity: String,
        status: PersonalTripStatus,
        routeName: String,
        startDate: LocalDate,
        endDate: LocalDate
    ) {
        self.identity = identity
        self.status = status
        self.routeName = routeName
        self.startDate = startDate
        self.endDate = endDate
    }
}

public enum TripEquipmentItemSource: String, Codable, Equatable {
    case systemSuggestion = "system_suggestion"
    case userAdjusted = "user_adjusted"
    case userAdded = "user_added"
}

public enum TripEquipmentOwnershipStatus: String, Codable, Equatable {
    case owned
    case unconfirmedOwned = "unconfirmed_owned"
}

public struct TripEquipmentItem: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let quantity: Int
     public let unitWeight: EquipmentWeight?
     public let note: String?
     public let source: TripEquipmentItemSource
     public let ownershipStatus: TripEquipmentOwnershipStatus

     public var id: String { identity }
     public var totalWeight: EquipmentWeight? {
        unitWeight.map { EquipmentWeight(grams: $0.grams * Double(quantity)) }
    }

    public let category: CatalogEquipmentCategory?
    public let equipmentType: CatalogEquipmentType?
    public let variant: String?
    public let unitLabel: EquipmentUnitLabel?
    public let weightScope: String?
    public let carryAllocation: TripCarryAllocation?
    public let supply: TripSupply?
    public let packedQuantity: Int?
    public let ownershipCheckApplicable: Bool?

    public enum CodingKeys: String, CodingKey {
        case identity, name, quantity, unitWeight, note, source, ownershipStatus
        case category, equipmentType, variant, unitLabel, weightScope
        case carryAllocation, supply, packedQuantity, ownershipCheckApplicable
    }

    public init(
        identity: String,
        name: String,
        quantity: Int,
        unitWeight: EquipmentWeight?,
        note: String?,
        source: TripEquipmentItemSource,
        ownershipStatus: TripEquipmentOwnershipStatus,
        category: CatalogEquipmentCategory? = nil,
        equipmentType: CatalogEquipmentType? = nil,
        variant: String? = nil,
        unitLabel: EquipmentUnitLabel? = nil,
        weightScope: String? = nil,
        carryAllocation: TripCarryAllocation? = nil,
        supply: TripSupply? = nil,
        packedQuantity: Int? = nil,
        ownershipCheckApplicable: Bool? = nil
    ) {
        self.identity = identity
        self.name = name
        self.quantity = quantity
        self.unitWeight = unitWeight
        self.note = note
        self.source = source
        self.ownershipStatus = ownershipStatus
        self.category = category
        self.equipmentType = equipmentType
        self.variant = variant
        self.unitLabel = unitLabel
        self.weightScope = weightScope
        self.carryAllocation = carryAllocation
        self.supply = supply
        self.packedQuantity = packedQuantity
        self.ownershipCheckApplicable = ownershipCheckApplicable
    }
}

public struct TripEquipmentSnapshot: Codable, Equatable {
     public let identity: String
     public let items: [TripEquipmentItem]
     public let summary: PersonalTripEquipmentSummary

    public init(
        identity: String,
        items: [TripEquipmentItem],
        summary: PersonalTripEquipmentSummary
    ) {
        self.identity = identity
        self.items = items
        self.summary = summary
    }
}

public struct TripEquipmentProjection: Codable, Equatable {
     public let trip: TripEquipmentTrip
     public let revision: String
     public let editable: Bool
     public let snapshot: TripEquipmentSnapshot

    public init(
        trip: TripEquipmentTrip,
        revision: String,
        editable: Bool,
        snapshot: TripEquipmentSnapshot
    ) {
        self.trip = trip
        self.revision = revision
        self.editable = editable
        self.snapshot = snapshot
    }
}

