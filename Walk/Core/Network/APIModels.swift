import Foundation

struct DataEnvelope<Value: Decodable>: Decodable {
    let data: Value
}

struct LocalDate: Codable, Hashable, Comparable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    var dateAtStartOfDay: Date? {
        Calendar.business.date(from: DateComponents(year: year, month: month, day: day))
    }

    static func < (left: LocalDate, right: LocalDate) -> Bool {
        (left.year, left.month, left.day) < (right.year, right.month, right.day)
    }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .business) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(
            year: components.year ?? 0,
            month: components.month ?? 0,
            day: components.day ?? 0
        )
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              let date = Calendar.business.date(
                from: DateComponents(year: year, month: month, day: day)
              ) else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Expected local date in YYYY-MM-DD format"
            )
        }
        let components = Calendar.business.dateComponents([.year, .month, .day], from: date)
        guard components.year == year, components.month == month, components.day == day else {
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid local date"
            )
        }
        self.init(year: year, month: month, day: day)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

struct ErrorEnvelope: Decodable {
    let error: APIErrorPayload
}

struct APIErrorPayload: Decodable {
    let code: String
    let message: String
    let retryable: Bool
    let details: APIErrorDetails?
}

struct APIErrorDetails: Codable, Equatable {
    let requestedTargetRouteVersionId: String?
    let currentPublicRouteVersionId: String?
    let retryAvailableAt: Date?

    init(
        requestedTargetRouteVersionId: String? = nil,
        currentPublicRouteVersionId: String? = nil,
        retryAvailableAt: Date? = nil
    ) {
        self.requestedTargetRouteVersionId = requestedTargetRouteVersionId
        self.currentPublicRouteVersionId = currentPublicRouteVersionId
        self.retryAvailableAt = retryAvailableAt
    }
}

struct APIEnvelope<Value: Decodable>: Decodable {
    let success: Bool
    let message: String
    let data: Value?
    let timestamp: Date
    let code: Int

    func unwrap() throws -> Value {
        guard success else {
            throw APIClientError.business(message: message, code: code)
        }
        if let data { return data }
        if Value.self == EmptyResponse.self, let empty = EmptyResponse() as? Value {
            return empty
        }
        throw APIClientError.decoding("成功响应缺少 data")
    }
}

struct PageDTO<Item: Decodable>: Decodable {
    let items: [Item]
    let number: Int
    let size: Int
    let totalElements: Int
    let totalPages: Int
    let first: Bool
    let last: Bool

    enum CodingKeys: String, CodingKey {
        case items = "content"
        case number
        case size
        case totalElements
        case totalPages
        case first
        case last
    }
}

struct EmptyResponse: Codable, Equatable {
    init() {}
}

enum APIJSONDecoder {
    static func make() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let seconds = try? container.decode(Double.self) {
                return Date(timeIntervalSince1970: seconds)
            }
            let value = try container.decode(String.self)
            if let date = ISO8601DateFormatter.apiWithFractionalSeconds.date(from: value)
                ?? ISO8601DateFormatter.api.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected epoch seconds or ISO-8601 date")
        }
        return decoder
    }
}

extension ISO8601DateFormatter {
    fileprivate static let api: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    fileprivate static let apiWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension APIJSONDecoder {
    static func decode<Response: Decodable>(
        _ response: Response.Type,
        from data: Data,
        envelope: APIResponseEnvelope = .legacy
    ) throws -> Response {
        do {
            switch envelope {
            case .legacy:
                return try make().decode(APIEnvelope<Response>.self, from: data).unwrap()
            case .data:
                return try make().decode(DataEnvelope<Response>.self, from: data).data
            }
        } catch let error as APIClientError {
            throw error
        } catch {
            throw APIClientError.decoding(error.localizedDescription)
        }
    }

    static func apiError(from data: Data) -> APIClientError? {
        guard let envelope = try? make().decode(ErrorEnvelope.self, from: data) else { return nil }
        return .api(
            code: envelope.error.code,
            message: envelope.error.message,
            retryable: envelope.error.retryable,
            details: envelope.error.details
        )
    }

    static func businessError(from data: Data) -> APIClientError? {
        if let error = apiError(from: data) { return error }
        guard let envelope = try? make().decode(APIEnvelope<EmptyResponse>.self, from: data), !envelope.success else {
            return nil
        }
        return .business(message: envelope.message, code: envelope.code)
    }
}

enum AccountAPI {
    struct SendVerificationCode: APIRequest {
        typealias Response = VerificationCodeResponse
        let method: APIHTTPMethod = .post
        let path = "/auth/verification-codes"
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data
        let authenticationPolicy: APIAuthenticationPolicy = .none

        init(phone: String) throws {
            body = try JSONEncoder().encode(SendVerificationCodeBody(phone: phone))
        }
    }

    struct CreateSession: APIRequest {
        typealias Response = AuthSessionResponse
        let method: APIHTTPMethod = .post
        let path = "/auth/session"
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data
        let authenticationPolicy: APIAuthenticationPolicy = .none

        init(verificationID: String, code: String) throws {
            body = try JSONEncoder().encode(CreateSessionBody(verificationId: verificationID, code: code))
        }
    }

    struct Current: APIRequest {
        typealias Response = AccountResponse
        let method: APIHTTPMethod = .get
        let path = "/account"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
    }

    struct UpdateProfile: APIRequest {
        typealias Response = ProfileResponse
        let method: APIHTTPMethod = .patch
        let path = "/account/profile"
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(update: ProfileUpdate) throws {
            body = try JSONEncoder().encode(update)
        }
    }

    struct UploadAvatar: APIRequest {
        typealias Response = AvatarMediaResponse
        let method: APIHTTPMethod = .post
        let path = "/account/profile/avatar-media"
        let body: Data?
        let contentType: String?
        let responseEnvelope: APIResponseEnvelope = .data

        init(data: Data, contentType: String) {
            body = data
            self.contentType = contentType
        }
    }

