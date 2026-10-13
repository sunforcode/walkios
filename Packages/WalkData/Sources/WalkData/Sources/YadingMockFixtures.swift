import Foundation

/// A local development dataset, not a public-route version or a generated itinerary.
/// The resource retains all original track coordinates and sanitized markers. Display
/// samples share one source-index map across the route, frozen profile and daily hikes.
enum YadingMockFixtures {
    static let routeID = "route-yading-5d"
    static let versionID = "route-yading-5d-v1"
    static let tripID = "trip-yading-5d"
    typealias Object = [String: Any]

    static let payload: Object = {
        guard let url = Bundle.module.url(forResource: "yading-five-day", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? Object else {
            preconditionFailure("The bundled Yading mock dataset is missing or invalid")
        }
        return object
    }()

    static func adding(to original: [String: Data]) -> [String: Data] {
        var fixtures = original
        let endpoints = payload["endpoints"] as! Object
        for (identifier, value) in endpoints { fixtures[identifier] = envelope(value) }
        let route = payload["routeSummary"] as! Object
        for identifier in [PublicRouteAPI.Featured().identifier, PublicRouteAPI.All().identifier] {
            var collection = object(fixtures[identifier])
            var items = collection["items"] as? [Object] ?? []
            items.removeAll { $0["routeId"] as? String == routeID }
            items.append(route)
            collection["items"] = items
            fixtures[identifier] = envelope(collection)
        }
        for query in ["亚丁", "亚丁5日"] {
            fixtures[PublicRouteAPI.Search(query: query).identifier] = envelope(["state": "completed", "items": [searchSummary(route)]])
        }
        for (identifier, data) in fixtures where identifier.hasPrefix("GET /public-routes/search") {
            var search = object(data)
            search["items"] = (search["items"] as? [Object] ?? []).map(searchSummary)
            fixtures[identifier] = envelope(search)
        }
        let collectionID = PersonalTripAPI.Collection().identifier
        var collection = object(fixtures[collectionID])
        var current = collection["currentTrips"] as? [Object] ?? []
        current.removeAll { $0["tripId"] as? String == tripID }
        current.append(payload["tripSummary"] as! Object)
        collection["currentTrips"] = current
        fixtures[collectionID] = envelope(collection)

        fixtures[PersonalTripAPI.Calendar().identifier] = envelope(calendar(collection: collection))
        // Deliberately retain the existing /trips/focus fixture.
        return fixtures
    }

    static func searchResponse(query: String?, fixtures: [String: Data]) -> Data {
        let term = normalizedSearch(query ?? "")
        guard !term.isEmpty else { return envelope(["state": "initial", "items": []]) }
        let items = object(fixtures[PublicRouteAPI.All().identifier])["items"] as? [Object] ?? []
        let matching = items.filter { item in
            ["name", "region"].contains { normalizedSearch(item[$0] as? String ?? "").contains(term) }
        }
        return envelope(["state": "completed", "items": matching.map(searchSummary)])
    }

    static func searchSummary(_ browse: Object) -> Object {
        let fields = Set(["routeId", "currentVersionId", "cover", "name", "region", "difficulty", "distance", "estimatedDuration"])
        return browse.filter { fields.contains($0.key) }
    }

    private static func normalizedSearch(_ text: String) -> String {
        let scalars = text.unicodeScalars.map { scalar -> String in
            var value = scalar.value
            if (0xFF01...0xFF5E).contains(value) { value -= 0xFEE0 }
            if (65...90).contains(value) { value += 32 }
            return String(UnicodeScalar(value)!)
        }.joined()
        return scalars.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func localDate(_ value: Any?) -> LocalDate? {
        guard let string = value as? String, let data = try? JSONEncoder().encode(string) else { return nil }
        return try? JSONDecoder().decode(LocalDate.self, from: data)
    }

    /// The fixture explicitly fixes its simulated server business date; generation
    /// never slides this 365-day window to make an out-of-window itinerary appear.
    static func calendar(collection: Object) -> Object {
        let source = payload["source"] as! Object
        let end = localDate(source["mockBusinessDate"])!.dateAtStartOfDay!
        let start = Calendar.business.date(byAdding: .day, value: -364, to: end)!
        var counts: [String: Int] = [:]
        let trips = (collection["currentTrips"] as? [Object] ?? []) + (collection["historicalTrips"] as? [Object] ?? [])
        for trip in trips {
            guard let tripStart = localDate(trip["startDate"])?.dateAtStartOfDay,
                  let tripEnd = localDate(trip["endDate"])?.dateAtStartOfDay else { continue }
            var date = max(start, tripStart)
            let last = min(end, tripEnd)
            while date <= last {
                counts[LocalDate(date: date).description, default: 0] += 1
                date = Calendar.business.date(byAdding: .day, value: 1, to: date)!
            }
        }
        return ["windowStartDate": LocalDate(date: start).description, "windowEndDate": LocalDate(date: end).description,
                "days": counts.keys.sorted().map { ["date": $0, "tripCount": counts[$0]!] as Object }]
    }

    static func object(_ data: Data?) -> Object {
        guard let data,
              let root = try? JSONSerialization.jsonObject(with: data) as? Object,
              let value = root["data"] as? Object else { return [:] }
        return value
    }

    static func envelope(_ value: Any) -> Data {
        // All values originate in the checked-in JSON or the closed mock dictionaries.
        try! JSONSerialization.data(withJSONObject: ["data": value], options: [.sortedKeys])
    }
}

/// Reuses the one demonstration trip identity while keeping create inputs and all
/// subsequent reads coherent. Each client/account owns its overrides; seeds stay immutable.
actor YadingMockScenarioStore {
    typealias Object = YadingMockFixtures.Object
    private let fixtures: [String: Data]
    private var overrides: [String: Data] = [:]
    private var identity: String?
    private var generation = 1
    private var receipts: [String: (fingerprint: Data, response: Data)] = [:]

    init(fixtures: [String: Data]) { self.fixtures = fixtures }

    func respond(method: String, path: String, body: Data?, headers: [String: String], identity currentIdentity: String) throws -> Data? {
        if identity != currentIdentity || (method == "DELETE" && path == "/auth/session") {
            overrides = [:]
            receipts = [:]
            generation = 1
            identity = currentIdentity
        }
        let tripID = YadingMockFixtures.tripID
        guard fixtures["GET /trips/\(tripID)"] != nil else { return nil }
        if method == "GET" { return overrides["GET \(path)"] }
        guard method == "POST", path == "/trips", let body,
              let input = try JSONSerialization.jsonObject(with: body) as? Object,
              input["routeId"] as? String == YadingMockFixtures.routeID else { return nil }
        guard currentIdentity != "anonymous", !currentIdentity.isEmpty else { throw error("authentication_required", "请先登录") }
        guard input["routeVersionId"] as? String == YadingMockFixtures.versionID else {
            throw error("route_version_unavailable", "此演示路线版本不可用")
        }
        guard let start = YadingMockFixtures.localDate(input["startDate"])?.dateAtStartOfDay,
              let city = (input["departureCity"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty,
              let key = headers["Idempotency-Key"], !key.isEmpty else { throw error("invalid_request", "日期、出发城市或幂等键无效") }
        let fingerprint = try JSONSerialization.data(withJSONObject: input, options: [.sortedKeys])
        if let receipt = receipts[key] {
            guard receipt.fingerprint == fingerprint else { throw error("idempotency_conflict", "同一操作的请求内容已改变") }
            return receipt.response
        }
        generation += 1
        let revision = "revision-yading-\(generation)"
        let dates = (0..<5).map { LocalDate(date: Calendar.business.date(byAdding: .day, value: $0, to: start)!).description }
        var detail = object("GET /trips/\(tripID)")
        var trip = detail["trip"] as! Object
        trip["startDate"] = dates[0]
        trip["endDate"] = dates[4]
        trip["departureCity"] = city
        detail["trip"] = trip
        detail["revision"] = revision
        let days = (detail["days"] as! [Object]).enumerated().map { index, original -> Object in
            var day = original
            day["date"] = dates[index]
            return day
        }
        detail["days"] = days
        var version = object("GET /trips/\(tripID)/route-version-status")
        version["tripRevision"] = revision
        detail["routeVersionStatus"] = version
        set(detail, for: "GET /trips/\(tripID)")
        set(version, for: "GET /trips/\(tripID)/route-version-status")

        var daily = object("GET /trips/\(tripID)/days")
        daily["revision"] = revision
        daily["startDate"] = dates[0]
        daily["endDate"] = dates[4]
        daily["days"] = days
        set(daily, for: "GET /trips/\(tripID)/days")
        var weather = object("GET /trips/\(tripID)/weather")
        weather["revision"] = revision
        weather["days"] = (weather["days"] as! [Object]).enumerated().map { index, original -> Object in
            var day = original
            day["date"] = dates[index]
            day["weatherAssociations"] = (day["weatherAssociations"] as! [Object]).map { original -> Object in
                var association = original
                for field in ["targetPeriodStart", "targetPeriodEnd"] {
                    association[field] = dates[index] + (association[field] as! String).dropFirst(10)
                }
                return association
            }
            return day
        }
        set(weather, for: "GET /trips/\(tripID)/weather")
        var equipment = object("GET /trips/\(tripID)/equipment")
        var equipmentTrip = equipment["trip"] as! Object
        equipmentTrip["startDate"] = dates[0]
        equipmentTrip["endDate"] = dates[4]
        equipment["trip"] = equipmentTrip
        equipment["revision"] = revision
        set(equipment, for: "GET /trips/\(tripID)/equipment")

        var collection = object(PersonalTripAPI.Collection().identifier)
        collection["currentTrips"] = (collection["currentTrips"] as! [Object]).map { original -> Object in
            guard original["tripId"] as? String == tripID else { return original }
            var summary = original
            summary["revision"] = revision
            summary["startDate"] = dates[0]
            summary["endDate"] = dates[4]
            return summary
        }
        set(collection, for: PersonalTripAPI.Collection().identifier)
        set(YadingMockFixtures.calendar(collection: collection), for: PersonalTripAPI.Calendar().identifier)
        let response = YadingMockFixtures.envelope(["resultType": "trip_created", "trip": detail])
        receipts[key] = (fingerprint, response)
        return response
    }

    private func object(_ key: String) -> Object { YadingMockFixtures.object(fixtures[key]) }
    private func set(_ value: Object, for key: String) { overrides[key] = YadingMockFixtures.envelope(value) }
    private func error(_ code: String, _ message: String) -> APIClientError {
        .api(code: code, message: message, retryable: false)
    }
}
