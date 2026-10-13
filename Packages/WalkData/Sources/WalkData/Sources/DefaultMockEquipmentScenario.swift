import Foundation

/// Mutable development fixtures for the equipment and trip UI. Each instance owns an
/// isolated in-memory scenario; unrelated requests still use the supplied static client.
/// This is not an offline store or an alternative implementation of backend validation.
public struct DefaultMockEquipmentScenario: APIClient {
    private let fallback: MockAPIClient
    private let store: EquipmentScenarioStore
    private let yading: YadingMockScenarioStore
    private let fixtures: [String: Data]
    private let identityProvider: @Sendable () -> String

    public init(
        fixtures: [String: Data] = DefaultMockFixtures.all(),
        identityProvider: @escaping @Sendable () -> String = { "mock-account" }
    ) {
        fallback = MockAPIClient(fixtures: fixtures)
        store = EquipmentScenarioStore(fixtures: fixtures)
        yading = YadingMockScenarioStore(fixtures: fixtures)
        self.fixtures = fixtures
        self.identityProvider = identityProvider
    }

    public func execute<Request: APIRequest>(_ request: Request) async throws -> Request.Response {
        let query = request.query.reduce(into: [String: String]()) { $0[$1.name] = $1.value }
        let identity = identityProvider()
        if let result = try await yading.respond(
            method: request.method.rawValue, path: request.path, body: request.body,
            headers: request.headers, identity: identity
        ) {
            return try APIJSONDecoder.decode(Request.Response.self, from: result, envelope: request.responseEnvelope)
        }
        if request.method == .get, request.path == "/public-routes/search" {
            return try APIJSONDecoder.decode(
                Request.Response.self,
                from: YadingMockFixtures.searchResponse(query: query["query"], fixtures: fixtures),
                envelope: request.responseEnvelope
            )
        }
        if request.method != .get,
           request.path.hasPrefix("/trips/\(YadingMockFixtures.tripID)/equipment") {
            throw APIClientError.api(code: "trip_equipment_read_only", message: "亚丁演示行程尚未配置可编辑装备", retryable: false)
        }
        if let result = try await store.respond(
            method: request.method.rawValue, path: request.path, query: query,
            body: request.body, headers: request.headers, identity: identity
        ) {
            let response = try APIJSONDecoder.decode(Request.Response.self, from: result.data, envelope: request.responseEnvelope)
            try request.validateResponse(response, statusCode: result.statusCode, headers: result.headers)
            return response
        }
        return try await fallback.execute(request)
    }
}

private struct EquipmentScenarioResponse: Sendable {
    let data: Data
    let statusCode: Int
    let headers: [String: String]
}

