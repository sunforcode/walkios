import Foundation

public struct RouteDetailResponse: Decodable, Equatable {
     public let id: String
     public let name: String
     public let description: String?
     public let regionId: String?
     public let region: String?
     public let distance: Double?
     public let duration: Int?
     public let elevationGain: Double?
     public let elevationLoss: Double?
     public let difficulty: RouteDetailDifficulty?
     public let routeType: RouteDetailType?
     public let routeDirection: Int?
     public let coverUrl: String?
     public let defaultMapId: String?
     public let kmlUrl: String?
     public let gpxUrl: String?
     public let popularity: Int
     public let usageCount: Int
     public let isLoop: Bool
     public let isFavorite: Bool
     public let status: Int
     public let createdAt: Int64
     public let updatedAt: Int64
     public let createdBy: String?
     public let creator: RouteDetailCreator?
     public let segmentSchemes: [RouteSegmentScheme]
     public let poiPoints: [RoutePOIPoint]
     public let dailyPlans: [RouteDailyPlan]
     public let tags: [String]
     public let imageUrls: [String]
     public let ratings: RouteRatings?
     public let weatherInfo: RouteWeatherInfo?
     public let hitchhikeContacts: [RouteHitchhikeContact]
     public let trackPoints: [RouteTrackPoint]

    public enum CodingKeys: String, CodingKey {
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

    public init(
        id: String,
        name: String,
        description: String?,
        regionId: String?,
        region: String?,
        distance: Double?,
        duration: Int?,
        elevationGain: Double?,
        elevationLoss: Double?,
        difficulty: RouteDetailDifficulty?,
        routeType: RouteDetailType?,
        routeDirection: Int?,
        coverUrl: String?,
        defaultMapId: String?,
        kmlUrl: String?,
        gpxUrl: String?,
        popularity: Int,
        usageCount: Int,
        isLoop: Bool,
        isFavorite: Bool,
        status: Int,
        createdAt: Int64,
        updatedAt: Int64,
        createdBy: String?,
        creator: RouteDetailCreator?,
        segmentSchemes: [RouteSegmentScheme],
        poiPoints: [RoutePOIPoint],
        dailyPlans: [RouteDailyPlan],
        tags: [String],
        imageUrls: [String],
        ratings: RouteRatings?,
        weatherInfo: RouteWeatherInfo?,
        hitchhikeContacts: [RouteHitchhikeContact],
        trackPoints: [RouteTrackPoint]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.regionId = regionId
        self.region = region
        self.distance = distance
        self.duration = duration
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.difficulty = difficulty
        self.routeType = routeType
        self.routeDirection = routeDirection
        self.coverUrl = coverUrl
        self.defaultMapId = defaultMapId
        self.kmlUrl = kmlUrl
        self.gpxUrl = gpxUrl
        self.popularity = popularity
        self.usageCount = usageCount
        self.isLoop = isLoop
        self.isFavorite = isFavorite
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.creator = creator
        self.segmentSchemes = segmentSchemes
        self.poiPoints = poiPoints
        self.dailyPlans = dailyPlans
        self.tags = tags
        self.imageUrls = imageUrls
        self.ratings = ratings
        self.weatherInfo = weatherInfo
        self.hitchhikeContacts = hitchhikeContacts
        self.trackPoints = trackPoints
    }
}

public enum RouteDetailDifficulty: Decodable, Equatable {
    case easy
    case moderate
    case hard
    case unknown(Int)

     public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(Int.self)
        switch value {
        case 1: self = .easy
        case 3: self = .moderate
        case 5: self = .hard
        default: self = .unknown(value)
        }
    }

     public var displayText: String {
        switch self {
        case .easy: "简单"
        case .moderate: "中等"
        case .hard: "困难"
        case .unknown: "暂无数据"
        }
    }
}

public enum RouteDetailType: Decodable, Equatable {
    case outAndBack
    case loop
    case oneWay
    case multiDay
    case unknown(Int)

     public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(Int.self)
        switch value {
        case 0: self = .outAndBack
        case 1: self = .loop
        case 2: self = .oneWay
        case 3: self = .multiDay
        default: self = .unknown(value)
        }
    }

     public var displayText: String {
        switch self {
        case .outAndBack: "往返"
        case .loop: "环线"
        case .oneWay: "单程"
        case .multiDay: "多日"
        case .unknown: "暂无数据"
        }
    }
}

public enum RouteDetailFormatting {
     public static func text(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "暂无数据"
        }
        return value
    }

     public static func number<T>(_ value: T?) -> String where T: Numeric {
        value.map(String.init(describing:)) ?? "—"
    }
}

public struct RouteDetailCreator: Decodable, Equatable {
     public let id: String
     public let username: String
     public let nickname: String
     public let email: String
     public let avatarUrl: String?
     public let createdAt: Int64