    struct Logout: APIRequest {
        typealias Response = LogoutResponse
        let method: APIHTTPMethod = .delete
        let path = "/auth/session"
        let responseEnvelope: APIResponseEnvelope = .data
    }
}

private struct SendVerificationCodeBody: Encodable { let phone: String }
private struct CreateSessionBody: Encodable { let verificationId: String; let code: String }

struct VerificationCodeResponse: Codable, Equatable {
    let verificationId: String
    let expiresAt: Date
    let resendAvailableAt: Date
}

struct AuthSessionResponse: Codable, Equatable {
    let accessToken: String
    let tokenType: String
}

struct AccountResponse: Codable, Equatable {
    let account: AccountProjection
    let profile: ProfileProjection
}

struct AccountProjection: Codable, Equatable { let identity: String }
struct ProfileResponse: Codable, Equatable { let profile: ProfileProjection }

struct ProfileProjection: Codable, Equatable {
    let identity: String
    let maskedPhone: String
    let nickname: String?
    let avatar: String?
}

struct AvatarMediaResponse: Codable, Equatable { let mediaReference: String }
struct LogoutResponse: Codable, Equatable { let loggedOut: Bool }

struct RouteDistance: Codable, Equatable { let meters: Double }
struct RouteElevation: Codable, Equatable { let meters: Double }
struct RouteElevationGain: Codable, Equatable { let meters: Double }
struct RouteElevationLoss: Codable, Equatable { let meters: Double }
struct RouteDuration: Codable, Equatable { let seconds: Double }

struct PublicRouteDiscoveryResult: Codable, Equatable {
    let items: [PublicRouteBrowseSummary]
}

struct PublicRouteCollectionResult: Codable, Equatable {
    let items: [PublicRouteBrowseSummary]
}

enum PublicRouteSearchState: String, Codable, Equatable {
    case initial
    case completed
}

struct PublicRouteSearchResult: Codable, Equatable {
    let state: PublicRouteSearchState
    let items: [PublicRouteSearchSummary]
}

struct PublicRouteBrowseSummary: Codable, Equatable, Identifiable {
    let routeId: String
    let currentVersionId: String
    let cover: String?
    let name: String?
    let region: String?
    let difficulty: String?
    let distance: RouteDistance?
    let ascent: RouteElevationGain?
    let estimatedDuration: RouteDuration?

    var id: String { routeId }

    enum CodingKeys: String, CodingKey {
        case routeId, currentVersionId
        case cover, name, region, difficulty, distance, ascent, estimatedDuration
    }
}

struct PublicRouteSearchSummary: Codable, Equatable, Identifiable {
    let routeId: String
    let currentVersionId: String
    let cover: String?
    let name: String?
    let region: String?
    let difficulty: String?
    let distance: RouteDistance?
    let estimatedDuration: RouteDuration?

    var id: String { routeId }

    enum CodingKeys: String, CodingKey {
        case routeId, currentVersionId
        case cover, name, region, difficulty, distance, estimatedDuration
    }
}

struct PublicRouteDetail: Codable, Equatable {
    let routeId: String
    let currentVersion: PublicRouteVersionDetail
}

enum PublicRouteType: String, Codable, Equatable {
    case oneDay = "one_day"
    case multiDay = "multi_day"
}

enum MainTrackAvailability: String, Codable, Equatable {
    case missing
    case processing
    case pendingReview = "pending_review"
    case valid
    case invalidated
}

enum RouteGenerationMissingReason: String, Codable, Equatable {
    case name
    case region
    case estimatedDuration
    case start
    case end
    case validMainTrack
}

enum PublicRouteImageRole: String, Codable, Equatable {
    case cover
    case environment
}

struct PublicRouteVersionDetail: Codable, Equatable {
    let versionId: String
    let summary: PublicRouteSummary
    let mainTrackAvailability: MainTrackAvailability
    let generationEligibility: RouteGenerationEligibility
    let versionLabel: String?
    let mainTrack: PublicRouteMainTrack?
    let elevationProfile: PublicRouteElevationProfile?
    let professionalAnalysis: PublicRouteProfessionalAnalysis?
    let referenceDays: [PublicRouteReferenceDay]?
    let segments: [PublicRouteSegment]?
    let keyPoints: [PublicRouteNamedPoint]?
    let interestPoints: [PublicRouteNamedPoint]?
    let campsites: [PublicRouteCampsite]?
    let overnightPlaces: [PublicRouteOvernightPlace]?
    let waterSources: [PublicRouteWaterSource]?
    let supplyPoints: [PublicRouteSupplyPoint]?
    let communicationAndSafety: PublicRouteCommunicationAndSafety?
    let seasonalWeather: PublicRouteSeasonalWeather?
    let seasonalEquipmentRecommendations: [PublicRouteSeasonalEquipmentRecommendation]?
    let images: [PublicRouteImage]?

    init(
        versionId: String,
        summary: PublicRouteSummary,
        mainTrackAvailability: MainTrackAvailability,
        generationEligibility: RouteGenerationEligibility,
        versionLabel: String? = nil,
        mainTrack: PublicRouteMainTrack? = nil,
        elevationProfile: PublicRouteElevationProfile? = nil,
        professionalAnalysis: PublicRouteProfessionalAnalysis? = nil,
        referenceDays: [PublicRouteReferenceDay]? = nil,
        segments: [PublicRouteSegment]? = nil,
        keyPoints: [PublicRouteNamedPoint]? = nil,
        interestPoints: [PublicRouteNamedPoint]? = nil,
        campsites: [PublicRouteCampsite]? = nil,
        overnightPlaces: [PublicRouteOvernightPlace]? = nil,
        waterSources: [PublicRouteWaterSource]? = nil,
        supplyPoints: [PublicRouteSupplyPoint]? = nil,
        communicationAndSafety: PublicRouteCommunicationAndSafety? = nil,
        seasonalWeather: PublicRouteSeasonalWeather? = nil,
        seasonalEquipmentRecommendations: [PublicRouteSeasonalEquipmentRecommendation]? = nil,
        images: [PublicRouteImage]? = nil
    ) {
        self.versionId = versionId
        self.summary = summary
        self.mainTrackAvailability = mainTrackAvailability
        self.generationEligibility = generationEligibility
        self.versionLabel = versionLabel
        self.mainTrack = mainTrack
        self.elevationProfile = elevationProfile
        self.professionalAnalysis = professionalAnalysis
        self.referenceDays = referenceDays
        self.segments = segments
        self.keyPoints = keyPoints
        self.interestPoints = interestPoints
        self.campsites = campsites
        self.overnightPlaces = overnightPlaces
        self.waterSources = waterSources
        self.supplyPoints = supplyPoints
        self.communicationAndSafety = communicationAndSafety
        self.seasonalWeather = seasonalWeather
        self.seasonalEquipmentRecommendations = seasonalEquipmentRecommendations
        self.images = images
    }

