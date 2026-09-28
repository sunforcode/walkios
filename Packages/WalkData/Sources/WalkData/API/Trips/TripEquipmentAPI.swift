import Foundation

/// 共用投影响应的十个任务请求；响应校验仍由真实客户端逐次执行。
public protocol TripEquipmentSnapshotRequest: APIRequest where Response == TripEquipmentProjection {}

public extension TripEquipmentSnapshotRequest {
    var responseEnvelope: APIResponseEnvelope { .data }
    var pathIsPercentEncoded: Bool { true }

    func validateResponse(_ response: TripEquipmentProjection, statusCode: Int, headers: [String: String]) throws {
        try EquipmentResponseValidation.validate(revision: response.revision, headers: headers)
    }
}

public enum TripEquipmentAPI {
    public struct Current: TripEquipmentSnapshotRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .get
        public let path: String
        public let storagePolicy: APIStoragePolicy = .store

        public init(tripID: String) {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment"
        }
    }

    public struct CreateItem: TripEquipmentSnapshotRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .post
        public let path: String
        public let body: Data?
        public let headers: [String: String]

        public init(tripID: String, input: TripEquipmentItemCreate, revision: String) throws {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment/items"
            body = try JSONEncoder().encode(input)
            headers = try EquipmentRequestHeaders.ifMatch(revision: revision)
        }

        /// 保留旧页面整数重量调用；新版类型化入口支持小数和完整准备字段。
        public init(tripID: String, name: String, quantity: Int, unitWeightGrams: Int?, note: String?) throws {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment/items"
            body = try JSONEncoder().encode(TripEquipmentItemCreate(
                name: name, quantity: quantity,
                unitWeight: unitWeightGrams.map { EquipmentWeight(grams: Double($0)) }, note: note
            ))
            headers = [:]
        }
    }

    public struct UpdateItem: TripEquipmentSnapshotRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .patch
        public let path: String
        public let body: Data?
        public let headers: [String: String]

        public init(tripID: String, itemID: String, update: TripEquipmentItemUpdate, revision: String? = nil) throws {
            if update.requiresRevision && revision == nil {
                throw EquipmentRequestValidationError.missingRevision
            }
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment/items/\(APIPathSegment.encode(itemID))"
            body = try JSONEncoder().encode(update)
            headers = try revision.map { try EquipmentRequestHeaders.ifMatch(revision: $0) } ?? [:]
        }
    }

    public struct DeleteItem: TripEquipmentSnapshotRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .delete
        public let path: String
        public let headers: [String: String]

        public init(tripID: String, itemID: String) {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment/items/\(APIPathSegment.encode(itemID))"
            headers = [:]
        }

        public init(tripID: String, itemID: String, revision: String) throws {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment/items/\(APIPathSegment.encode(itemID))"
            headers = try EquipmentRequestHeaders.ifMatch(revision: revision)
        }
    }

    public struct RecheckOwnership: TripEquipmentSnapshotRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .post
        public let path: String
        public let headers: [String: String]

        public init(tripID: String) {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment:recheck-ownership"
            headers = [:]
        }

        public init(tripID: String, revision: String) throws {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment:recheck-ownership"
            headers = try EquipmentRequestHeaders.ifMatch(revision: revision)
        }
    }

    public struct FromPersonal: TripEquipmentSnapshotRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .post
        public let path: String
        public let body: Data?
        public let headers: [String: String]

        public init(tripID: String, personalEquipmentID: String, quantity: Int, revision: String, idempotencyKey: String) throws {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment/items:from-personal"
            body = try JSONEncoder().encode(PersonalEquipmentSelectionBody(personalEquipmentId: personalEquipmentID, quantity: quantity))
            headers = try EquipmentRequestHeaders.ifMatch(revision: revision)
                .merging(EquipmentRequestHeaders.idempotency(key: idempotencyKey)) { _, rhs in rhs }
        }
    }

    public struct AppendList: TripEquipmentSnapshotRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .post
        public let path: String
        public let body: Data?
        public let headers: [String: String]

        public init(tripID: String, equipmentListID: String, revision: String, idempotencyKey: String) throws {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment:append-list"
            body = try JSONEncoder().encode(AppendListBody(equipmentListId: equipmentListID))
            headers = try EquipmentRequestHeaders.ifMatch(revision: revision)
                .merging(EquipmentRequestHeaders.idempotency(key: idempotencyKey)) { _, rhs in rhs }
        }
    }

    public struct ReplaceWithPersonal: TripEquipmentSnapshotRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .put
        public let path: String
        public let body: Data?
        public let headers: [String: String]

        public init(tripID: String, itemID: String, personalEquipmentID: String, quantity: Int, revision: String) throws {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment/items/\(APIPathSegment.encode(itemID))/personal-equipment"
            body = try JSONEncoder().encode(PersonalEquipmentSelectionBody(personalEquipmentId: personalEquipmentID, quantity: quantity))
            headers = try EquipmentRequestHeaders.ifMatch(revision: revision)
        }
    }

    public struct Preparation: APIRequest {
        public typealias Response = TripEquipmentPreparation
        public let method: APIHTTPMethod = .get
        public let path: String
        public let responseEnvelope: APIResponseEnvelope = .data
        public let pathIsPercentEncoded = true

        public init(tripID: String) {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment/preparation"
        }

        public func validateResponse(_ response: TripEquipmentPreparation, statusCode: Int, headers: [String: String]) throws {
            try EquipmentResponseValidation.validate(revision: response.revision, headers: headers)
        }
    }

    public struct SetPacking: TripEquipmentSnapshotRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .put
        public let path: String
        public let body: Data?
        public let headers: [String: String]

        public init(tripID: String, itemID: String, packedQuantity: Int, revision: String) throws {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment/items/\(APIPathSegment.encode(itemID))/packing"
            body = try JSONEncoder().encode(PackingBody(packedQuantity: packedQuantity))
            headers = try EquipmentRequestHeaders.ifMatch(revision: revision)
        }
    }

    public struct ResetPacking: TripEquipmentSnapshotRequest {
        public typealias Response = TripEquipmentProjection
        public let method: APIHTTPMethod = .post
        public let path: String
        public let headers: [String: String]

        public init(tripID: String, revision: String) throws {
            path = "/trips/\(APIPathSegment.encode(tripID))/equipment:reset-packing"
            headers = try EquipmentRequestHeaders.ifMatch(revision: revision)
        }
    }
}

private struct PersonalEquipmentSelectionBody: Encodable {
    let personalEquipmentId: String
    let quantity: Int
}

private struct AppendListBody: Encodable {
    let equipmentListId: String
}

private struct PackingBody: Encodable {
    let packedQuantity: Int
}
