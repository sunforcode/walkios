import Foundation

struct RouteDetailResponse: Decodable, Equatable {
    let id: String
    let name: String
    let description: String?
    let regionId: String?
    let region: String?
    let distance: Double?
    let duration: Int?
    let elevationGain: Double?
    let elevationLoss: Double?
    let difficulty: RouteDetailDifficulty?
    let routeType: RouteDetailType?
    let routeDirection: Int?
    let coverUrl: String?
    let defaultMapId: String?
    let kmlUrl: String?
    let gpxUrl: String?
    let popularity: Int
    let usageCount: Int
    let isLoop: Bool
    let isFavorite: Bool
    let status: Int
    let createdAt: Int64
    let updatedAt: Int64
    let createdBy: String?
    let creator: RouteDetailCreator?
    let segmentSchemes: [RouteSegmentScheme]
    let poiPoints: [RoutePOIPoint]
    let dailyPlans: [RouteDailyPlan]
    let tags: [String]
    let imageUrls: [String]
    let ratings: RouteRatings?
    let weatherInfo: RouteWeatherInfo?
    let hitchhikeContacts: [RouteHitchhikeContact]
    let trackPoints: [RouteTrackPoint]

    enum CodingKeys: String, CodingKey {
        case id, name, description, region, distance, duration, difficulty, popularity, status, creator, tags, ratings
        case regionId = "region_id"
        case elevationGain = "elevation_gain"
        case elevationLoss = "elevation_loss"
        case routeType = "route_type"
        case routeDirection = "route_direction"
        case coverUrl = "cover_url"
        case defaultMapId = "default_map_id"
        case kmlUrl = "kml_url"
        case gpxUrl = "gpx_url"
        case usageCount = "usage_count"
        case isLoop = "is_loop"
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
        case segmentSchemes = "segment_schemes"
        case poiPoints = "poi_points"
        case dailyPlans = "daily_plans"
        case imageUrls = "image_urls"
        case weatherInfo = "weather_info"
        case hitchhikeContacts = "hitchhike_contacts"
        case trackPoints = "track_points"
    }
}

enum RouteDetailDifficulty: Decodable, Equatable {
    case easy
    case moderate
    case hard
    case unknown(Int)

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(Int.self)
        switch value {
        case 1: self = .easy
        case 3: self = .moderate
        case 5: self = .hard
        default: self = .unknown(value)
        }
    }

    var displayText: String {
        switch self {
        case .easy: "简单"
        case .moderate: "中等"
        case .hard: "困难"
        case .unknown: "暂无数据"
        }
    }
}

enum RouteDetailType: Decodable, Equatable {
    case outAndBack
    case loop
    case oneWay
    case multiDay
    case unknown(Int)

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(Int.self)
        switch value {
        case 0: self = .outAndBack
        case 1: self = .loop
        case 2: self = .oneWay
        case 3: self = .multiDay
        default: self = .unknown(value)
        }
    }

    var displayText: String {
        switch self {
        case .outAndBack: "往返"
        case .loop: "环线"
        case .oneWay: "单程"
        case .multiDay: "多日"
        case .unknown: "暂无数据"
        }
    }
}

enum RouteDetailFormatting {
    static func text(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "暂无数据"
        }
        return value
    }

    static func number<T>(_ value: T?) -> String where T: Numeric {
        value.map(String.init(describing:)) ?? "—"
    }
}

struct RouteDetailCreator: Decodable, Equatable {
    let id: String
    let username: String
    let nickname: String
    let email: String
    let avatarUrl: String?
    let createdAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, username, nickname, email
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }
}

struct RouteSegmentScheme: Decodable, Equatable {
    let id: String
    let routeId: String
    let schemeType: String
    let label: String
    let isDefault: Bool
    let segments: [RouteSegment]

    enum CodingKeys: String, CodingKey {
        case id, label, segments
        case routeId = "route_id"
        case schemeType = "scheme_type"
        case isDefault = "is_default"
    }
}