    enum CodingKeys: String, CodingKey {
        case versionId, summary, mainTrackAvailability, generationEligibility, versionLabel
        case mainTrack, elevationProfile, professionalAnalysis, referenceDays, segments
        case keyPoints, interestPoints, campsites, overnightPlaces, waterSources
        case supplyPoints, communicationAndSafety, seasonalWeather
        case seasonalEquipmentRecommendations, images
    }
}

struct PublicRouteSummary: Codable, Equatable {
    let routeType: PublicRouteType
    let name: String?
    let region: String?
    let start: PublicRoutePlace?
    let end: PublicRoutePlace?
    let estimatedDuration: RouteDuration?
    let difficulty: String?
    let direction: String?
    let distance: RouteDistance?
    let ascent: RouteElevationGain?
    let descent: RouteElevationLoss?
    let maxElevation: RouteElevation?
    let suggestedDays: Int?
    let tags: [String]?
    let introduction: String?

    init(
        routeType: PublicRouteType,
        name: String? = nil,
        region: String? = nil,
        start: PublicRoutePlace? = nil,
        end: PublicRoutePlace? = nil,
        estimatedDuration: RouteDuration? = nil,
        difficulty: String? = nil,
        direction: String? = nil,
        distance: RouteDistance? = nil,
        ascent: RouteElevationGain? = nil,
        descent: RouteElevationLoss? = nil,
        maxElevation: RouteElevation? = nil,
        suggestedDays: Int? = nil,
        tags: [String]? = nil,
        introduction: String? = nil
    ) {
        self.routeType = routeType
        self.name = name
        self.region = region
        self.start = start
        self.end = end
        self.estimatedDuration = estimatedDuration
        self.difficulty = difficulty
        self.direction = direction
        self.distance = distance
        self.ascent = ascent
        self.descent = descent
        self.maxElevation = maxElevation
        self.suggestedDays = suggestedDays
        self.tags = tags
        self.introduction = introduction
    }

    enum CodingKeys: String, CodingKey {
        case routeType, name, region, start, end, estimatedDuration
        case difficulty, direction, distance, ascent, descent, maxElevation, suggestedDays, tags, introduction
    }
}

struct PublicRoutePlace: Codable, Equatable {
    let name: String
    let position: PublicRouteGeoPosition?

    init(name: String, position: PublicRouteGeoPosition? = nil) {
        self.name = name
        self.position = position
    }
}

struct PublicRouteGeoPosition: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let referenceSystem: String
}

struct PublicRouteMainTrack: Codable, Equatable {
    let identity: String
    let path: [PublicRouteGeoPosition]
}

struct PublicRoutePathPosition: Codable, Equatable {
    let precedingPositionIndex: Int
    let progressToNextPosition: Double?
}

struct PublicRouteMainTrackRange: Codable, Equatable {
    let startPathPosition: PublicRoutePathPosition
    let endPathPosition: PublicRoutePathPosition
}

struct PublicRouteElevationSample: Codable, Equatable, Identifiable {
    let identity: String
    let distance: RouteDistance
    let elevation: RouteElevation
    var id: String { identity }
}

struct PublicRouteElevationProfile: Codable, Equatable {
    let minElevation: RouteElevation
    let maxElevation: RouteElevation
    let samples: [PublicRouteElevationSample]
}

struct PublicRouteProfessionalAnalysis: Codable, Equatable {
    let fitnessRequirement: QualifiedString?
    let experienceRequirement: QualifiedString?
    let mainTerrain: QualifiedString?
    let technicalDifficulty: QualifiedString?
    let highAltitudeImpact: QualifiedString?
    let exposedSections: QualifiedString?
    let dangerAreas: QualifiedString?
    let signalCoverage: QualifiedString?
    let evacuationDifficulty: QualifiedString?
}

struct PublicRouteReferenceDay: Codable, Equatable, Identifiable {
    let identity: String
    let dayNumber: Int
    let title: String?
    let start: PublicRoutePlace?
    let end: PublicRoutePlace?
    let distance: RouteDistance?
    let estimatedDuration: RouteDuration?
    let ascent: RouteElevationGain?
    let descent: RouteElevationLoss?
    let maxElevation: RouteElevation?
    let minElevation: RouteElevation?
    let accommodation: String?
    let notes: String?
    var id: String { identity }
}

struct RouteGenerationEligibility: Codable, Equatable {
    let eligible: Bool
    let missingReasons: [RouteGenerationMissingReason]?

    init(eligible: Bool, missingReasons: [RouteGenerationMissingReason]? = nil) {
        self.eligible = eligible
        self.missingReasons = missingReasons
    }

    enum CodingKeys: String, CodingKey {
        case eligible, missingReasons
    }
}

struct PublicRouteSegment: Codable, Equatable, Identifiable {
    let identity: String
    let order: Int
    let name: String
    let start: PublicRoutePlace?
    let end: PublicRoutePlace?
    let distance: RouteDistance?
    let estimatedDuration: RouteDuration?
    let ascent: RouteElevationGain?
    let descent: RouteElevationLoss?
    let difficulty: String?
    let terrainOrRoadType: String?
    let description: String?
    let notes: String?
    let mainTrackRange: PublicRouteMainTrackRange?

    var id: String { identity }

