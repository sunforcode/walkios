import Foundation

struct EquipmentWeight: Codable, Equatable {
    let grams: Int
}

struct PersonalEquipment: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let ownedQuantity: Int
    let unitWeight: EquipmentWeight?

    var id: String { identity }
}

struct PersonalEquipmentSummary: Codable, Equatable {
    let equipmentItemCount: Int
    let equipmentListCount: Int
    let knownTotalWeight: EquipmentWeight
    let missingWeightItemCount: Int
}

struct PersonalEquipmentCollection: Codable, Equatable {
    let items: [PersonalEquipment]
    let summary: PersonalEquipmentSummary
}

struct PersonalEquipmentMutation: Codable, Equatable {
    let item: PersonalEquipment
    let summary: PersonalEquipmentSummary
}

struct EquipmentListReference: Codable, Equatable, Identifiable {
    let identity: String
    let name: String

    var id: String { identity }
}

struct PersonalEquipmentDeletionImpact: Codable, Equatable {
    let personalEquipmentId: String
    let equipmentListReferenceCount: Int
    let affectedEquipmentLists: [EquipmentListReference]
}

struct PersonalEquipmentDeletionResult: Codable, Equatable {
    let deletedPersonalEquipmentId: String
    let removedEquipmentListReferenceCount: Int
    let summary: PersonalEquipmentSummary
}

struct EquipmentListSummary: Codable, Equatable {
    let itemCount: Int
    let knownTotalWeight: EquipmentWeight
    let missingWeightItemCount: Int
}

struct EquipmentListOverview: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let summary: EquipmentListSummary

    var id: String { identity }
}

struct EquipmentListCollection: Codable, Equatable {
    let items: [EquipmentListOverview]
}

struct EquipmentListMember: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let ownedQuantity: Int
    let unitWeight: EquipmentWeight?
    let quantity: Int

    var id: String { identity }
}

struct EquipmentListDetail: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let members: [EquipmentListMember]
    let summary: EquipmentListSummary

    var id: String { identity }
}

struct EquipmentListCreateResult: Codable, Equatable {
    let equipmentList: EquipmentListDetail
    let personalEquipmentSummary: PersonalEquipmentSummary
}

struct EquipmentListMutation: Codable, Equatable {
    let equipmentList: EquipmentListDetail
}

struct EquipmentListDeletionResult: Codable, Equatable {
    let deletedEquipmentListId: String
    let personalEquipmentSummary: PersonalEquipmentSummary
}

enum PersonalEquipmentUpdateField<Value: Encodable & Equatable>: Encodable, Equatable {
    case unchanged
    case value(Value)
    case clear

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .unchanged, .clear:
            try container.encodeNil()
        case .value(let value):
            try container.encode(value)
        }
    }
}

struct PersonalEquipmentUpdate: Encodable, Equatable {
    let name: String?
    let ownedQuantity: Int?
    let unitWeight: PersonalEquipmentUpdateField<EquipmentWeight>

    init(
        name: String? = nil,
        ownedQuantity: Int? = nil,
        unitWeight: PersonalEquipmentUpdateField<EquipmentWeight> = .unchanged
    ) {
        self.name = name
        self.ownedQuantity = ownedQuantity
        self.unitWeight = unitWeight
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name { try container.encode(name, forKey: .name) }
        if let ownedQuantity { try container.encode(ownedQuantity, forKey: .ownedQuantity) }
        if unitWeight != .unchanged { try container.encode(unitWeight, forKey: .unitWeight) }
    }

    private enum CodingKeys: String, CodingKey {
        case name, ownedQuantity, unitWeight
    }
}

enum PersonalEquipmentAPI {
    struct Collection: APIRequest {
        typealias Response = PersonalEquipmentCollection
        let method: APIHTTPMethod = .get
        let path = "/personal-equipment"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
    }

