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
        unitWeight.map { EquipmentWeight(grams: $0.grams * quantity) }
    }

    public enum CodingKeys: String, CodingKey {
        case identity, name, quantity, unitWeight, note, source, ownershipStatus
    }

    public init(
        identity: String,
        name: String,
        quantity: Int,
        unitWeight: EquipmentWeight?,
        note: String?,
        source: TripEquipmentItemSource,
        ownershipStatus: TripEquipmentOwnershipStatus
    ) {
        self.identity = identity
        self.name = name
        self.quantity = quantity
        self.unitWeight = unitWeight
        self.note = note
        self.source = source
        self.ownershipStatus = ownershipStatus
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

public struct TripEquipmentItemUpdate: Encodable, Equatable {
     public let name: String?
     public let quantity: Int?
     public let unitWeight: TripEquipmentUpdateField<EquipmentWeight>
     public let note: TripEquipmentUpdateField<String>

     public init(
        name: String? = nil,
        quantity: Int? = nil,
        unitWeight: TripEquipmentUpdateField<EquipmentWeight> = .unchanged,
        note: TripEquipmentUpdateField<String> = .unchanged
    ) {
        self.name = name
        self.quantity = quantity
        self.unitWeight = unitWeight
        self.note = note
    }

     public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name { try container.encode(name, forKey: .name) }
        if let quantity { try container.encode(quantity, forKey: .quantity) }
        if unitWeight != .unchanged { try container.encode(unitWeight, forKey: .unitWeight) }
        if note != .unchanged { try container.encode(note, forKey: .note) }
    }

    private enum CodingKeys: String, CodingKey {
        case name, quantity, unitWeight, note
    }
}

private struct CreateTripEquipmentItemBody: Encodable {
     public let name: String
     public let quantity: Int
     public let unitWeight: EquipmentWeight?
     public let note: String?
}

public enum TripEquipmentAPI {
    public struct Current: APIRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init(tripID: String) {
            path = "/trips/\(tripID)/equipment"
        }
    }

    public struct CreateItem: APIRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .post
        public let path: String
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(
            tripID: String,
            name: String,
            quantity: Int,
            unitWeightGrams: Int?,
            note: String?
        ) throws {
            path = "/trips/\(tripID)/equipment/items"
            body = try JSONEncoder().encode(CreateTripEquipmentItemBody(
                name: name,
                quantity: quantity,
                unitWeight: unitWeightGrams.map(EquipmentWeight.init(grams:)),
                note: note
            ))
        }
    }

    public struct UpdateItem: APIRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .patch
        public let path: String
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(tripID: String, itemID: String, update: TripEquipmentItemUpdate) throws {
            path = "/trips/\(tripID)/equipment/items/\(itemID)"
            body = try JSONEncoder().encode(update)
        }
    }

    public struct DeleteItem: APIRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .delete
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(tripID: String, itemID: String) {
            path = "/trips/\(tripID)/equipment/items/\(itemID)"
        }
    }

    public struct RecheckOwnership: APIRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .post
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(tripID: String) {
            path = "/trips/\(tripID)/equipment:recheck-ownership"
        }
    }
}

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

public struct TripEquipmentService: TripEquipmentServicing {
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