    init(
        identity: String,
        order: Int,
        name: String,
        start: PublicRoutePlace? = nil,
        end: PublicRoutePlace? = nil,
        distance: RouteDistance? = nil,
        estimatedDuration: RouteDuration? = nil,
        ascent: RouteElevationGain? = nil,
        descent: RouteElevationLoss? = nil,
        difficulty: String? = nil,
        terrainOrRoadType: String? = nil,
        description: String? = nil,
        notes: String? = nil,
        mainTrackRange: PublicRouteMainTrackRange? = nil
    ) {
        self.identity = identity
        self.order = order
        self.name = name
        self.start = start
        self.end = end
        self.distance = distance
        self.estimatedDuration = estimatedDuration
        self.ascent = ascent
        self.descent = descent
        self.difficulty = difficulty
        self.terrainOrRoadType = terrainOrRoadType
        self.description = description
        self.notes = notes
        self.mainTrackRange = mainTrackRange
    }

    enum CodingKeys: String, CodingKey {
        case identity, order, name, start, end, distance, estimatedDuration
        case ascent, descent, difficulty, terrainOrRoadType, description, notes, mainTrackRange
    }
}

struct PublicRouteNamedPoint: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let positions: [PublicRouteGeoPosition]
    let category: String?
    let description: String?
    let elevation: RouteElevation?
    let media: [String]?

    var id: String { identity }

    init(
        identity: String,
        name: String,
        positions: [PublicRouteGeoPosition],
        category: String? = nil,
        description: String? = nil,
        elevation: RouteElevation? = nil,
        media: [String]? = nil
    ) {
        self.identity = identity
        self.name = name
        self.positions = positions
        self.category = category
        self.description = description
        self.elevation = elevation
        self.media = media
    }
}

struct PublicRouteCampsite: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let positions: [PublicRouteGeoPosition]
    let elevation: RouteElevation?
    let details: String?
    let status: String?

    var id: String { identity }
}

struct PublicRouteOvernightPlace: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let positions: [PublicRouteGeoPosition]
    let elevation: RouteElevation?
    let type: String?
    let facilities: [String]?
    let details: String?
    let status: String?

    var id: String { identity }
}

struct PublicRouteWaterSource: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let positions: [PublicRouteGeoPosition]
    let elevation: RouteElevation?
    let sourceType: String?
    let seasonalReliability: String?
    let treatmentRecommended: Bool?
    let treatmentAdvice: String?
    let description: String?

    var id: String { identity }

    enum CodingKeys: String, CodingKey {
        case identity, name, positions, elevation, sourceType, seasonalReliability
        case treatmentRecommended, treatmentAdvice, description
    }
}

struct PublicRouteSupplyPoint: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let positions: [PublicRouteGeoPosition]
    let supplyType: String?
    let availableItems: [String]?
    let description: String?

    var id: String { identity }

    enum CodingKeys: String, CodingKey {
        case identity, name, positions, supplyType, availableItems, description
    }
}

struct PublicRouteCommunicationAndSafety: Codable, Equatable {
    let coverageSummary: String?
    let notices: [PublicRouteSafetyNotice]?

    init(coverageSummary: String? = nil, notices: [PublicRouteSafetyNotice]? = nil) {
        self.coverageSummary = coverageSummary
        self.notices = notices
    }
}

struct PublicRouteSafetyNotice: Codable, Equatable, Identifiable {
    let identity: String
    let kind: String
    let title: String
    let description: String
    let positions: [PublicRouteGeoPosition]?

    var id: String { identity }
}

struct PublicRouteSeasonalWeather: Codable, Equatable {
    let bestSeasons: [String]?
    let conditions: [PublicRouteSeasonalWeatherCondition]?
}

struct PublicRouteSeasonalWeatherCondition: Codable, Equatable, Identifiable {
    let identity: String
    let season: String
    let typicalWeather: String?
    let environmentalRisks: [String]?
    let notes: String?
    var id: String { identity }
}

enum PublicRouteEquipmentRecommendationLevel: String, Codable, Equatable {
    case required
    case recommended
}

struct PublicRouteSeasonalEquipmentRecommendation: Codable, Equatable, Identifiable {
    let identity: String
    let seasonOrCondition: String
    let name: String
    let level: PublicRouteEquipmentRecommendationLevel
    let reason: String?
    var id: String { identity }
}

struct PublicRouteImage: Codable, Equatable, Identifiable {
    let identity: String
    let mediaReference: String
    let role: PublicRouteImageRole
    let caption: String?
    let position: PublicRouteGeoPosition?

    var id: String { identity }

    init(
        identity: String,
        mediaReference: String,
        role: PublicRouteImageRole,
        caption: String? = nil,
        position: PublicRouteGeoPosition? = nil
    ) {
        self.identity = identity
        self.mediaReference = mediaReference
        self.role = role
        self.caption = caption
        self.position = position
    }

    enum CodingKeys: String, CodingKey {
        case identity, mediaReference, role, caption, position
    }
}

struct EquipmentWeight: Codable, Equatable {
    let grams: Int
}

struct PersonalEquipment: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let ownedQuantity: Int
    let unitWeight: EquipmentWeight?

    var id: String { identity }
}

struct PersonalEquipmentSummary: Codable, Equatable {
    let equipmentItemCount: Int
    let equipmentListCount: Int
    let knownTotalWeight: EquipmentWeight
    let missingWeightItemCount: Int
}

struct PersonalEquipmentCollection: Codable, Equatable {
    let items: [PersonalEquipment]
    let summary: PersonalEquipmentSummary
}

struct PersonalEquipmentMutation: Codable, Equatable {
    let item: PersonalEquipment
    let summary: PersonalEquipmentSummary
}

struct EquipmentListReference: Codable, Equatable, Identifiable {
    let identity: String
    let name: String

    var id: String { identity }
}

struct PersonalEquipmentDeletionImpact: Codable, Equatable {
    let personalEquipmentId: String
    let equipmentListReferenceCount: Int
    let affectedEquipmentLists: [EquipmentListReference]
}

struct PersonalEquipmentDeletionResult: Codable, Equatable {
    let deletedPersonalEquipmentId: String
    let removedEquipmentListReferenceCount: Int
    let summary: PersonalEquipmentSummary
}

struct EquipmentListSummary: Codable, Equatable {
    let itemCount: Int
    let knownTotalWeight: EquipmentWeight
    let missingWeightItemCount: Int
}

struct EquipmentListOverview: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let summary: EquipmentListSummary

    var id: String { identity }
}

struct EquipmentListCollection: Codable, Equatable {
    let items: [EquipmentListOverview]
}

