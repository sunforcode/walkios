import Foundation

struct TripParticipantDTO: Codable, Equatable {
    let id: String
    let username: String
    let nickname: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, username, nickname
        case avatarURL = "avatar_url"
    }
}

struct TripDailyPlanDTO: Codable, Equatable {
    let day: Int
    let date: Date?
    let title: String
    let description: String?
}

struct TripResponseDTO: Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let startDate: Date?
    let endDate: Date?
    let status: Int
    let routeIDs: [String]
    let primaryRouteID: String?
    let participants: [TripParticipantDTO]
    let participantCount: Int
    let organizerID: String
    let equipmentListID: String?
    let mealPlanID: String?
    let waterPlanID: String?
    let itinerary: [TripDailyPlanDTO]
    let coverURL: String?
    let imageURLs: [String]?
    let budget: Double?
    let actualCost: Double?
    let notes: String?
    let privacySetting: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
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
}

struct TripCreateRequestDTO: Encodable {
    let name: String
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let organizerID: String?
    let routeIDs: [String]
    let primaryRouteID: String?
    let budget: Double?
    let notes: String?
    let privacySetting: Int
    let coverURL: String?

    enum CodingKeys: String, CodingKey {
        case name, description, budget, notes
        case startDate = "start_date"
        case endDate = "end_date"
        case organizerID = "organizer_id"
        case routeIDs = "route_ids"
        case primaryRouteID = "primary_route_id"
        case privacySetting = "privacy_setting"
        case coverURL = "cover_url"
    }
}

struct TripUpdateRequestDTO: Encodable {
    let name: String?
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let primaryRouteID: String?
    let budget: Double?
    let actualCost: Double?
    let notes: String?
    let privacySetting: Int?
    let coverURL: String?

    enum CodingKeys: String, CodingKey {
        case name, description, budget, notes
        case startDate = "start_date"
        case endDate = "end_date"
        case primaryRouteID = "primary_route_id"
        case actualCost = "actual_cost"
        case privacySetting = "privacy_setting"
        case coverURL = "cover_url"
    }
}

struct Page<Value> {
    let items: [Value]
    let number: Int
    let size: Int
    let totalElements: Int
    let totalPages: Int
    let first: Bool
    let last: Bool
}

extension PageDTO {
    func map<Value>(_ transform: (Item) -> Value) -> Page<Value> {
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

extension Trip {
    init(dto: TripResponseDTO) {
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
    static func encode<Value: Encodable>(_ value: Value) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return try? encoder.encode(value)
    }
}

enum TripAPI {
    struct List: APIRequest {
        typealias Response = PageDTO<TripResponseDTO>
        let method: APIHTTPMethod = .get
        let path = "/legacy/trips"
        let query: [URLQueryItem]

        init(
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

    struct Detail: APIRequest {
        typealias Response = TripResponseDTO
        let method: APIHTTPMethod = .get
        let path: String
        let storagePolicy: APIStoragePolicy = .store
        init(id: String) { path = "/legacy/trips/\(id)" }
    }

    struct Create: APIRequest {
        typealias Response = TripResponseDTO
        let method: APIHTTPMethod = .post
        let path = "/legacy/trips"
        let body: Data?
        init(input: TripCreateRequestDTO) { body = LegacyTripRequestEncoder.encode(input) }
    }

    struct Update: APIRequest {
        typealias Response = TripResponseDTO
        let method: APIHTTPMethod = .put
        let path: String
        let body: Data?
        init(id: String, input: TripUpdateRequestDTO) {
            path = "/legacy/trips/\(id)"
            body = LegacyTripRequestEncoder.encode(input)
        }
    }

    struct Delete: APIRequest {
        typealias Response = EmptyResponse
        let method: APIHTTPMethod = .delete
        let path: String
        init(id: String) { path = "/legacy/trips/\(id)" }
    }

    struct UpdateStatus: APIRequest {
        typealias Response = TripResponseDTO
        let method: APIHTTPMethod = .patch
        let path: String
        let query: [URLQueryItem]
        init(id: String, status: TripStatus) {
            path = "/legacy/trips/\(id)/status"
            query = [URLQueryItem(name: "status", value: String(status.rawValue))]
        }
    }
}
