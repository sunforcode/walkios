import Foundation

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
    let description: String?
    let position: PublicRouteGeoPosition?

    var id: String { identity }

    init(
        identity: String,
        mediaReference: String,
        role: PublicRouteImageRole,
        caption: String? = nil,
        description: String? = nil,
        position: PublicRouteGeoPosition? = nil
    ) {
        self.identity = identity
        self.mediaReference = mediaReference
        self.role = role
        self.caption = caption
        self.description = description
        self.position = position
    }

    enum CodingKeys: String, CodingKey {
        case identity, mediaReference, role, caption, description, position
    }
}