private actor EquipmentScenarioStore {
    typealias Object = [String: Any]
    struct ListRecord {
        var name: String
        var members: [String: Int]
    }
    struct Receipt {
        let fingerprint: Data
        let response: EquipmentScenarioResponse
    }

    private let fixtures: [String: Data]
    private var identity: String?
    private var personal: [String: Object] = [:]
    private var lists: [String: ListRecord] = [:]
    private var trip: Object = [:]
    private var tripItems: [Object] = []
    private var snapshotID = "equipment-snapshot-1"
    private var revision = 1
    private var nextID = 100
    private var receipts: [String: Receipt] = [:]
    private let configurationKeys = ["category", "equipmentType", "variant", "unitLabel", "weightScope"]

    init(fixtures: [String: Data]) { self.fixtures = fixtures }

    func respond(
        method: String, path: String, query: [String: String], body: Data?,
        headers: [String: String], identity currentIdentity: String
    ) throws -> EquipmentScenarioResponse? {
        if identity != currentIdentity {
            try reset()
            identity = currentIdentity
        }
        if method == "DELETE", path == "/auth/session" {
            // Reset even if a subsequent mock login returns the same demonstration token.
            try reset()
            identity = nil
            return nil
        }
        let segments = path.split(separator: "/").map { String($0).removingPercentEncoding ?? String($0) }
        let personalRoute = segments.first == "personal-equipment"
        let listRoute = segments.first == "equipment-lists" && !path.hasSuffix(":copy")
        let tripRoute = segments.count >= 3 && segments[0] == "trips" && segments[1] == "trip-1"
            && (segments[2] == "equipment" || ["equipment:recheck-ownership", "equipment:append-list"].contains(segments[2]))
        let detailRoute = method == "GET" && segments == ["trips", "trip-1"]
        guard personalRoute || listRoute || tripRoute || detailRoute else { return nil }
        guard currentIdentity != "anonymous", !currentIdentity.isEmpty else {
            throw error("authentication_required", "请先登录")
        }
        let input: Object
        if let body {
            guard let object = try JSONSerialization.jsonObject(with: body) as? Object else { throw error("invalid_request", "请求格式无效") }
            input = object
        } else { input = [:] }
        if personalRoute { return try personalResponse(method: method, segments: segments, query: query, input: input) }
        if listRoute { return try listResponse(method: method, segments: segments, input: input) }
        if detailRoute {
            var detail = try fixtureObject("GET /trips/trip-1")
            detail["revision"] = currentRevision
            detail["equipmentSnapshot"] = ["snapshotId": snapshotID, "summary": tripSummary()]
            return try response(detail, revision: currentRevision)
        }
        return try tripResponse(method: method, path: path, segments: segments, input: input, headers: headers)
    }

    private func reset() throws {
        personal = [
            "equipment-1": ["identity": "equipment-1", "name": "轻量帐篷", "ownedQuantity": 1,
                            "unitWeight": ["grams": 1800.0], "unitWeightSource": "user_recorded",
                            "category": "tent", "equipmentType": "tent"],
            "equipment-2": ["identity": "equipment-2", "name": "修补贴", "ownedQuantity": 1,
                            "unitWeight": ["grams": 12.5], "unitWeightSource": "user_recorded",
                            "category": "safety_emergency", "equipmentType": "repair_material"],
        ]
        lists = ["list-1": ListRecord(name: "周末露营", members: ["equipment-1": 1])]
        let projection = try fixtureObject("GET /trips/trip-1/equipment")
        guard let tripValue = projection["trip"] as? Object,
              let snapshot = projection["snapshot"] as? Object,
              let items = snapshot["items"] as? [Object], let id = snapshot["identity"] as? String else {
            throw APIClientError.invalidResponse
        }
        trip = tripValue
        tripItems = items.map { $0.filter { !($0.value is NSNull) } }
        snapshotID = id
        revision = 1
        nextID = 100
        receipts = [:]
    }

    private func personalResponse(method: String, segments: [String], query: [String: String], input: Object) throws -> EquipmentScenarioResponse? {
        if segments.count == 1 {
            switch method {
            case "GET":
                let items = orderedPersonal.filter { item in
                    if let keyword = query["keyword"], !normalized(item["name"] as? String ?? "").contains(normalized(keyword)) { return false }
                    for field in ["category", "equipmentType"] {
                        if let filter = query[field], item[field] as? String != filter { return false }
                    }
                    if let filter = query["missingWeight"], (weight(item) == nil) != (filter == "true") { return false }
                    return true
                }
                return try response(["items": items, "summary": personalSummary()])
            case "POST":
                var item = input
                try validateItem(&item, quantityKey: "ownedQuantity")
                try uniqueName(item, among: orderedPersonal)
                let id = newID("equipment")
                item["identity"] = id
                if weight(item) != nil { item["unitWeightSource"] = "user_recorded" }
                personal[id] = item
                return try response(["item": item, "summary": personalSummary()], status: 201)
            default: return nil
            }
        }
        let id = segments[1]
        guard let original = personal[id] else { throw notFound() }
        if segments.count == 3, segments[2] == "deletion-impact", method == "GET" {
            let affected = lists.keys.sorted().compactMap { key -> Object? in
                guard let record = lists[key], record.members[id] != nil else { return nil }
                return ["identity": key, "name": record.name]
            }
            return try response(["personalEquipmentId": id, "equipmentListReferenceCount": affected.count, "affectedEquipmentLists": affected])
        }
        guard segments.count == 2 else { return nil }
        switch method {
        case "GET": return try response(original)
        case "PATCH":
            var item = applying(input, to: original)
            try validateItem(&item, quantityKey: "ownedQuantity")
            try uniqueName(item, among: orderedPersonal.filter { $0["identity"] as? String != id })
            if input["unitWeight"] != nil {
                item["unitWeightSource"] = weight(item) == nil ? nil : "user_recorded"
            }
            personal[id] = item
            return try response(["item": item, "summary": personalSummary()])
        case "DELETE":
            guard query["confirmListRemoval"] == "true" else { throw error("deletion_confirmation_required", "请确认清单移除影响") }
            let affected = lists.keys.filter { lists[$0]?.members[id] != nil }
            personal[id] = nil
            for key in affected { lists[key]?.members[id] = nil }
            return try response(["deletedPersonalEquipmentId": id, "removedEquipmentListReferenceCount": affected.count, "summary": personalSummary()])
        default: return nil
        }
    }

    private func listResponse(method: String, segments: [String], input: Object) throws -> EquipmentScenarioResponse? {
        if segments.count == 1 {
            switch method {
            case "GET":
                let items: [Object] = lists.keys.sorted().map { id in
                    let detail = listDetail(id)
                    return ["identity": id, "name": detail["name"]!, "summary": detail["summary"]!]
                }
                return try response(["items": items])
            case "POST":
                let name = try validName(input["name"])
                let id = newID("list")
                lists[id] = ListRecord(name: name, members: [:])
                return try response(["equipmentList": listDetail(id), "personalEquipmentSummary": personalSummary()], status: 201)
            default: return nil
            }
        }
        let id = segments[1]
        guard lists[id] != nil else { throw notFound() }
        if segments.count == 4, segments[2] == "members" {
            let equipmentID = segments[3]
            guard personal[equipmentID] != nil else { throw notFound() }
            switch method {
            case "PUT": lists[id]?.members[equipmentID] = try positiveQuantity(input["quantity"])
            case "DELETE": lists[id]?.members[equipmentID] = nil
            default: return nil
            }
            return try response(["equipmentList": listDetail(id)])
        }
        guard segments.count == 2 else { return nil }
        switch method {
        case "GET": return try response(listDetail(id))
        case "PATCH":
            lists[id]?.name = try validName(input["name"])
            return try response(["equipmentList": listDetail(id)])
        case "DELETE":
            lists[id] = nil
            return try response(["deletedEquipmentListId": id, "personalEquipmentSummary": personalSummary()])
        default: return nil
        }
    }

    private func tripResponse(method: String, path: String, segments: [String], input: Object, headers: [String: String]) throws -> EquipmentScenarioResponse? {
        if method == "GET", segments.count == 3, segments[2] == "equipment" { return try tripProjection() }
        let selection = method == "POST" && (path.hasSuffix("/items:from-personal") || path.hasSuffix("/equipment:append-list"))
        let itemRoute = segments.count >= 4 && segments[2] == "equipment" && segments[3] == "items"
        let recheck = method == "POST" && segments.count == 3 && segments[2] == "equipment:recheck-ownership"
        guard selection || recheck || (itemRoute && ((segments.count == 4 && method == "POST") || (segments.count == 5 && ["PATCH", "DELETE"].contains(method)))) else { return nil }
        var receiptKey: String?
        var fingerprint: Data?
        if selection {
            guard let key = headers["Idempotency-Key"], !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw error("invalid_request", "缺少幂等键") }
            let scope = "\(method) \(path) \(key)"
            let value = try JSONSerialization.data(withJSONObject: ["body": input, "revision": headers["If-Match"] ?? ""], options: .sortedKeys)
            if let saved = receipts[scope] {
                guard saved.fingerprint == value else { throw error("idempotency_conflict", "同一操作的请求内容已改变") }
                return saved.response
            }
            receiptKey = scope
            fingerprint = value
        }
        let extendedFields = Set(configurationKeys + ["carryAllocation", "supply"])
        if let match = headers["If-Match"] {
            guard match.count > 2, match.hasPrefix("\""), match.hasSuffix("\""),
                  !match.dropFirst().dropLast().contains("\"") else { throw error("invalid_request", "行程版本格式无效") }
            guard match == "\"\(currentRevision)\"" else { throw error("concurrent_modification", "行程已更新，请刷新后重试") }
        } else if selection || !extendedFields.isDisjoint(with: input.keys) {
            throw error("invalid_request", "缺少有效行程版本")
        }
        guard trip["status"] as? String == "planned" else { throw error("trip_equipment_read_only", "当前行程不能修改装备") }
        var updated = tripItems
        var resultStatus = 200
        if selection {
            let candidates: [Object]
            if path.hasSuffix("/items:from-personal") {
                guard let id = input["personalEquipmentId"] as? String else { throw notFound() }
                candidates = [try copiedPersonal(id, quantity: positiveQuantity(input["quantity"]))]
                resultStatus = 201
            } else {
                guard let id = input["equipmentListId"] as? String, let list = lists[id] else { throw notFound() }
                candidates = try list.members.keys.sorted().map { try copiedPersonal($0, quantity: list.members[$0]!) }
            }
            // Validate the whole batch before assigning identities or committing anything.
            var combined = updated
            for candidate in candidates { try uniqueName(candidate, among: combined); combined.append(candidate) }
            for var candidate in candidates { candidate["identity"] = newID("trip-equipment"); updated.append(candidate) }
        } else if recheck {
            updated = updated.map { item in
                var copy = item
                copy["ownershipStatus"] = ownership(item)
                copy["ownershipCheckApplicable"] = item["supply"] == nil
                return copy
            }
        } else if method == "POST" {
            var item = input
            try validateItem(&item, quantityKey: "quantity")
            try uniqueName(item, among: updated)
            item["identity"] = newID("trip-equipment")
            item["source"] = "user_added"
            item["ownershipStatus"] = "unconfirmed_owned"
            item["ownershipCheckApplicable"] = item["supply"] == nil
            updated.append(item)
            resultStatus = 201
        } else {
            guard let index = updated.firstIndex(where: { $0["identity"] as? String == segments[4] }) else { throw notFound() }
            if method == "DELETE" { updated.remove(at: index) }
            else {
                let original = updated[index]
                var item = applying(input, to: original)
                try validateItem(&item, quantityKey: "quantity")
                try uniqueName(item, among: updated.enumerated().filter { $0.offset != index }.map(\.element))
                if original["source"] as? String == "system_suggestion" { item["source"] = "user_adjusted" }
                if item["supply"] != nil { item["ownershipStatus"] = "unconfirmed_owned" }
                item["ownershipCheckApplicable"] = item["supply"] == nil
                let preparationFields = Set(["name", "quantity", "unitWeight", "category", "equipmentType", "variant", "unitLabel", "weightScope", "carryAllocation", "supply"])
                if !preparationFields.isDisjoint(with: input.keys) { item["packedQuantity"] = 0 }
                updated[index] = item
            }
        }
        tripItems = updated
        revision += 1
        let result = try tripProjection(status: resultStatus)
        if let receiptKey, let fingerprint { receipts[receiptKey] = Receipt(fingerprint: fingerprint, response: result) }
        return result
    }

    private func copiedPersonal(_ id: String, quantity: Int) throws -> Object {
        guard let personal = personal[id] else { throw notFound() }
        guard !["food", "drinking_water", "fuel"].contains(personal["category"] as? String ?? "") else {
            throw error("validation_failed", "请在本次装备中填写实际补给量")
        }
        var item: Object = ["name": personal["name"]!, "quantity": quantity, "source": "user_added", "packedQuantity": 0, "ownershipCheckApplicable": true]
        for key in configurationKeys + ["unitWeight"] { item[key] = personal[key] }
        item["ownershipStatus"] = ownership(item)
        return item
    }

    private var currentRevision: String { "revision-\(revision)" }
    private var orderedPersonal: [Object] { personal.keys.sorted().compactMap { personal[$0] } }

    private func personalSummary() -> Object {
        let result = summary(orderedPersonal, quantityKey: "ownedQuantity")
        return ["equipmentItemCount": personal.count, "equipmentListCount": lists.count,
                "knownTotalWeight": result["knownTotalWeight"]!, "missingWeightItemCount": result["missingWeightItemCount"]!]
    }

    private func listDetail(_ id: String) -> Object {
        guard let list = lists[id] else { return [:] }
        let members: [Object] = list.members.keys.sorted().compactMap { key in
            guard var item = personal[key] else { return nil }
            item["quantity"] = list.members[key]
            return item
        }
        return ["identity": id, "name": list.name, "members": members, "summary": summary(members, quantityKey: "quantity")]
    }

    private func tripSummary() -> Object {
        var result = summary(tripItems, quantityKey: "quantity")
        let owned = tripItems.filter { $0["ownershipStatus"] as? String == "owned" }.count
        result["ownedItemCount"] = owned
        result["unconfirmedOwnedItemCount"] = tripItems.count - owned
        return result
    }

    private func summary(_ items: [Object], quantityKey: String) -> Object {
        let total = items.reduce(0.0) { $0 + (weight($1) ?? 0) * Double($1[quantityKey] as? Int ?? 1) }
        return ["itemCount": items.count, "knownTotalWeight": ["grams": total], "missingWeightItemCount": items.filter { weight($0) == nil }.count]
    }

    private func tripProjection(status: Int = 200) throws -> EquipmentScenarioResponse {
        try response(["trip": trip, "revision": currentRevision, "editable": trip["status"] as? String == "planned",
                      "snapshot": ["identity": snapshotID, "items": tripItems, "summary": tripSummary()]], status: status, revision: currentRevision)
    }

    private func ownership(_ item: Object) -> String {
        guard item["supply"] == nil else { return "unconfirmed_owned" }
        let name = normalized(item["name"] as? String ?? "")
        let quantity = item["quantity"] as? Int ?? 1
        return orderedPersonal.contains { normalized($0["name"] as? String ?? "") == name && ($0["ownedQuantity"] as? Int ?? 0) >= quantity } ? "owned" : "unconfirmed_owned"
    }

    private func validateItem(_ item: inout Object, quantityKey: String) throws {
        item["name"] = try validName(item["name"])
        item[quantityKey] = try positiveQuantity(item[quantityKey])
        if let raw = item["unitWeight"] {
            guard let value = raw as? Object, let number = value["grams"] as? NSNumber,
                  CFGetTypeID(number) != CFBooleanGetTypeID(), number.doubleValue.isFinite, number.doubleValue > 0 else {
                throw error("validation_failed", "重量必须为有限正数")
            }
        }
    }

    private func positiveQuantity(_ value: Any?) throws -> Int {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, number.doubleValue > 0, number.doubleValue < Double(Int.max),
              number.doubleValue.rounded() == number.doubleValue else { throw error("validation_failed", "数量必须为正整数") }
        return number.intValue
    }

    private func validName(_ value: Any?) throws -> String {
        guard let raw = value as? String else { throw error("invalid_request", "缺少名称") }
        let name = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !name.isEmpty else { throw error("validation_failed", "名称不能为空") }
        return name
    }

    private func normalized(_ value: String) -> String {
        let cleaned = value.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(String.UnicodeScalarView(cleaned.unicodeScalars.map {
            (65...90).contains($0.value) ? UnicodeScalar($0.value + 32)! : $0
        }))
    }

    private func uniqueName(_ item: Object, among items: [Object]) throws {
        let name = normalized(item["name"] as? String ?? "")
        guard !items.contains(where: { normalized($0["name"] as? String ?? "") == name }) else { throw error("equipment_name_conflict", "已经有同名装备") }
    }

    private func weight(_ item: Object) -> Double? { (item["unitWeight"] as? Object)?["grams"] as? Double }
    private func newID(_ prefix: String) -> String { defer { nextID += 1 }; return "\(prefix)-\(nextID)" }
    private func applying(_ update: Object, to original: Object) -> Object {
        var item = original
        for (key, value) in update { item[key] = value is NSNull ? nil : value }
        return item
    }
    private func fixtureObject(_ identifier: String) throws -> Object {
        guard let data = fixtures[identifier], let envelope = try JSONSerialization.jsonObject(with: data) as? Object,
              let value = envelope["data"] as? Object else { throw APIClientError.mockNotFound(identifier) }
        return value
    }
    private func response(_ value: Object, status: Int = 200, revision: String? = nil) throws -> EquipmentScenarioResponse {
        EquipmentScenarioResponse(data: try JSONSerialization.data(withJSONObject: ["data": value], options: .sortedKeys),
                                  statusCode: status, headers: revision.map { ["ETag": "\"\($0)\""] } ?? [:])
    }
    private func error(_ code: String, _ message: String) -> APIClientError { .api(code: code, message: message, retryable: false) }
    private func notFound() -> APIClientError { error("resource_not_found", "未找到此资源") }
}