struct EquipmentListMember: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let ownedQuantity: Int
    let unitWeight: EquipmentWeight?
    let quantity: Int

    var id: String { identity }
}

struct EquipmentListDetail: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let members: [EquipmentListMember]
    let summary: EquipmentListSummary

    var id: String { identity }
}

struct EquipmentListCreateResult: Codable, Equatable {
    let equipmentList: EquipmentListDetail
    let personalEquipmentSummary: PersonalEquipmentSummary
}

struct EquipmentListMutation: Codable, Equatable {
    let equipmentList: EquipmentListDetail
}

struct EquipmentListDeletionResult: Codable, Equatable {
    let deletedEquipmentListId: String
    let personalEquipmentSummary: PersonalEquipmentSummary
}

enum PersonalEquipmentUpdateField<Value: Encodable & Equatable>: Encodable, Equatable {
    case unchanged
    case value(Value)
    case clear

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .unchanged, .clear:
            try container.encodeNil()
        case .value(let value):
            try container.encode(value)
        }
    }
}

struct PersonalEquipmentUpdate: Encodable, Equatable {
    let name: String?
    let ownedQuantity: Int?
    let unitWeight: PersonalEquipmentUpdateField<EquipmentWeight>

    init(
        name: String? = nil,
        ownedQuantity: Int? = nil,
        unitWeight: PersonalEquipmentUpdateField<EquipmentWeight> = .unchanged
    ) {
        self.name = name
        self.ownedQuantity = ownedQuantity
        self.unitWeight = unitWeight
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name { try container.encode(name, forKey: .name) }
        if let ownedQuantity { try container.encode(ownedQuantity, forKey: .ownedQuantity) }
        if unitWeight != .unchanged { try container.encode(unitWeight, forKey: .unitWeight) }
    }

    private enum CodingKeys: String, CodingKey {
        case name, ownedQuantity, unitWeight
    }
}

enum PersonalEquipmentAPI {
    struct Collection: APIRequest {
        typealias Response = PersonalEquipmentCollection
        let method: APIHTTPMethod = .get
        let path = "/personal-equipment"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
    }

    struct Create: APIRequest {
        typealias Response = PersonalEquipmentMutation
        let method: APIHTTPMethod = .post
        let path = "/personal-equipment"
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(name: String, ownedQuantity: Int, unitWeightGrams: Int?) throws {
            body = try JSONEncoder().encode(CreatePersonalEquipmentBody(
                name: name,
                ownedQuantity: ownedQuantity,
                unitWeight: unitWeightGrams.map(EquipmentWeight.init(grams:))
            ))
        }
    }

    struct Detail: APIRequest {
        typealias Response = PersonalEquipment
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store

        init(personalEquipmentID: String) {
            path = "/personal-equipment/\(personalEquipmentID)"
        }
    }

    struct Update: APIRequest {
        typealias Response = PersonalEquipmentMutation
        let method: APIHTTPMethod = .patch
        let path: String
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(personalEquipmentID: String, update: PersonalEquipmentUpdate) throws {
            path = "/personal-equipment/\(personalEquipmentID)"
            body = try JSONEncoder().encode(update)
        }
    }

    struct DeletionImpact: APIRequest {
        typealias Response = PersonalEquipmentDeletionImpact
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data

        init(personalEquipmentID: String) {
            path = "/personal-equipment/\(personalEquipmentID)/deletion-impact"
        }
    }

    struct Delete: APIRequest {
        typealias Response = PersonalEquipmentDeletionResult
        let method: APIHTTPMethod = .delete
        let path: String
        let query = [URLQueryItem(name: "confirmListRemoval", value: "true")]
        let responseEnvelope: APIResponseEnvelope = .data

        init(personalEquipmentID: String) {
            path = "/personal-equipment/\(personalEquipmentID)"
        }
    }
}

enum EquipmentListAPI {
    struct Collection: APIRequest {
        typealias Response = EquipmentListCollection
        let method: APIHTTPMethod = .get
        let path = "/equipment-lists"
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store
    }

    struct Create: APIRequest {
        typealias Response = EquipmentListCreateResult
        let method: APIHTTPMethod = .post
        let path = "/equipment-lists"
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(name: String) throws {
            body = try JSONEncoder().encode(EquipmentListNameBody(name: name))
        }
    }

    struct Detail: APIRequest {
        typealias Response = EquipmentListDetail
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store

        init(equipmentListID: String) {
            path = "/equipment-lists/\(equipmentListID)"
        }
    }

    struct Rename: APIRequest {
        typealias Response = EquipmentListMutation
        let method: APIHTTPMethod = .patch
        let path: String
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(equipmentListID: String, name: String) throws {
            path = "/equipment-lists/\(equipmentListID)"
            body = try JSONEncoder().encode(EquipmentListNameBody(name: name))
        }
    }

    struct Delete: APIRequest {
        typealias Response = EquipmentListDeletionResult
        let method: APIHTTPMethod = .delete
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data

        init(equipmentListID: String) {
            path = "/equipment-lists/\(equipmentListID)"
        }
    }

    struct PutMember: APIRequest {
        typealias Response = EquipmentListMutation
        let method: APIHTTPMethod = .put
        let path: String
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(equipmentListID: String, personalEquipmentID: String, quantity: Int) throws {
            path = "/equipment-lists/\(equipmentListID)/members/\(personalEquipmentID)"
            body = try JSONEncoder().encode(EquipmentListMemberBody(quantity: quantity))
        }
    }

    struct DeleteMember: APIRequest {
        typealias Response = EquipmentListMutation
        let method: APIHTTPMethod = .delete
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data

        init(equipmentListID: String, personalEquipmentID: String) {
            path = "/equipment-lists/\(equipmentListID)/members/\(personalEquipmentID)"
        }
    }
}

private struct CreatePersonalEquipmentBody: Encodable {
    let name: String
    let ownedQuantity: Int
    let unitWeight: EquipmentWeight?
}

private struct EquipmentListNameBody: Encodable { let name: String }
private struct EquipmentListMemberBody: Encodable { let quantity: Int }

