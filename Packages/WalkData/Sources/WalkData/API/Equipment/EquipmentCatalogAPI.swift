import Foundation

public enum EquipmentCatalogRequestError: Error, Equatable {
    case nonFiniteNumber(field: String)
}

public enum EquipmentCatalogAPI {
    public struct Brands: APIRequest {
        public typealias Response = EquipmentBrandCollection
        public let method: APIHTTPMethod = .get
        public let path = "/equipment-catalog/brands"
        public let pathIsPercentEncoded = true
        public let responseEnvelope: APIResponseEnvelope = .data
        public let authenticationPolicy: APIAuthenticationPolicy = .required
        public let storagePolicy: APIStoragePolicy = .none

        public init() {}
    }

    public struct Items: APIRequest {
        public typealias Response = CatalogEquipmentCollection
        public let method: APIHTTPMethod = .get
        public let path = "/equipment-catalog/items"
        public let pathIsPercentEncoded = true
        public let responseEnvelope: APIResponseEnvelope = .data
        public let authenticationPolicy: APIAuthenticationPolicy = .required
        public let storagePolicy: APIStoragePolicy = .none
        public let query: [URLQueryItem]

        public init(filter: EquipmentCatalogFilter) throws {
            try self.init(
                keyword: filter.keyword,
                category: filter.category,
                brandID: filter.brandID,
                equipmentType: filter.equipmentType,
                weightGrams: filter.weightGrams,
                minWeightGrams: filter.minWeightGrams,
                maxWeightGrams: filter.maxWeightGrams,
                comfortTemperatureCelsius: filter.comfortTemperatureCelsius,
                minComfortTemperatureCelsius: filter.minComfortTemperatureCelsius,
                maxComfortTemperatureCelsius: filter.maxComfortTemperatureCelsius
            )
        }

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
        ) throws {
            var query: [URLQueryItem] = []
            if let keyword { query.append(URLQueryItem(name: "keyword", value: keyword)) }
            if let category { query.append(URLQueryItem(name: "category", value: category.rawValue)) }
            if let brandID { query.append(URLQueryItem(name: "brandId", value: brandID)) }
            if let equipmentType { query.append(URLQueryItem(name: "equipmentType", value: equipmentType.rawValue)) }
            let numbers: [(String, Double?)] = [
                ("weightGrams", weightGrams),
                ("minWeightGrams", minWeightGrams),
                ("maxWeightGrams", maxWeightGrams),
                ("comfortTemperatureCelsius", comfortTemperatureCelsius),
                ("minComfortTemperatureCelsius", minComfortTemperatureCelsius),
                ("maxComfortTemperatureCelsius", maxComfortTemperatureCelsius)
            ]
            for (name, value) in numbers {
                if let value {
                    guard value.isFinite else {
                        throw EquipmentCatalogRequestError.nonFiniteNumber(field: name)
                    }
                    query.append(URLQueryItem(name: name, value: String(value)))
                }
            }
            self.query = query
        }
    }

    public struct Detail: APIRequest {
        public typealias Response = CatalogEquipmentDetail
        public let method: APIHTTPMethod = .get
        public let path: String
        public let pathIsPercentEncoded = true
        public let responseEnvelope: APIResponseEnvelope = .data
        public let authenticationPolicy: APIAuthenticationPolicy = .required
        public let storagePolicy: APIStoragePolicy = .none

        public init(equipmentID: String) {
            path = "/equipment-catalog/items/\(APIPathSegment.encode(equipmentID))"
        }
    }
}