    struct Create: APIRequest {
        typealias Response = PersonalEquipmentMutation
        let method: APIHTTPMethod = .post
        let path = "/personal-equipment"
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(name: String, ownedQuantity: Int, unitWeightGrams: Int?) throws {
            body = try JSONEncoder().encode(CreatePersonalEquipmentBody(
                name: name,
                ownedQuantity: ownedQuantity,
                unitWeight: unitWeightGrams.map(EquipmentWeight.init(grams:))
            ))
        }
    }

    struct Detail: APIRequest {
        typealias Response = PersonalEquipment
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store

        init(personalEquipmentID: String) {
            path = "/personal-equipment/\(personalEquipmentID)"
        }
    }

    struct Update: APIRequest {
        typealias Response = PersonalEquipmentMutation
        let method: APIHTTPMethod = .patch
        let path: String
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(personalEquipmentID: String, update: PersonalEquipmentUpdate) throws {
            path = "/personal-equipment/\(personalEquipmentID)"
            body = try JSONEncoder().encode(update)
        }
    }

    struct DeletionImpact: APIRequest {
        typealias Response = PersonalEquipmentDeletionImpact
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data

        init(personalEquipmentID: String) {
            path = "/personal-equipment/\(personalEquipmentID)/deletion-impact"
        }
    }

    struct Delete: APIRequest {
        typealias Response = PersonalEquipmentDeletionResult
        let method: APIHTTPMethod = .delete
        let path: String
        let query = [URLQueryItem(name: "confirmListRemoval", value: "true")]
        let responseEnvelope: APIResponseEnvelope = .data

        init(personalEquipmentID: String) {
            path = "/personal-equipment/\(personalEquipmentID)"
        }
    }
}

enum EquipmentListAPI {
    struct Collection: APIRequest {
        typealias Response = EquipmentListCollection
        let method: APIHTTPMethod = .get
        let path = "/equipment-lists"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
    }

    struct Create: APIRequest {
        typealias Response = EquipmentListCreateResult
        let method: APIHTTPMethod = .post
        let path = "/equipment-lists"
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(name: String) throws {
            body = try JSONEncoder().encode(EquipmentListNameBody(name: name))
        }
    }

    struct Detail: APIRequest {
        typealias Response = EquipmentListDetail
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store

        init(equipmentListID: String) {
            path = "/equipment-lists/\(equipmentListID)"
        }
    }

    struct Rename: APIRequest {
        typealias Response = EquipmentListMutation
        let method: APIHTTPMethod = .patch
        let path: String
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(equipmentListID: String, name: String) throws {
            path = "/equipment-lists/\(equipmentListID)"
            body = try JSONEncoder().encode(EquipmentListNameBody(name: name))
        }
    }

    struct Delete: APIRequest {
        typealias Response = EquipmentListDeletionResult
        let method: APIHTTPMethod = .delete
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data

        init(equipmentListID: String) {
            path = "/equipment-lists/\(equipmentListID)"
        }
    }

    struct PutMember: APIRequest {
        typealias Response = EquipmentListMutation
        let method: APIHTTPMethod = .put
        let path: String
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(equipmentListID: String, personalEquipmentID: String, quantity: Int) throws {
            path = "/equipment-lists/\(equipmentListID)/members/\(personalEquipmentID)"
            body = try JSONEncoder().encode(EquipmentListMemberBody(quantity: quantity))
        }
    }

    struct DeleteMember: APIRequest {
        typealias Response = EquipmentListMutation
        let method: APIHTTPMethod = .delete
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data

        init(equipmentListID: String, personalEquipmentID: String) {
            path = "/equipment-lists/\(equipmentListID)/members/\(personalEquipmentID)"
        }
    }
}

private struct CreatePersonalEquipmentBody: Encodable {
    let name: String
    let ownedQuantity: Int
    let unitWeight: EquipmentWeight?
}

private struct EquipmentListNameBody: Encodable { let name: String }
private struct EquipmentListMemberBody: Encodable { let quantity: Int }