struct FrozenRouteBasis: Codable, Equatable {
    let routeName: String
    let routeType: String
    let region: String
    let start: PublicRoutePlace
    let end: PublicRoutePlace
    let estimatedDuration: RouteDuration
    let mainTrackPath: [PublicRouteGeoPosition]
    let versionLabel: String?
    let cover: String?
    let direction: String?
    let distance: RouteDistance?
    let ascent: RouteElevationGain?
    let descent: RouteElevationLoss?
    let maxElevation: RouteElevation?

    enum CodingKeys: String, CodingKey {
        case routeName, routeType, region, start, end, estimatedDuration
        case mainTrackPath, versionLabel, cover, direction, distance, ascent, descent, maxElevation
    }
}

struct PersonalTripRouteReference: Codable, Equatable {
    let routeID: String
    let adoptedRouteVersionID: String

    enum CodingKeys: String, CodingKey {
        case routeID = "routeId"
        case adoptedRouteVersionID = "adoptedRouteVersionId"
    }
}

enum PersonalTripStatus: String, Codable, Equatable {
    case planned
    case inProgress = "in_progress"
    case completed
    case cancelled

    var title: String {
        switch self {
        case .planned: "规划中"
        case .inProgress: "进行中"
        case .completed: "已完成"
        case .cancelled: "已取消"
        }
    }
}

struct PersonalTripSummary: Codable, Equatable, Identifiable {
    let tripID: String
    let revision: String
    let name: String
    let status: PersonalTripStatus
    let routeReference: PersonalTripRouteReference
    let routeName: String
    let routeType: String
    let start: PublicRoutePlace
    let end: PublicRoutePlace
    let estimatedDuration: RouteDuration
    let startDate: LocalDate
    let endDate: LocalDate
    let totalDayCount: Int
    let hikingDayCount: Int
    let versionLabel: String?
    let cover: String?
    let direction: String?
    let distance: RouteDistance?
    let ascent: RouteElevationGain?

    var id: String { tripID }

    var dateRangeDescription: String {
        startDate == endDate ? startDate.description : "\(startDate) - \(endDate)"
    }

    enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case revision, name, status, routeReference, routeName, routeType
        case start, end, estimatedDuration, startDate, endDate
        case totalDayCount, hikingDayCount, versionLabel, cover, direction, distance, ascent
    }
}

struct PersonalTripFocus: Codable, Equatable {
    let trip: PersonalTripSummary?
}

struct PersonalTripCollection: Codable, Equatable {
    let currentTrips: [PersonalTripSummary]
    let historicalTrips: [PersonalTripSummary]
}

struct PersonalTripCalendarDay: Codable, Equatable, Identifiable {
    let date: LocalDate
    let tripCount: Int

    var id: LocalDate { date }
}

struct PersonalTripCalendar: Codable, Equatable {
    let windowStartDate: LocalDate
    let windowEndDate: LocalDate
    let days: [PersonalTripCalendarDay]
}

struct InformationConfidence: Codable, Equatable {
    let status: String
    let category: String?
}

struct QualifiedString: Codable, Equatable {
    let value: String?
    let confidence: InformationConfidence?
}

struct QualifiedStringList: Codable, Equatable {
    let value: [String]?
    let confidence: InformationConfidence?
}

struct QualifiedInteger: Codable, Equatable {
    let value: Int?
    let confidence: InformationConfidence?
}

struct QualifiedDuration: Codable, Equatable {
    let value: RouteDuration?
    let confidence: InformationConfidence?
}

struct QualifiedDistance: Codable, Equatable {
    let value: RouteDistance?
    let confidence: InformationConfidence?
}

struct QualifiedPlace: Codable, Equatable {
    let value: PublicRoutePlace?
    let confidence: InformationConfidence?
}

struct QualifiedPosition: Codable, Equatable {
    let value: PublicRouteGeoPosition?
    let confidence: InformationConfidence?
}

