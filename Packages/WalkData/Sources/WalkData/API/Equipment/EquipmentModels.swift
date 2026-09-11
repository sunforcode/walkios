import Foundation

public struct EquipmentWeight: Codable, Equatable {
     public let grams: Int

    public init(
        grams: Int
    ) {
        self.grams = grams
    }
}

public struct PersonalEquipment: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let ownedQuantity: Int
     public let unitWeight: EquipmentWeight?

     public var id: String { identity }

    public init(
        identity: String,
        name: String,
        ownedQuantity: Int,
        unitWeight: EquipmentWeight?
    ) {
        self.identity = identity
        self.name = name
        self.ownedQuantity = ownedQuantity
        self.unitWeight = unitWeight
    }
}

public struct PersonalEquipmentSummary: Codable, Equatable {
     public let equipmentItemCount: Int
     public let equipmentListCount: Int
     public let knownTotalWeight: EquipmentWeight
     public let missingWeightItemCount: Int

    public init(
        equipmentItemCount: Int,
        equipmentListCount: Int,
        knownTotalWeight: EquipmentWeight,
        missingWeightItemCount: Int
    ) {
        self.equipmentItemCount = equipmentItemCount
        self.equipmentListCount = equipmentListCount
        self.knownTotalWeight = knownTotalWeight
        self.missingWeightItemCount = missingWeightItemCount
    }
}

public struct PersonalEquipmentCollection: Codable, Equatable {
     public let items: [PersonalEquipment]
     public let summary: PersonalEquipmentSummary

    public init(
        items: [PersonalEquipment],
        summary: PersonalEquipmentSummary
    ) {
        self.items = items
        self.summary = summary
    }
}

public struct PersonalEquipmentMutation: Codable, Equatable {
     public let item: PersonalEquipment
     public let summary: PersonalEquipmentSummary

    public init(
        item: PersonalEquipment,
        summary: PersonalEquipmentSummary
    ) {
        self.item = item
        self.summary = summary
    }
}

public struct EquipmentListReference: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String

     public var id: String { identity }

    public init(
        identity: String,
        name: String
    ) {
        self.identity = identity
        self.name = name
    }
}

public struct PersonalEquipmentDeletionImpact: Codable, Equatable {
     public let personalEquipmentId: String
     public let equipmentListReferenceCount: Int
     public let affectedEquipmentLists: [EquipmentListReference]

    public init(
        personalEquipmentId: String,
        equipmentListReferenceCount: Int,
        affectedEquipmentLists: [EquipmentListReference]
    ) {
        self.personalEquipmentId = personalEquipmentId
        self.equipmentListReferenceCount = equipmentListReferenceCount
        self.affectedEquipmentLists = affectedEquipmentLists
    }
}

public struct PersonalEquipmentDeletionResult: Codable, Equatable {
     public let deletedPersonalEquipmentId: String
     public let removedEquipmentListReferenceCount: Int
     public let summary: PersonalEquipmentSummary

    public init(
        deletedPersonalEquipmentId: String,
        removedEquipmentListReferenceCount: Int,
        summary: PersonalEquipmentSummary
    ) {
        self.deletedPersonalEquipmentId = deletedPersonalEquipmentId
        self.removedEquipmentListReferenceCount = removedEquipmentListReferenceCount
        self.summary = summary
    }
}

public struct EquipmentListSummary: Codable, Equatable {
     public let itemCount: Int
     public let knownTotalWeight: EquipmentWeight
     public let missingWeightItemCount: Int

    public init(
        itemCount: Int,
        knownTotalWeight: EquipmentWeight,
        missingWeightItemCount: Int
    ) {
        self.itemCount = itemCount
        self.knownTotalWeight = knownTotalWeight
        self.missingWeightItemCount = missingWeightItemCount
    }
}

public struct EquipmentListOverview: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let summary: EquipmentListSummary

     public var id: String { identity }

    public init(
        identity: String,
        name: String,
        summary: EquipmentListSummary
    ) {
        self.identity = identity
        self.name = name
        self.summary = summary
    }
}

public struct EquipmentListCollection: Codable, Equatable {
     public let items: [EquipmentListOverview]

    public init(
        items: [EquipmentListOverview]
    ) {
        self.items = items
    }
}

public struct EquipmentListMember: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let ownedQuantity: Int
     public let unitWeight: EquipmentWeight?
     public let quantity: Int

     public var id: String { identity }

    public init(
        identity: String,
        name: String,
        ownedQuantity: Int,
        unitWeight: EquipmentWeight?,
        quantity: Int
    ) {
        self.identity = identity
        self.name = name
        self.ownedQuantity = ownedQuantity
        self.unitWeight = unitWeight
        self.quantity = quantity
    }
}

public struct EquipmentListDetail: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let members: [EquipmentListMember]
     public let summary: EquipmentListSummary

     public var id: String { identity }

    public init(
        identity: String,
        name: String,
        members: [EquipmentListMember],
        summary: EquipmentListSummary
    ) {
        self.identity = identity
        self.name = name
        self.members = members
        self.summary = summary
    }
}

public struct EquipmentListCreateResult: Codable, Equatable {
     public let equipmentList: EquipmentListDetail
     public let personalEquipmentSummary: PersonalEquipmentSummary

    public init(
        equipmentList: EquipmentListDetail,
        personalEquipmentSummary: PersonalEquipmentSummary
    ) {
        self.equipmentList = equipmentList
        self.personalEquipmentSummary = personalEquipmentSummary
    }
}

public struct EquipmentListMutation: Codable, Equatable {
     public let equipmentList: EquipmentListDetail

    public init(
        equipmentList: EquipmentListDetail
    ) {
        self.equipmentList = equipmentList
    }
}

