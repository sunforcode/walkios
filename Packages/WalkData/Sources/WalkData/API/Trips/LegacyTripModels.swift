import Foundation

public struct TripParticipantDTO: Codable, Equatable {
     public let id: String
     public let username: String
     public let nickname: String?
     public let avatarURL: String?

    public enum CodingKeys: String, CodingKey {
        case id, username, nickname
        case avatarURL = "avatar_url"
    }

    public init(
        id: String,
        username: String,
        nickname: String?,
        avatarURL: String?
    ) {
        self.id = id
        self.username = username
        self.nickname = nickname
        self.avatarURL = avatarURL
    }
}

public struct TripDailyPlanDTO: Codable, Equatable {
     public let day: Int
     public let date: Date?
     public let title: String
     public let description: String?

    public init(
        day: Int,
        date: Date?,
        title: String,
        description: String?
    ) {
        self.day = day
        self.date = date
        self.title = title
        self.description = description
    }
}

public struct TripResponseDTO: Codable, Equatable {
     public let id: String
     public let name: String
     public let description: String
     public let startDate: Date?
     public let endDate: Date?
     public let status: Int
     public let routeIDs: [String]
     public let primaryRouteID: String?
     public let participants: [TripParticipantDTO]
     public let participantCount: Int
     public let organizerID: String
     public let equipmentListID: String?
     public let mealPlanID: String?
     public let waterPlanID: String?
     public let itinerary: [TripDailyPlanDTO]
     public let coverURL: String?
     public let imageURLs: [String]?
     public let budget: Double?
     public let actualCost: Double?
     public let notes: String?
     public let privacySetting: String
     public let createdAt: Date
     public let updatedAt: Date

    public enum CodingKeys: String, CodingKey {
        case id, name, description, status, participants, itinerary, budget, notes
        case startDate = "start_date"
        case endDate = "end_date"
        case routeIDs = "route_ids"
        case primaryRouteID = "primary_route_id"
        case participantCount = "participant_count"
        case organizerID = "organizer_id"
        case equipmentListID = "equipment_list_id"
        case mealPlanID = "meal_plan_id"
        case waterPlanID = "water_plan_id"
        case coverURL = "cover_url"
        case imageURLs = "image_urls"
        case actualCost = "actual_cost"
        case privacySetting = "privacy_setting"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(
        id: String,
        name: String,
        description: String,
        startDate: Date?,
        endDate: Date?,
        status: Int,
        routeIDs: [String],
        primaryRouteID: String?,
        participants: [TripParticipantDTO],
        participantCount: Int,
        organizerID: String,
        equipmentListID: String?,
        mealPlanID: String?,
        waterPlanID: String?,
        itinerary: [TripDailyPlanDTO],
        coverURL: String?,
        imageURLs: [String]?,
        budget: Double?,
        actualCost: Double?,
        notes: String?,
        privacySetting: String,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.routeIDs = routeIDs
        self.primaryRouteID = primaryRouteID
        self.participants = participants
        self.participantCount = participantCount
        self.organizerID = organizerID
        self.equipmentListID = equipmentListID
        self.mealPlanID = mealPlanID
        self.waterPlanID = waterPlanID
        self.itinerary = itinerary
        self.coverURL = coverURL
        self.imageURLs = imageURLs
        self.budget = budget
        self.actualCost = actualCost
        self.notes = notes
        self.privacySetting = privacySetting
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct TripCreateRequestDTO: Encodable {
     public let name: String
     public let description: String?
     public let startDate: Date?
     public let endDate: Date?
     public let organizerID: String?
     public let routeIDs: [String]
     public let primaryRouteID: String?
     public let budget: Double?
     public let notes: String?
     public let privacySetting: Int
     public let coverURL: String?

    public enum CodingKeys: String, CodingKey {
        case name, description, budget, notes
        case startDate = "start_date"
        case endDate = "end_date"
        case organizerID = "organizer_id"
        case routeIDs = "route_ids"
        case primaryRouteID = "primary_route_id"
        case privacySetting = "privacy_setting"
        case coverURL = "cover_url"
    }

    public init(
        name: String,
        description: String?,
        startDate: Date?,
        endDate: Date?,
        organizerID: String?,
        routeIDs: [String],
        primaryRouteID: String?,
        budget: Double?,
        notes: String?,
        privacySetting: Int,
        coverURL: String?
    ) {
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.organizerID = organizerID
        self.routeIDs = routeIDs
        self.primaryRouteID = primaryRouteID
        self.budget = budget
        self.notes = notes
        self.privacySetting = privacySetting
        self.coverURL = coverURL
    }
}

public struct TripUpdateRequestDTO: Encodable {
     public let name: String?
     public let description: String?
     public let startDate: Date?
     public let endDate: Date?
     public let primaryRouteID: String?
     public let budget: Double?
     public let actualCost: Double?
     public let notes: String?
     public let privacySetting: Int?
     public let coverURL: String?

    public enum CodingKeys: String, CodingKey {
        case name, description, budget, notes
        case startDate = "start_date"
        case endDate = "end_date"
        case primaryRouteID = "primary_route_id"
        case actualCost = "actual_cost"
        case privacySetting = "privacy_setting"
        case coverURL = "cover_url"
    }

    public init(
        name: String?,
        description: String?,
        startDate: Date?,
        endDate: Date?,
        primaryRouteID: String?,
        budget: Double?,
        actualCost: Double?,
        notes: String?,
        privacySetting: Int?,
        coverURL: String?
    ) {
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.primaryRouteID = primaryRouteID
        self.budget = budget
        self.actualCost = actualCost
        self.notes = notes
        self.privacySetting = privacySetting
        self.coverURL = coverURL
    }
}

public struct Page<Value> {
     public let items: [Value]
     public let number: Int
     public let size: Int
     public let totalElements: Int
     public let totalPages: Int
     public let first: Bool
     public let last: Bool

    public init(
        items: [Value],
        number: Int,
        size: Int,
        totalElements: Int,
        totalPages: Int,
        first: Bool,
        last: Bool
    ) {
        self.items = items
        self.number = number
        self.size = size
        self.totalElements = totalElements
        self.totalPages = totalPages
        self.first = first
        self.last = last
    }
}

public extension PageDTO {
     public func map<Value>(_ transform: (Item) -> Value) -> Page<Value> {
        Page(
            items: items.map(transform),
            number: number,
            size: size,
            totalElements: totalElements,
            totalPages: totalPages,
            first: first,
            last: last
        )
    }
}

public extension Trip {
     public init(dto: TripResponseDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            description: dto.description,
            status: TripStatus(rawValue: dto.status),
            startDate: dto.startDate,
            endDate: dto.endDate,
            userId: dto.organizerID,
            routeId: dto.primaryRouteID,
            createdAt: dto.createdAt,
            updatedAt: dto.updatedAt
        )
    }
}

private enum LegacyTripRequestEncoder {
     public static func encode<Value: Encodable>(_ value: Value) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try? encoder.encode(value)
    }
}

public enum TripAPI {
    public struct List: APIRequest {
        public typealias Response = PageDTO<TripResponseDTO>
        public let method: APIHTTPMethod = .get
        public let path = "/legacy/trips"
        public let query: [URLQueryItem]