    public enum CodingKeys: String, CodingKey {
        case id, username, nickname, email
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
    }

    public init(
        id: String,
        username: String,
        nickname: String,
        email: String,
        avatarUrl: String?,
        createdAt: Int64
    ) {
        self.id = id
        self.username = username
        self.nickname = nickname
        self.email = email
        self.avatarUrl = avatarUrl
        self.createdAt = createdAt
    }
}

public struct RouteSegmentScheme: Decodable, Equatable {
     public let id: String
     public let routeId: String
     public let schemeType: String
     public let label: String
     public let isDefault: Bool
     public let segments: [RouteSegment]

    public enum CodingKeys: String, CodingKey {
        case id, label, segments
        case routeId = "route_id"
        case schemeType = "scheme_type"
        case isDefault = "is_default"
    }

    public init(
        id: String,
        routeId: String,
        schemeType: String,
        label: String,
        isDefault: Bool,
        segments: [RouteSegment]
    ) {
        self.id = id
        self.routeId = routeId
        self.schemeType = schemeType
        self.label = label
        self.isDefault = isDefault
        self.segments = segments
    }
}

public struct RouteSegment: Decodable, Equatable {
     public let id: String
     public let name: String
     public let description: String?
     public let distance: Double?
     public let elevationGain: Double?
     public let elevationLoss: Double?
     public let estimatedTime: Double?
     public let difficulty: RouteDetailDifficulty?
     public let routeType: RouteDetailType?
     public let notes: String?
     public let sequenceNumber: Int
     public let trackStartIndex: Int?
     public let trackEndIndex: Int?
     public let color: String?
     public let schemeType: String?
     public let startPoint: RouteWaypoint?
     public let endPoint: RouteWaypoint?
     public let keypoints: [RouteWaypoint]

    public enum CodingKeys: String, CodingKey {
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

    public init(
        id: String,
        name: String,
        description: String?,
        distance: Double?,
        elevationGain: Double?,
        elevationLoss: Double?,
        estimatedTime: Double?,
        difficulty: RouteDetailDifficulty?,
        routeType: RouteDetailType?,
        notes: String?,
        sequenceNumber: Int,
        trackStartIndex: Int?,
        trackEndIndex: Int?,
        color: String?,
        schemeType: String?,
        startPoint: RouteWaypoint?,
        endPoint: RouteWaypoint?,
        keypoints: [RouteWaypoint]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.distance = distance
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.estimatedTime = estimatedTime
        self.difficulty = difficulty
        self.routeType = routeType
        self.notes = notes
        self.sequenceNumber = sequenceNumber
        self.trackStartIndex = trackStartIndex
        self.trackEndIndex = trackEndIndex
        self.color = color
        self.schemeType = schemeType
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.keypoints = keypoints
    }
}

public struct RouteWaypoint: Decodable, Equatable {
     public let id: String
     public let name: String
     public let description: String?
     public let latitude: Double
     public let longitude: Double
     public let elevation: Double?
     public let type: String?
     public let iconUrl: String?
     public let imageUrl: String?
     public let sequenceNumber: Int
     public let createdAt: Date
     public let updatedAt: Date

    public enum CodingKeys: String, CodingKey {
        case id, name, description, latitude, longitude, elevation, type
        case iconUrl = "icon_url"
        case imageUrl = "image_url"
        case sequenceNumber = "sequence_number"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String,
        name: String,
        description: String?,
        latitude: Double,
        longitude: Double,
        elevation: Double?,
        type: String?,
        iconUrl: String?,
        imageUrl: String?,
        sequenceNumber: Int,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.type = type
        self.iconUrl = iconUrl
        self.imageUrl = imageUrl
        self.sequenceNumber = sequenceNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct RoutePOIPoint: Decodable, Equatable {
     public let id: String
     public let routeId: String
     public let name: String
     public let latitude: Double
     public let longitude: Double
     public let elevation: Double?
     public let category: String
     public let subCategory: String?
     public let source: String
     public let description: String?
     public let confidence: Double?

    public enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, elevation, category, source, description, confidence
        case routeId = "route_id"
        case subCategory = "sub_category"
    }

    public init(
        id: String,
        routeId: String,
        name: String,
        latitude: Double,
        longitude: Double,
        elevation: Double?,
        category: String,
        subCategory: String?,
        source: String,
        description: String?,
        confidence: Double?
    ) {
        self.id = id
        self.routeId = routeId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.category = category
        self.subCategory = subCategory
        self.source = source
        self.description = description
        self.confidence = confidence
    }
}

public struct RouteDailyPlan: Decodable, Equatable {
     public let id: String
     public let dayNumber: Int
     public let title: String
     public let description: String?
     public let distance: Double?
     public let estimatedTime: Double?
     public let elevationGain: Int?
     public let elevationLoss: Double?
     public let maxElevation: Double?
     public let minElevation: Double?
     public let accommodation: String?
     public let notes: String?
     public let createdAt: Date
     public let updatedAt: Date
     public let segments: [RouteDailyPlanSegment]