public struct EquipmentListDeletionResult: Codable, Equatable {
     public let deletedEquipmentListId: String
     public let personalEquipmentSummary: PersonalEquipmentSummary

    public init(
        deletedEquipmentListId: String,
        personalEquipmentSummary: PersonalEquipmentSummary
    ) {
        self.deletedEquipmentListId = deletedEquipmentListId
        self.personalEquipmentSummary = personalEquipmentSummary
    }
}

public enum PersonalEquipmentUpdateField<Value: Encodable & Equatable>: Encodable, Equatable {
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

public struct PersonalEquipmentUpdate: Encodable, Equatable {
     public let name: String?
     public let ownedQuantity: Int?
     public let unitWeight: PersonalEquipmentUpdateField<EquipmentWeight>

     public init(
        name: String? = nil,
        ownedQuantity: Int? = nil,
        unitWeight: PersonalEquipmentUpdateField<EquipmentWeight> = .unchanged
    ) {
        self.name = name
        self.ownedQuantity = ownedQuantity
        self.unitWeight = unitWeight
    }

     public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name { try container.encode(name, forKey: .name) }
        if let ownedQuantity { try container.encode(ownedQuantity, forKey: .ownedQuantity) }
        if unitWeight != .unchanged { try container.encode(unitWeight, forKey: .unitWeight) }
    }

    private enum CodingKeys: String, CodingKey {
        case name, ownedQuantity, unitWeight
    }
}

public enum PersonalEquipmentAPI {
    public struct Collection: APIRequest {
        public typealias Response = PersonalEquipmentCollection
        public let method: APIHTTPMethod = .get
        public let path = "/personal-equipment"
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init() {}
    }

    public struct Create: APIRequest {
        public typealias Response = PersonalEquipmentMutation
        public let method: APIHTTPMethod = .post
        public let path = "/personal-equipment"
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(name: String, ownedQuantity: Int, unitWeightGrams: Int?) throws {
            body = try JSONEncoder().encode(CreatePersonalEquipmentBody(
                name: name,
                ownedQuantity: ownedQuantity,
                unitWeight: unitWeightGrams.map(EquipmentWeight.init(grams:))
            ))
        }
    }

    public struct Detail: APIRequest {
        public typealias Response = PersonalEquipment
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init(personalEquipmentID: String) {
            path = "/personal-equipment/\(personalEquipmentID)"
        }
    }

    public struct Update: APIRequest {
        public typealias Response = PersonalEquipmentMutation
        public let method: APIHTTPMethod = .patch
        public let path: String
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(personalEquipmentID: String, update: PersonalEquipmentUpdate) throws {
            path = "/personal-equipment/\(personalEquipmentID)"
            body = try JSONEncoder().encode(update)
        }
    }

    public struct DeletionImpact: APIRequest {
        public typealias Response = PersonalEquipmentDeletionImpact
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(personalEquipmentID: String) {
            path = "/personal-equipment/\(personalEquipmentID)/deletion-impact"
        }
    }

    public struct Delete: APIRequest {
        public typealias Response = PersonalEquipmentDeletionResult
        public let method: APIHTTPMethod = .delete
        public let path: String
        public let query = [URLQueryItem(name: "confirmListRemoval", value: "true")]
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(personalEquipmentID: String) {
            path = "/personal-equipment/\(personalEquipmentID)"
        }
    }
}

public enum EquipmentListAPI {
    public struct Collection: APIRequest {
        public typealias Response = EquipmentListCollection
        public let method: APIHTTPMethod = .get
        public let path = "/equipment-lists"
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init() {}
    }

    public struct Create: APIRequest {
        public typealias Response = EquipmentListCreateResult
        public let method: APIHTTPMethod = .post
        public let path = "/equipment-lists"
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(name: String) throws {
            body = try JSONEncoder().encode(EquipmentListNameBody(name: name))
        }
    }

    public struct Detail: APIRequest {
        public typealias Response = EquipmentListDetail
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init(equipmentListID: String) {
            path = "/equipment-lists/\(equipmentListID)"
        }
    }

    public struct Rename: APIRequest {
        public typealias Response = EquipmentListMutation
        public let method: APIHTTPMethod = .patch
        public let path: String
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(equipmentListID: String, name: String) throws {
            path = "/equipment-lists/\(equipmentListID)"
            body = try JSONEncoder().encode(EquipmentListNameBody(name: name))
        }
    }

    public struct Delete: APIRequest {
        public typealias Response = EquipmentListDeletionResult
        public let method: APIHTTPMethod = .delete
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(equipmentListID: String) {
            path = "/equipment-lists/\(equipmentListID)"
        }
    }

    public struct PutMember: APIRequest {
        public typealias Response = EquipmentListMutation
        public let method: APIHTTPMethod = .put
        public let path: String
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(equipmentListID: String, personalEquipmentID: String, quantity: Int) throws {
            path = "/equipment-lists/\(equipmentListID)/members/\(personalEquipmentID)"
            body = try JSONEncoder().encode(EquipmentListMemberBody(quantity: quantity))
        }
    }

    public struct DeleteMember: APIRequest {
        public typealias Response = EquipmentListMutation
        public let method: APIHTTPMethod = .delete
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(equipmentListID: String, personalEquipmentID: String) {
            path = "/equipment-lists/\(equipmentListID)/members/\(personalEquipmentID)"
        }
    }
}

private struct CreatePersonalEquipmentBody: Encodable {
     public let name: String
     public let ownedQuantity: Int
     public let unitWeight: EquipmentWeight?
}

private struct EquipmentListNameBody: Encodable { public let name: String }
private struct EquipmentListMemberBody: Encodable { public let quantity: Int }