        public init(
            keyword: String? = nil,
            status: TripStatus? = nil,
            organizerID: String? = nil,
            participantID: String? = nil,
            page: Int = 0,
            size: Int = 20,
            sort: [String] = []
        ) {
            var query = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
            if let keyword { query.append(URLQueryItem(name: "keyword", value: keyword)) }
            if let status { query.append(URLQueryItem(name: "status", value: String(status.rawValue))) }
            if let organizerID { query.append(URLQueryItem(name: "organizerId", value: organizerID)) }
            if let participantID { query.append(URLQueryItem(name: "participantId", value: participantID)) }
            query.append(contentsOf: sort.map { URLQueryItem(name: "sort", value: $0) })
            self.query = query
        }
    }

    public struct Detail: APIRequest {
        public typealias Response = TripResponseDTO
        public let method: APIHTTPMethod = .get
        public let path: String
        public let storagePolicy: APIStoragePolicy = .store
        public init(id: String) { path = "/legacy/trips/\(id)" }
    }

    public struct Create: APIRequest {
        public typealias Response = TripResponseDTO
        public let method: APIHTTPMethod = .post
        public let path = "/legacy/trips"
        public let body: Data?
        public init(input: TripCreateRequestDTO) { body = LegacyTripRequestEncoder.encode(input) }
    }

    public struct Update: APIRequest {
        public typealias Response = TripResponseDTO
        public let method: APIHTTPMethod = .put
        public let path: String
        public let body: Data?
        public init(id: String, input: TripUpdateRequestDTO) {
            path = "/legacy/trips/\(id)"
            body = LegacyTripRequestEncoder.encode(input)
        }
    }

    public struct Delete: APIRequest {
        public typealias Response = EmptyResponse
        public let method: APIHTTPMethod = .delete
        public let path: String
        public init(id: String) { path = "/legacy/trips/\(id)" }
    }

    public struct UpdateStatus: APIRequest {
        public typealias Response = TripResponseDTO
        public let method: APIHTTPMethod = .patch
        public let path: String
        public let query: [URLQueryItem]
        public init(id: String, status: TripStatus) {
            path = "/legacy/trips/\(id)/status"
            query = [URLQueryItem(name: "status", value: String(status.rawValue))]
        }
    }
}
