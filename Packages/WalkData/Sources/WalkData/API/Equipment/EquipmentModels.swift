import Foundation

public struct EquipmentWeight: Codable, Equatable {
    public let grams: Double

    public init(grams: Double) {
        self.grams = grams
    }

    public init<Integer: BinaryInteger>(grams: Integer) {
        self.grams = Double(grams)
    }
}

public enum EquipmentWeightSource: String, Codable, Equatable {
    case catalogReference = "catalog_reference"
    case userRecorded = "user_recorded"
}

public struct PersonalEquipment: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let ownedQuantity: Int
     public let unitWeight: EquipmentWeight?
    public let category: CatalogEquipmentCategory?
    public let equipmentType: CatalogEquipmentType?
    public let variant: String?
    public let unitLabel: EquipmentUnitLabel?
    public let weightScope: String?
    public let unitWeightSource: EquipmentWeightSource?
    public let catalogEquipmentId: String?

     public var id: String { identity }

    public init(
        identity: String,
        name: String,
        ownedQuantity: Int,
        unitWeight: EquipmentWeight?,
        category: CatalogEquipmentCategory? = nil,
        equipmentType: CatalogEquipmentType? = nil,
        variant: String? = nil,
        unitLabel: EquipmentUnitLabel? = nil,
        weightScope: String? = nil,
        unitWeightSource: EquipmentWeightSource? = nil,
        catalogEquipmentId: String? = nil
    ) {
        self.identity = identity
        self.name = name
        self.ownedQuantity = ownedQuantity
        self.unitWeight = unitWeight
        self.category = category
        self.equipmentType = equipmentType
        self.variant = variant
        self.unitLabel = unitLabel
        self.weightScope = weightScope
        self.unitWeightSource = unitWeightSource
        self.catalogEquipmentId = catalogEquipmentId
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
    public let category: CatalogEquipmentCategory?
    public let equipmentType: CatalogEquipmentType?
    public let variant: String?
    public let unitLabel: EquipmentUnitLabel?
    public let weightScope: String?
    public let unitWeightSource: EquipmentWeightSource?
    public let catalogEquipmentId: String?
     public let quantity: Int

     public var id: String { identity }

    public init(
        identity: String,
        name: String,
        ownedQuantity: Int,
        unitWeight: EquipmentWeight?,
        quantity: Int,
        category: CatalogEquipmentCategory? = nil,
        equipmentType: CatalogEquipmentType? = nil,
        variant: String? = nil,
        unitLabel: EquipmentUnitLabel? = nil,
        weightScope: String? = nil,
        unitWeightSource: EquipmentWeightSource? = nil,
        catalogEquipmentId: String? = nil
    ) {
        self.identity = identity
        self.name = name
        self.ownedQuantity = ownedQuantity
        self.unitWeight = unitWeight
        self.category = category
        self.equipmentType = equipmentType
        self.variant = variant
        self.unitLabel = unitLabel
        self.weightScope = weightScope
        self.unitWeightSource = unitWeightSource
        self.catalogEquipmentId = catalogEquipmentId
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

/// Manual creation omits unknown values; only PATCH and catalog adoption permit explicit clears.
public struct PersonalEquipmentCreateRequest: Encodable, Equatable {
    public let name: String
    public let ownedQuantity: Int
    public let unitWeight: EquipmentWeight?
    public let category: CatalogEquipmentCategory?
    public let equipmentType: CatalogEquipmentType?
    public let variant: String?
    public let unitLabel: EquipmentUnitLabel?
    public let weightScope: String?

    public init(
        name: String,
        ownedQuantity: Int,
        unitWeight: EquipmentWeight? = nil,
        category: CatalogEquipmentCategory? = nil,
        equipmentType: CatalogEquipmentType? = nil,
        variant: String? = nil,
        unitLabel: EquipmentUnitLabel? = nil,
        weightScope: String? = nil
    ) {
        self.name = name
        self.ownedQuantity = ownedQuantity
        self.unitWeight = unitWeight
        self.category = category
        self.equipmentType = equipmentType
        self.variant = variant
        self.unitLabel = unitLabel
        self.weightScope = weightScope
    }
}

public struct PersonalEquipmentUpdate: Encodable, Equatable {
    public let name: String?
    public let ownedQuantity: Int?
    public let unitWeight: PersonalEquipmentUpdateField<EquipmentWeight>
    public let category: PersonalEquipmentUpdateField<CatalogEquipmentCategory>
    public let equipmentType: PersonalEquipmentUpdateField<CatalogEquipmentType>
    public let variant: PersonalEquipmentUpdateField<String>
    public let unitLabel: PersonalEquipmentUpdateField<EquipmentUnitLabel>
    public let weightScope: PersonalEquipmentUpdateField<String>

    public init(
        name: String? = nil,
        ownedQuantity: Int? = nil,
        unitWeight: PersonalEquipmentUpdateField<EquipmentWeight> = .unchanged,
        category: PersonalEquipmentUpdateField<CatalogEquipmentCategory> = .unchanged,
        equipmentType: PersonalEquipmentUpdateField<CatalogEquipmentType> = .unchanged,
        variant: PersonalEquipmentUpdateField<String> = .unchanged,
        unitLabel: PersonalEquipmentUpdateField<EquipmentUnitLabel> = .unchanged,
        weightScope: PersonalEquipmentUpdateField<String> = .unchanged
    ) {
        self.name = name
        self.ownedQuantity = ownedQuantity
        self.unitWeight = unitWeight
        self.category = category
        self.equipmentType = equipmentType
        self.variant = variant
        self.unitLabel = unitLabel
        self.weightScope = weightScope
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name { try container.encode(name, forKey: .name) }
        if let ownedQuantity { try container.encode(ownedQuantity, forKey: .ownedQuantity) }
        if unitWeight != .unchanged { try container.encode(unitWeight, forKey: .unitWeight) }
        if category != .unchanged { try container.encode(category, forKey: .category) }
        if equipmentType != .unchanged { try container.encode(equipmentType, forKey: .equipmentType) }
        if variant != .unchanged { try container.encode(variant, forKey: .variant) }
        if unitLabel != .unchanged { try container.encode(unitLabel, forKey: .unitLabel) }
        if weightScope != .unchanged { try container.encode(weightScope, forKey: .weightScope) }
    }

    private enum CodingKeys: String, CodingKey {
        case name, ownedQuantity, unitWeight, category, equipmentType, variant, unitLabel, weightScope
    }
}

public struct PersonalEquipmentFromCatalogRequest: Encodable, Equatable {
    public let catalogEquipmentId: String
    public let ownedQuantity: Int
    public let name: String?
    public let unitWeight: PersonalEquipmentUpdateField<EquipmentWeight>
    public let variant: PersonalEquipmentUpdateField<String>
    public let unitLabel: PersonalEquipmentUpdateField<EquipmentUnitLabel>
    public let weightScope: PersonalEquipmentUpdateField<String>

    public init(
        catalogEquipmentId: String,
        ownedQuantity: Int,
        name: String? = nil,
        unitWeight: PersonalEquipmentUpdateField<EquipmentWeight> = .unchanged,
        variant: PersonalEquipmentUpdateField<String> = .unchanged,
        unitLabel: PersonalEquipmentUpdateField<EquipmentUnitLabel> = .unchanged,
        weightScope: PersonalEquipmentUpdateField<String> = .unchanged
    ) {
        self.catalogEquipmentId = catalogEquipmentId
        self.ownedQuantity = ownedQuantity
        self.name = name
        self.unitWeight = unitWeight
        self.variant = variant
        self.unitLabel = unitLabel
        self.weightScope = weightScope
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(catalogEquipmentId, forKey: .catalogEquipmentId)
        try container.encode(ownedQuantity, forKey: .ownedQuantity)
        if let name { try container.encode(name, forKey: .name) }
        if unitWeight != .unchanged { try container.encode(unitWeight, forKey: .unitWeight) }
        if variant != .unchanged { try container.encode(variant, forKey: .variant) }
        if unitLabel != .unchanged { try container.encode(unitLabel, forKey: .unitLabel) }
        if weightScope != .unchanged { try container.encode(weightScope, forKey: .weightScope) }
    }

    private enum CodingKeys: String, CodingKey {
        case catalogEquipmentId, ownedQuantity, name, unitWeight, variant, unitLabel, weightScope
    }
}

public struct PersonalEquipmentFilter: Equatable {
    public let keyword: String?
    public let category: CatalogEquipmentCategory?
    public let equipmentType: CatalogEquipmentType?
    public let missingWeight: Bool?

    public init(
        keyword: String? = nil,
        category: CatalogEquipmentCategory? = nil,
        equipmentType: CatalogEquipmentType? = nil,
        missingWeight: Bool? = nil
    ) {
        self.keyword = keyword
        self.category = category
        self.equipmentType = equipmentType
        self.missingWeight = missingWeight
    }

    fileprivate var query: [URLQueryItem] {
        [
            keyword.map { URLQueryItem(name: "keyword", value: $0) },
            category.map { URLQueryItem(name: "category", value: $0.rawValue) },
            equipmentType.map { URLQueryItem(name: "equipmentType", value: $0.rawValue) },
            missingWeight.map { URLQueryItem(name: "missingWeight", value: $0 ? "true" : "false") },
        ].compactMap { $0 }
    }
}

public enum PersonalEquipmentAPI {
    public struct Collection: APIRequest {
        public typealias Response = PersonalEquipmentCollection
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .get
        public let path = "/personal-equipment"
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public let query: [URLQueryItem]

        public init(
            keyword: String? = nil,
            category: CatalogEquipmentCategory? = nil,
            equipmentType: CatalogEquipmentType? = nil,
            missingWeight: Bool? = nil
        ) {
            self.init(filter: PersonalEquipmentFilter(
                keyword: keyword, category: category, equipmentType: equipmentType, missingWeight: missingWeight
            ))
        }

        public init(filter: PersonalEquipmentFilter) {
            query = filter.query
        }
    }

    public struct Create: APIRequest {
        public typealias Response = PersonalEquipmentMutation
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .post
        public let path = "/personal-equipment"
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(name: String, ownedQuantity: Int, unitWeightGrams: Int?) throws {
            try self.init(input: PersonalEquipmentCreateRequest(
                name: name,
                ownedQuantity: ownedQuantity,
                unitWeight: unitWeightGrams.map { EquipmentWeight(grams: $0) }
            ))
        }

        public init(input: PersonalEquipmentCreateRequest) throws {
            body = try JSONEncoder().encode(input)
        }
    }

    public struct FromCatalog: APIRequest {
        public typealias Response = PersonalEquipmentMutation
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .post
        public let path = "/personal-equipment:from-catalog"
        public let body: Data?
        public let headers: [String: String]
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(input: PersonalEquipmentFromCatalogRequest, idempotencyKey: String) throws {
            headers = try EquipmentRequestHeaders.idempotency(key: idempotencyKey)
            body = try JSONEncoder().encode(input)
        }
    }

    public struct Detail: APIRequest {
        public typealias Response = PersonalEquipment
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init(personalEquipmentID: String) {
            path = "/personal-equipment/\(APIPathSegment.encode(personalEquipmentID))"
        }
    }

    public struct Update: APIRequest {
        public typealias Response = PersonalEquipmentMutation
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .patch
        public let path: String
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(personalEquipmentID: String, update: PersonalEquipmentUpdate) throws {
            path = "/personal-equipment/\(APIPathSegment.encode(personalEquipmentID))"
            body = try JSONEncoder().encode(update)
        }
    }

    public struct DeletionImpact: APIRequest {
        public typealias Response = PersonalEquipmentDeletionImpact
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(personalEquipmentID: String) {
            path = "/personal-equipment/\(APIPathSegment.encode(personalEquipmentID))/deletion-impact"
        }
    }

    public struct Delete: APIRequest {
        public typealias Response = PersonalEquipmentDeletionResult
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .delete
        public let path: String
        public let query = [URLQueryItem(name: "confirmListRemoval", value: "true")]
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(personalEquipmentID: String) {
            path = "/personal-equipment/\(APIPathSegment.encode(personalEquipmentID))"
        }
    }
}

public enum EquipmentListAPI {
    public struct Collection: APIRequest {
        public typealias Response = EquipmentListCollection
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .get
        public let path = "/equipment-lists"
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init() {}
    }

    public struct Create: APIRequest {
        public typealias Response = EquipmentListCreateResult
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .post
        public let path = "/equipment-lists"
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(name: String) throws {
            body = try JSONEncoder().encode(EquipmentListNameBody(name: name))
        }
    }

    public struct Copy: APIRequest {
        public typealias Response = EquipmentListCreateResult
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .post
        public let path: String
        public let body: Data?
        public let headers: [String: String]
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(equipmentListID: String, name: String, idempotencyKey: String) throws {
            path = "/equipment-lists/\(APIPathSegment.encode(equipmentListID)):copy"
            headers = try EquipmentRequestHeaders.idempotency(key: idempotencyKey)
            body = try JSONEncoder().encode(EquipmentListNameBody(name: name))
        }
    }

    public struct Detail: APIRequest {
        public typealias Response = EquipmentListDetail
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data
        public let storagePolicy: APIStoragePolicy = .store

        public init(equipmentListID: String) {
            path = "/equipment-lists/\(APIPathSegment.encode(equipmentListID))"
        }
    }

    public struct Rename: APIRequest {
        public typealias Response = EquipmentListMutation
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .patch
        public let path: String
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(equipmentListID: String, name: String) throws {
            path = "/equipment-lists/\(APIPathSegment.encode(equipmentListID))"
            body = try JSONEncoder().encode(EquipmentListNameBody(name: name))
        }
    }

    public struct Delete: APIRequest {
        public typealias Response = EquipmentListDeletionResult
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .delete
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(equipmentListID: String) {
            path = "/equipment-lists/\(APIPathSegment.encode(equipmentListID))"
        }
    }

    public struct PutMember: APIRequest {
        public typealias Response = EquipmentListMutation
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .put
        public let path: String
        public let body: Data?
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(equipmentListID: String, personalEquipmentID: String, quantity: Int) throws {
            path = "/equipment-lists/\(APIPathSegment.encode(equipmentListID))/members/\(APIPathSegment.encode(personalEquipmentID))"
            body = try JSONEncoder().encode(EquipmentListMemberBody(quantity: quantity))
        }
    }

    public struct DeleteMember: APIRequest {
        public typealias Response = EquipmentListMutation
        public let pathIsPercentEncoded = true
        public let method: APIHTTPMethod = .delete
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data

        public init(equipmentListID: String, personalEquipmentID: String) {
            path = "/equipment-lists/\(APIPathSegment.encode(equipmentListID))/members/\(APIPathSegment.encode(personalEquipmentID))"
        }
    }
}

private struct EquipmentListNameBody: Encodable { public let name: String }
private struct EquipmentListMemberBody: Encodable { public let quantity: Int }