    public enum CodingKeys: String, CodingKey {
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

    public init(
        id: String,
        dayNumber: Int,
        title: String,
        description: String?,
        distance: Double?,
        estimatedTime: Double?,
        elevationGain: Int?,
        elevationLoss: Double?,
        maxElevation: Double?,
        minElevation: Double?,
        accommodation: String?,
        notes: String?,
        createdAt: Date,
        updatedAt: Date,
        segments: [RouteDailyPlanSegment]
    ) {
        self.id = id
        self.dayNumber = dayNumber
        self.title = title
        self.description = description
        self.distance = distance
        self.estimatedTime = estimatedTime
        self.elevationGain = elevationGain
        self.elevationLoss = elevationLoss
        self.maxElevation = maxElevation
        self.minElevation = minElevation
        self.accommodation = accommodation
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.segments = segments
    }
}

public struct RouteDailyPlanSegment: Decodable, Equatable {
     public let id: String
     public let sequenceNumber: Int
     public let segment: RouteSegment?

    public enum CodingKeys: String, CodingKey {
        case id, segment
        case sequenceNumber = "sequence_number"
    }

    public init(
        id: String,
        sequenceNumber: Int,
        segment: RouteSegment?
    ) {
        self.id = id
        self.sequenceNumber = sequenceNumber
        self.segment = segment
    }
}

public struct RouteRatings: Decodable, Equatable {
     public let overall: Double?
     public let scenery: Double?
     public let difficulty: Double?
     public let experience: Double?
     public let facilities: Double?
     public let ratingCount: Int

    public enum CodingKeys: String, CodingKey {
        case overall, scenery, difficulty, experience, facilities
        case ratingCount = "rating_count"
    }

    public init(
        overall: Double?,
        scenery: Double?,
        difficulty: Double?,
        experience: Double?,
        facilities: Double?,
        ratingCount: Int
    ) {
        self.overall = overall
        self.scenery = scenery
        self.difficulty = difficulty
        self.experience = experience
        self.facilities = facilities
        self.ratingCount = ratingCount
    }
}

public struct RouteWeatherInfo: Decodable, Equatable {
     public let description: String?
     public let precautions: String?
     public let bestSeasons: [String]
     public let seasonalWeather: [String: String]

    public enum CodingKeys: String, CodingKey {
        case description, precautions
        case bestSeasons = "best_seasons"
        case seasonalWeather = "seasonal_weather"
    }

    public init(
        description: String?,
        precautions: String?,
        bestSeasons: [String],
        seasonalWeather: [String: String]
    ) {
        self.description = description
        self.precautions = precautions
        self.bestSeasons = bestSeasons
        self.seasonalWeather = seasonalWeather
    }
}

public struct RouteHitchhikeContact: Decodable, Equatable {
     public let id: String
     public let name: String
     public let phone: String
     public let description: String?
     public let location: String?
     public let price: Double?
     public let lastVerified: Bool
     public let creator: RouteDetailCreator?
     public let createdAt: Int64
     public let updatedAt: Int64

    public enum CodingKeys: String, CodingKey {
        case id, name, phone, description, location, price, creator
        case lastVerified = "last_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String,
        name: String,
        phone: String,
        description: String?,
        location: String?,
        price: Double?,
        lastVerified: Bool,
        creator: RouteDetailCreator?,
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.id = id
        self.name = name
        self.phone = phone
        self.description = description
        self.location = location
        self.price = price
        self.lastVerified = lastVerified
        self.creator = creator
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct RouteTrackPoint: Decodable, Equatable {
     public let id: String
     public let name: String?
     public let latitude: Double
     public let longitude: Double
     public let elevation: Double?
     public let sequenceNumber: Int
     public let type: String?
     public let iconUrl: String?
     public let imageUrl: String?
     public let description: String?

    public enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, elevation, type, description
        case sequenceNumber = "sequence_number"
        case iconUrl = "icon_url"
        case imageUrl = "image_url"
    }

    public init(
        id: String,
        name: String?,
        latitude: Double,
        longitude: Double,
        elevation: Double?,
        sequenceNumber: Int,
        type: String?,
        iconUrl: String?,
        imageUrl: String?,
        description: String?
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.sequenceNumber = sequenceNumber
        self.type = type
        self.iconUrl = iconUrl
        self.imageUrl = imageUrl
        self.description = description
    }
}