struct RouteSegment: Decodable, Equatable {
    let id: String
    let name: String
    let description: String?
    let distance: Double?
    let elevationGain: Double?
    let elevationLoss: Double?
    let estimatedTime: Double?
    let difficulty: RouteDetailDifficulty?
    let routeType: RouteDetailType?
    let notes: String?
    let sequenceNumber: Int
    let trackStartIndex: Int?
    let trackEndIndex: Int?
    let color: String?
    let schemeType: String?
    let startPoint: RouteWaypoint?
    let endPoint: RouteWaypoint?
    let keypoints: [RouteWaypoint]

    enum CodingKeys: String, CodingKey {
        case id, name, description, distance, difficulty, notes, color, keypoints
        case elevationGain = "elevation_gain"
        case elevationLoss = "elevation_loss"
        case estimatedTime = "estimated_time"
        case routeType = "route_type"
        case sequenceNumber = "sequence_number"
        case trackStartIndex = "track_start_index"
        case trackEndIndex = "track_end_index"
        case schemeType = "scheme_type"
        case startPoint = "start_point"
        case endPoint = "end_point"
    }
}

struct RouteWaypoint: Decodable, Equatable {
    let id: String
    let name: String
    let description: String?
    let latitude: Double
    let longitude: Double
    let elevation: Double?
    let type: String?
    let iconUrl: String?
    let imageUrl: String?
    let sequenceNumber: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, description, latitude, longitude, elevation, type
        case iconUrl = "icon_url"
        case imageUrl = "image_url"
        case sequenceNumber = "sequence_number"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RoutePOIPoint: Decodable, Equatable {
    let id: String
    let routeId: String
    let name: String
    let latitude: Double
    let longitude: Double
    let elevation: Double?
    let category: String
    let subCategory: String?
    let source: String
    let description: String?
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, elevation, category, source, description, confidence
        case routeId = "route_id"
        case subCategory = "sub_category"
    }
}

struct RouteDailyPlan: Decodable, Equatable {
    let id: String
    let dayNumber: Int
    let title: String
    let description: String?
    let distance: Double?
    let estimatedTime: Double?
    let elevationGain: Int?
    let elevationLoss: Double?
    let maxElevation: Double?
    let minElevation: Double?
    let accommodation: String?
    let notes: String?
    let createdAt: Date
    let updatedAt: Date
    let segments: [RouteDailyPlanSegment]

    enum CodingKeys: String, CodingKey {
        case id, title, description, distance, accommodation, notes, segments
        case dayNumber = "day_number"
        case estimatedTime = "estimated_time"
        case elevationGain = "elevation_gain"
        case elevationLoss = "elevation_loss"
        case maxElevation = "max_elevation"
        case minElevation = "min_elevation"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RouteDailyPlanSegment: Decodable, Equatable {
    let id: String
    let sequenceNumber: Int
    let segment: RouteSegment?

    enum CodingKeys: String, CodingKey {
        case id, segment
        case sequenceNumber = "sequence_number"
    }
}

struct RouteRatings: Decodable, Equatable {
    let overall: Double?
    let scenery: Double?
    let difficulty: Double?
    let experience: Double?
    let facilities: Double?
    let ratingCount: Int

    enum CodingKeys: String, CodingKey {
        case overall, scenery, difficulty, experience, facilities
        case ratingCount = "rating_count"
    }
}

struct RouteWeatherInfo: Decodable, Equatable {
    let description: String?
    let precautions: String?
    let bestSeasons: [String]
    let seasonalWeather: [String: String]

    enum CodingKeys: String, CodingKey {
        case description, precautions
        case bestSeasons = "best_seasons"
        case seasonalWeather = "seasonal_weather"
    }
}

struct RouteHitchhikeContact: Decodable, Equatable {
    let id: String
    let name: String
    let phone: String
    let description: String?
    let location: String?
    let price: Double?
    let lastVerified: Bool
    let creator: RouteDetailCreator?
    let createdAt: Int64
    let updatedAt: Int64

    enum CodingKeys: String, CodingKey {
        case id, name, phone, description, location, price, creator
        case lastVerified = "last_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RouteTrackPoint: Decodable, Equatable {
    let id: String
    let name: String?
    let latitude: Double
    let longitude: Double
    let elevation: Double?
    let sequenceNumber: Int
    let type: String?
    let iconUrl: String?
    let imageUrl: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, elevation, type, description
        case sequenceNumber = "sequence_number"
        case iconUrl = "icon_url"
        case imageUrl = "image_url"
    }
}
