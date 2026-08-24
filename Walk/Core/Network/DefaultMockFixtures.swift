import Foundation

enum DefaultMockFixtures {
    static func all(userID: String = "anonymous", bundle: Bundle = .main) -> [String: Data] {
        tripFixtures(bundle: bundle).merging(routeFixtures(userID: userID, bundle: bundle)) { _, route in route }
    }

    static func tripFixtures(bundle: Bundle = .main) -> [String: Data] {
        var fixtures: [String: Data] = [:]

        if let data = load("trip-list", bundle: bundle) {
            fixtures[TripAPI.List().identifier] = data
        }
        if let data = load("trip-detail-trip-1", bundle: bundle) ?? load("trip-detail", bundle: bundle) {
            fixtures[TripAPI.Detail(id: "trip-1").identifier] = data
        }

        return fixtures
    }

    static func routeFixtures(userID: String = "anonymous", bundle: Bundle = .main) -> [String: Data] {
        guard let data = load("route-detail-route-1", bundle: bundle) else { return [:] }
        let emptyResponse = Data("""
        {"success":true,"message":"success","data":null,"timestamp":1724544001,"code":200}
        """.utf8)
        let routes = [
            (id: "route-1", name: "贡嘎环线"),
            (id: "route_001", name: "五台山逆穿"),
            (id: "route_002", name: "箭扣长城"),
            (id: "route_003", name: "海坨山南坡")
        ]
        var fixtures: [String: Data] = [:]

        for route in routes {
            guard let routeData = routeDetailData(from: data, id: route.id, name: route.name) else { continue }
            fixtures[RouteAPI.Detail(id: route.id, userID: userID).identifier] = routeData
            fixtures[RouteAPI.Favorite(id: route.id, userID: userID, isFavorite: true).identifier] = emptyResponse
            fixtures[RouteAPI.Favorite(id: route.id, userID: userID, isFavorite: false).identifier] = emptyResponse
        }

        return fixtures
    }

    private static func routeDetailData(from source: Data, id: String, name: String) -> Data? {
        guard var envelope = try? JSONSerialization.jsonObject(with: source) as? [String: Any],
              var route = envelope["data"] as? [String: Any] else {
            return nil
        }
        route["id"] = id
        route["name"] = name
        envelope["data"] = route
        return try? JSONSerialization.data(withJSONObject: envelope)
    }

    private static func load(_ name: String, bundle: Bundle) -> Data? {
        let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "MockAPI")
            ?? bundle.url(forResource: name, withExtension: "json")
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }
}