indirect enum QualifiedJSONValue: Codable, Equatable {
    case null
    case string(String)
    case number(Double)
    case boolean(Bool)
    case array([QualifiedJSONValue])
    case object([String: QualifiedJSONValue])

    var text: String? {
        switch self {
        case .null, .array, .object:
            nil
        case .string(let value):
            value
        case .number(let value):
            String(value)
        case .boolean(let value):
            String(value)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([QualifiedJSONValue].self) {
            self = .array(value)
        } else if let value = try? container.decode([String: QualifiedJSONValue].self) {
            self = .object(value)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .boolean(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }
}

struct QualifiedJSON: Codable, Equatable {
    let value: QualifiedJSONValue?
    let confidence: InformationConfidence?
}

struct PersonalTripImportantNotice: Codable, Equatable, Identifiable {
    let sequence: Int
    let type: String
    let content: QualifiedString

    var id: Int { sequence }
}

struct PersonalTripProjection: Codable, Equatable {
    let identity: String
    let name: String
    let firstGeneratedAt: Date
    let status: PersonalTripStatus
    let departureCity: String
    let startDate: LocalDate
    let endDate: LocalDate
    let totalDayCount: Int
    let hikingDayCount: Int
    let frozenRouteBasis: FrozenRouteBasis
    let weatherOverview: QualifiedString?
    let importantNotices: [PersonalTripImportantNotice]?

    enum CodingKeys: String, CodingKey {
        case identity, name, firstGeneratedAt, status, departureCity
        case startDate, endDate, totalDayCount, hikingDayCount
        case frozenRouteBasis, weatherOverview, importantNotices
    }
}

struct PersonalTripRouteSectionSnapshot: Codable, Equatable {
    let start: PublicRoutePlace
    let end: PublicRoutePlace
    let name: String?
    let path: [PublicRouteGeoPosition]?
}

struct PersonalTripAction: Codable, Equatable, Identifiable {
    let sequence: Int
    let actionType: String
    let origin: QualifiedPlace?
    let destination: QualifiedPlace?
    let mode: QualifiedString?
    let keyTimes: QualifiedStringList?
    let estimatedDuration: QualifiedDuration?
    let transferNotes: QualifiedStringList?
    let routeSectionSnapshot: PersonalTripRouteSectionSnapshot?
    let start: QualifiedPlace?
    let end: QualifiedPlace?
    let distance: QualifiedDistance?
    let ascent: QualifiedDistance?

    var id: Int { sequence }

    enum CodingKeys: String, CodingKey {
        case sequence, actionType, origin, destination, mode, keyTimes
        case estimatedDuration, transferNotes, routeSectionSnapshot
        case start, end, distance, ascent
    }
}

struct PersonalTripDayWeather: Codable, Equatable {
    let condition: QualifiedJSON
    let temperatureRange: QualifiedJSON
    let precipitation: QualifiedJSON
    let wind: QualifiedJSON
    let placeContext: QualifiedJSON
    let routeSectionContext: QualifiedJSON?
    let source: QualifiedString?
    let updatedAt: QualifiedString?

    enum CodingKeys: String, CodingKey {
        case condition, temperatureRange, precipitation, wind
        case placeContext, routeSectionContext, source, updatedAt
    }
}

struct PersonalTripPoint: Codable, Equatable, Identifiable {
    let sequence: Int
    let category: String
    let type: String
    let name: String?
    let distance: QualifiedDistance?
    let location: QualifiedPosition?
    let details: QualifiedString?
    let isAlternative: Bool?

    var id: Int { sequence }

    enum CodingKeys: String, CodingKey {
        case sequence, category, type, name, distance, location, details, isAlternative
    }
}

struct PersonalTripDay: Codable, Equatable, Identifiable {
    let identity: String
    let dayNumber: Int
    let date: LocalDate
    let primaryStage: String
    let hikingDayNumber: Int?
    let actions: [PersonalTripAction]
    let weather: PersonalTripDayWeather
    let points: [PersonalTripPoint]?

    var id: String { identity }

    enum CodingKeys: String, CodingKey {
        case identity, dayNumber, date, primaryStage, hikingDayNumber, actions, weather, points
    }
}

struct PersonalTripEquipmentSummary: Codable, Equatable {
    let itemCount: Int
    let knownTotalWeight: EquipmentWeight
    let missingWeightItemCount: Int
    let ownedItemCount: Int
    let unconfirmedOwnedItemCount: Int

    enum CodingKeys: String, CodingKey {
        case itemCount, knownTotalWeight, missingWeightItemCount
        case ownedItemCount, unconfirmedOwnedItemCount
    }
}

struct PersonalTripEquipmentSnapshotReference: Codable, Equatable {
    let snapshotID: String
    let summary: PersonalTripEquipmentSummary

    enum CodingKeys: String, CodingKey {
        case snapshotID = "snapshotId"
        case summary
    }
}

struct PersonalTripRouteVersionReference: Codable, Equatable {
    let routeVersionID: String
    let versionLabel: String?

    enum CodingKeys: String, CodingKey {
        case routeVersionID = "routeVersionId"
        case versionLabel
    }
}

enum PersonalTripVersionRelationship: String, Codable, Equatable {
    case current
    case newerPublicVersionAvailable = "newer_public_version_available"
    case currentPublicVersionUnavailable = "current_public_version_unavailable"
}

enum PersonalTripRouteDifferenceCategory: String, Codable, Equatable, CaseIterable {
    case identityAndStructure = "identity_and_structure"
    case trackAndSegments = "track_and_segments"
    case scaleDifficultyAndTime = "scale_difficulty_and_time"
    case planningSupportAndSafety = "planning_support_and_safety"
    case seasonalPreparationAndEquipment = "seasonal_preparation_and_equipment"

    var title: String {
        switch self {
        case .identityAndStructure: "路线身份与结构"
        case .trackAndSegments: "线路与轨迹"
        case .scaleDifficultyAndTime: "体量、难度与时间"
        case .planningSupportAndSafety: "规划、沿途保障与安全"
        case .seasonalPreparationAndEquipment: "季节准备与装备建议"
        }
    }
}

enum PersonalTripRouteDifferenceChangeType: String, Codable, Equatable {
    case added
    case noLongerProvided = "no_longer_provided"
    case modified

    var title: String {
        switch self {
        case .added: "新增"
        case .noLongerProvided: "新版不再提供"
        case .modified: "已修改"
        }
    }
}

enum PersonalTripRouteMinimumComparisonStatus: String, Codable, Equatable {
    case complete
    case partial
    case unavailable
}

enum PersonalTripOtherRelevantChangeStatus: String, Codable, Equatable {
    case none
    case changed
    case unknown
}

struct PersonalTripRouteVersionDifferenceItem: Codable, Equatable, Identifiable {
    let category: PersonalTripRouteDifferenceCategory
    let changeType: PersonalTripRouteDifferenceChangeType
    let subject: String
    let summary: String
    let before: QualifiedString?
    let after: QualifiedString?

    var id: String { "\(category.rawValue):\(changeType.rawValue):\(subject)" }

    enum CodingKeys: String, CodingKey {
        case category, changeType, subject, summary, before, after
    }
}

struct PersonalTripRouteVersionDifference: Codable, Equatable {
    let minimumComparisonStatus: PersonalTripRouteMinimumComparisonStatus
    let differences: [PersonalTripRouteVersionDifferenceItem]
    let unavailableCategories: [PersonalTripRouteDifferenceCategory]
    let otherRelevantChangeStatus: PersonalTripOtherRelevantChangeStatus
    let otherRelevantChanges: [String]

    enum CodingKeys: String, CodingKey {
        case minimumComparisonStatus, differences, unavailableCategories
        case otherRelevantChangeStatus, otherRelevantChanges
    }
}

struct PersonalTripRouteVersionStatus: Codable, Equatable {
    let tripID: String
    let tripRevision: String
    let adoptedVersion: PersonalTripRouteVersionReference
    let currentPublicVersion: PersonalTripRouteVersionReference?
    let versionRelationship: PersonalTripVersionRelationship
    let migrationEligible: Bool
    let difference: PersonalTripRouteVersionDifference?

    enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case tripRevision, adoptedVersion, currentPublicVersion
        case versionRelationship, migrationEligible, difference
    }
}

struct PersonalTripDetail: Codable, Equatable {
    let revision: String
    let trip: PersonalTripProjection
    let routeReference: PersonalTripRouteReference
    let days: [PersonalTripDay]
    let equipmentSnapshot: PersonalTripEquipmentSnapshotReference
    let routeVersionStatus: PersonalTripRouteVersionStatus

    enum CodingKeys: String, CodingKey {
        case revision, trip, routeReference, days, equipmentSnapshot, routeVersionStatus
    }
}

struct PersonalTripDays: Codable, Equatable {
    let tripID: String
    let revision: String
    let startDate: LocalDate
    let endDate: LocalDate
    let totalDayCount: Int
    let hikingDayCount: Int
    let days: [PersonalTripDay]

    enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case revision, startDate, endDate, totalDayCount, hikingDayCount, days
    }
}

struct PersonalTripWeatherDay: Codable, Equatable, Identifiable {
    let tripDayID: String
    let dayNumber: Int
    let date: LocalDate
    let primaryStage: String
    let hikingDayNumber: Int?
    let weather: PersonalTripDayWeather

    var id: String { tripDayID }

    enum CodingKeys: String, CodingKey {
        case tripDayID = "tripDayId"
        case dayNumber, date, primaryStage, hikingDayNumber, weather
    }
}

struct PersonalTripWeather: Codable, Equatable {
    let tripID: String
    let revision: String
    let routeName: String
    let startDate: LocalDate
    let endDate: LocalDate
    let days: [PersonalTripWeatherDay]
    let weatherOverview: QualifiedString?

    enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case revision, routeName, startDate, endDate, days, weatherOverview
    }
}

struct PersonalTripGenerationRoute: Codable, Equatable {
    let routeID: String
    let currentPublicRouteVersionID: String
    let routeType: String
    let generationEligibility: RouteGenerationEligibility
    let versionLabel: String?
    let name: String?
    let region: String?
    let start: PublicRoutePlace?
    let end: PublicRoutePlace?
    let difficulty: String?
    let distance: RouteDistance?
    let estimatedDuration: RouteDuration?

    enum CodingKeys: String, CodingKey {
        case routeID = "routeId"
        case currentPublicRouteVersionID = "currentPublicRouteVersionId"
        case routeType, generationEligibility, versionLabel
        case name, region, start, end, difficulty, distance, estimatedDuration
    }
}

struct PersonalTripGenerationEquipmentListOption: Codable, Equatable, Identifiable {
    let equipmentListID: String
    let name: String
    let summary: EquipmentListSummary

    var id: String { equipmentListID }

    enum CodingKeys: String, CodingKey {
        case equipmentListID = "equipmentListId"
        case name, summary
    }
}

struct PersonalTripGenerationContext: Codable, Equatable {
    let route: PersonalTripGenerationRoute
    let personalEquipmentSummary: PersonalEquipmentSummary
    let equipmentLists: [PersonalTripGenerationEquipmentListOption]

    enum CodingKeys: String, CodingKey {
        case route, personalEquipmentSummary, equipmentLists
    }
}

struct PersonalTripTransportOption: Codable, Equatable, Identifiable {
    let transportOptionID: String
    let transferCount: QualifiedInteger
    let estimatedArrivalAt: QualifiedString
    let estimatedDuration: QualifiedDuration
    let verificationItems: [String]

    var id: String { transportOptionID }

    enum CodingKeys: String, CodingKey {
        case transportOptionID = "transportOptionId"
        case transferCount, estimatedArrivalAt, estimatedDuration, verificationItems
    }
}

struct PersonalTripTransportSelection: Codable, Equatable {
    let selectionID: String
    let options: [PersonalTripTransportOption]

    enum CodingKeys: String, CodingKey {
        case selectionID = "selectionId"
        case options
    }
}

enum PersonalTripGenerationResult: Decodable, Equatable {
    case transportSelectionRequired(PersonalTripTransportSelection)
    case tripCreated(PersonalTripDetail)

    private enum CodingKeys: String, CodingKey {
        case resultType, selection, trip
    }

    private enum ResultType: String, Decodable {
        case transportSelectionRequired = "transport_selection_required"
        case tripCreated = "trip_created"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(ResultType.self, forKey: .resultType) {
        case .transportSelectionRequired:
            self = .transportSelectionRequired(
                try container.decode(PersonalTripTransportSelection.self, forKey: .selection)
            )
        case .tripCreated:
            self = .tripCreated(try container.decode(PersonalTripDetail.self, forKey: .trip))
        }
    }
}

struct PersonalTripTransportSelectionRequest: Encodable, Equatable {
    let selectionID: String
    let transportOptionID: String

    enum CodingKeys: String, CodingKey {
        case selectionID = "selectionId"
        case transportOptionID = "transportOptionId"
    }
}

struct PersonalTripCreateRequest: Encodable, Equatable {
    let routeID: String
    let routeVersionID: String
    let departureCity: String
    let startDate: LocalDate
    let equipmentListID: String?
    let transportSelection: PersonalTripTransportSelectionRequest?

    enum CodingKeys: String, CodingKey {
        case routeID = "routeId"
        case routeVersionID = "routeVersionId"
        case departureCity, startDate
        case equipmentListID = "equipmentListId"
        case transportSelection
    }
}

struct PersonalTripCancelRequest: Encodable, Equatable {
    let expectedRevision: String
    let confirmed: Bool
}

struct PersonalTripMigrateRequest: Encodable, Equatable {
    let expectedRevision: String
    let targetRouteVersionID: String

    enum CodingKeys: String, CodingKey {
        case expectedRevision
        case targetRouteVersionID = "targetRouteVersionId"
    }
}

struct ProfileUpdate: Encodable, Equatable {
    enum Field<Value: Encodable & Equatable>: Encodable, Equatable {
        case unchanged
        case value(Value)
        case clear

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .unchanged, .clear: try container.encodeNil()
            case .value(let value): try container.encode(value)
            }
        }
    }

    let nickname: Field<String>
    let avatar: Field<String>

    init(nickname: Field<String> = .unchanged, avatar: Field<String> = .unchanged) {
        self.nickname = nickname
        self.avatar = avatar
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if nickname != .unchanged { try container.encode(nickname, forKey: .nickname) }
        if avatar != .unchanged { try container.encode(avatar, forKey: .avatar) }
    }

    private enum CodingKeys: String, CodingKey { case nickname, avatar }
}
