import Foundation

public struct RouteDistance: Codable, Equatable { public let meters: Double 
    public init(
        meters: Double
    ) {
        self.meters = meters
    }
}
public struct RouteElevation: Codable, Equatable { public let meters: Double 
    public init(
        meters: Double
    ) {
        self.meters = meters
    }
}
public struct RouteElevationGain: Codable, Equatable { public let meters: Double 
    public init(
        meters: Double
    ) {
        self.meters = meters
    }
}
public struct RouteElevationLoss: Codable, Equatable { public let meters: Double 
    public init(
        meters: Double
    ) {
        self.meters = meters
    }
}
public struct RouteDuration: Codable, Equatable { public let seconds: Double 
    public init(
        seconds: Double
    ) {
        self.seconds = seconds
    }
}

public struct PublicRouteDiscoveryResult: Codable, Equatable {
     public let items: [PublicRouteBrowseSummary]

    public init(
        items: [PublicRouteBrowseSummary]
    ) {
        self.items = items
    }
}

public struct PublicRouteCollectionResult: Codable, Equatable {
     public let items: [PublicRouteBrowseSummary]

    public init(
        items: [PublicRouteBrowseSummary]
    ) {
        self.items = items
    }
}

public enum PublicRouteSearchState: String, Codable, Equatable {
    case initial
    case completed
}

public struct PublicRouteSearchResult: Codable, Equatable {
     public let state: PublicRouteSearchState
     public let items: [PublicRouteSearchSummary]

    public init(
        state: PublicRouteSearchState,
        items: [PublicRouteSearchSummary]
    ) {
        self.state = state
        self.items = items
    }
}

public struct PublicRouteBrowseSummary: Codable, Equatable, Identifiable {
     public let routeId: String
     public let currentVersionId: String
     public let cover: String?
     public let name: String?
     public let region: String?
     public let difficulty: String?
     public let distance: RouteDistance?
     public let ascent: RouteElevationGain?
     public let estimatedDuration: RouteDuration?

     public var id: String { routeId }

    public enum CodingKeys: String, CodingKey {
        case routeId, currentVersionId
        case cover, name, region, difficulty, distance, ascent, estimatedDuration
    }

    public init(
        routeId: String,
        currentVersionId: String,
        cover: String?,
        name: String?,
        region: String?,
        difficulty: String?,
        distance: RouteDistance?,
        ascent: RouteElevationGain?,
        estimatedDuration: RouteDuration?
    ) {
        self.routeId = routeId
        self.currentVersionId = currentVersionId
        self.cover = cover
        self.name = name
        self.region = region
        self.difficulty = difficulty
        self.distance = distance
        self.ascent = ascent
        self.estimatedDuration = estimatedDuration
    }
}

public struct PublicRouteSearchSummary: Codable, Equatable, Identifiable {
     public let routeId: String
     public let currentVersionId: String
     public let cover: String?
     public let name: String?
     public let region: String?
     public let difficulty: String?
     public let distance: RouteDistance?
     public let estimatedDuration: RouteDuration?

     public var id: String { routeId }

    public enum CodingKeys: String, CodingKey {
        case routeId, currentVersionId
        case cover, name, region, difficulty, distance, estimatedDuration
    }

    public init(
        routeId: String,
        currentVersionId: String,
        cover: String?,
        name: String?,
        region: String?,
        difficulty: String?,
        distance: RouteDistance?,
        estimatedDuration: RouteDuration?
    ) {
        self.routeId = routeId
        self.currentVersionId = currentVersionId
        self.cover = cover
        self.name = name
        self.region = region
        self.difficulty = difficulty
        self.distance = distance
        self.estimatedDuration = estimatedDuration
    }
}

public struct PublicRouteDetail: Codable, Equatable {
     public let routeId: String
     public let currentVersion: PublicRouteVersionDetail

    public init(
        routeId: String,
        currentVersion: PublicRouteVersionDetail
    ) {
        self.routeId = routeId
        self.currentVersion = currentVersion
    }
}

public enum PublicRouteType: String, Codable, Equatable {
    case oneDay = "one_day"
    case multiDay = "multi_day"
}

public enum MainTrackAvailability: String, Codable, Equatable {
    case missing
    case processing
    case pendingReview = "pending_review"
    case valid
    case invalidated
}

public enum RouteGenerationMissingReason: String, Codable, Equatable {
    case name
    case region
    case estimatedDuration
    case start
    case end
    case validMainTrack
}

public enum PublicRouteImageRole: String, Codable, Equatable {
    case cover
    case environment
}

public struct PublicRouteVersionDetail: Codable, Equatable {
     public let versionId: String
     public let summary: PublicRouteSummary
     public let mainTrackAvailability: MainTrackAvailability
     public let generationEligibility: RouteGenerationEligibility
     public let versionLabel: String?
     public let mainTrack: PublicRouteMainTrack?
     public let elevationProfile: PublicRouteElevationProfile?
     public let professionalAnalysis: PublicRouteProfessionalAnalysis?
     public let referenceDays: [PublicRouteReferenceDay]?
     public let segments: [PublicRouteSegment]?
     public let keyPoints: [PublicRouteNamedPoint]?
     public let interestPoints: [PublicRouteNamedPoint]?
     public let campsites: [PublicRouteCampsite]?
     public let overnightPlaces: [PublicRouteOvernightPlace]?
     public let waterSources: [PublicRouteWaterSource]?
     public let supplyPoints: [PublicRouteSupplyPoint]?
     public let communicationAndSafety: PublicRouteCommunicationAndSafety?
     public let seasonalWeather: PublicRouteSeasonalWeather?
     public let seasonalEquipmentRecommendations: [PublicRouteSeasonalEquipmentRecommendation]?
     public let images: [PublicRouteImage]?

     public init(
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

    public enum CodingKeys: String, CodingKey {
        case versionId, summary, mainTrackAvailability, generationEligibility, versionLabel
        case mainTrack, elevationProfile, professionalAnalysis, referenceDays, segments
        case keyPoints, interestPoints, campsites, overnightPlaces, waterSources
        case supplyPoints, communicationAndSafety, seasonalWeather
        case seasonalEquipmentRecommendations, images
    }
}

public struct PublicRouteSummary: Codable, Equatable {
     public let routeType: PublicRouteType
     public let name: String?
     public let region: String?
     public let start: PublicRoutePlace?
     public let end: PublicRoutePlace?
     public let estimatedDuration: RouteDuration?
     public let difficulty: String?
     public let direction: String?
     public let distance: RouteDistance?
     public let ascent: RouteElevationGain?
     public let descent: RouteElevationLoss?
     public let maxElevation: RouteElevation?
     public let suggestedDays: Int?
     public let tags: [String]?
     public let introduction: String?

     public init(
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

    public enum CodingKeys: String, CodingKey {
        case routeType, name, region, start, end, estimatedDuration
        case difficulty, direction, distance, ascent, descent, maxElevation, suggestedDays, tags, introduction
    }
}

public struct PublicRoutePlace: Codable, Equatable {
     public let name: String
     public let position: PublicRouteGeoPosition?

     public init(name: String, position: PublicRouteGeoPosition? = nil) {
        self.name = name
        self.position = position
    }
}

public struct PublicRouteGeoPosition: Codable, Equatable {
     public let latitude: Double
     public let longitude: Double
     public let referenceSystem: String

    public init(
        latitude: Double,
        longitude: Double,
        referenceSystem: String
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.referenceSystem = referenceSystem
    }
}

public struct PublicRouteMainTrack: Codable, Equatable {
     public let identity: String
     public let path: [PublicRouteGeoPosition]

    public init(
        identity: String,
        path: [PublicRouteGeoPosition]
    ) {
        self.identity = identity
        self.path = path
    }
}

public struct PublicRoutePathPosition: Codable, Equatable {
     public let precedingPositionIndex: Int
     public let progressToNextPosition: Double?

    public init(
        precedingPositionIndex: Int,
        progressToNextPosition: Double?
    ) {
        self.precedingPositionIndex = precedingPositionIndex
        self.progressToNextPosition = progressToNextPosition
    }
}

public struct PublicRouteMainTrackRange: Codable, Equatable {
     public let startPathPosition: PublicRoutePathPosition
     public let endPathPosition: PublicRoutePathPosition

    public init(
        startPathPosition: PublicRoutePathPosition,
        endPathPosition: PublicRoutePathPosition
    ) {
        self.startPathPosition = startPathPosition
        self.endPathPosition = endPathPosition
    }
}

public struct PublicRouteElevationSample: Codable, Equatable, Identifiable {
     public let identity: String
     public let distance: RouteDistance
     public let elevation: RouteElevation
     public var id: String { identity }

    public init(
        identity: String,
        distance: RouteDistance,
        elevation: RouteElevation
    ) {
        self.identity = identity
        self.distance = distance
        self.elevation = elevation
    }
}

public struct PublicRouteElevationProfile: Codable, Equatable {
     public let minElevation: RouteElevation
     public let maxElevation: RouteElevation
     public let samples: [PublicRouteElevationSample]

    public init(
        minElevation: RouteElevation,
        maxElevation: RouteElevation,
        samples: [PublicRouteElevationSample]
    ) {
        self.minElevation = minElevation
        self.maxElevation = maxElevation
        self.samples = samples
    }
}

public struct PublicRouteProfessionalAnalysis: Codable, Equatable {
     public let fitnessRequirement: QualifiedString?
     public let experienceRequirement: QualifiedString?
     public let mainTerrain: QualifiedString?
     public let technicalDifficulty: QualifiedString?
     public let highAltitudeImpact: QualifiedString?
     public let exposedSections: QualifiedString?
     public let dangerAreas: QualifiedString?
     public let signalCoverage: QualifiedString?
     public let evacuationDifficulty: QualifiedString?

    public init(
        fitnessRequirement: QualifiedString?,
        experienceRequirement: QualifiedString?,
        mainTerrain: QualifiedString?,
        technicalDifficulty: QualifiedString?,
        highAltitudeImpact: QualifiedString?,
        exposedSections: QualifiedString?,
        dangerAreas: QualifiedString?,
        signalCoverage: QualifiedString?,
        evacuationDifficulty: QualifiedString?
    ) {
        self.fitnessRequirement = fitnessRequirement
        self.experienceRequirement = experienceRequirement
        self.mainTerrain = mainTerrain
        self.technicalDifficulty = technicalDifficulty
        self.highAltitudeImpact = highAltitudeImpact
        self.exposedSections = exposedSections
        self.dangerAreas = dangerAreas
        self.signalCoverage = signalCoverage
        self.evacuationDifficulty = evacuationDifficulty
    }
}

public struct PublicRouteReferenceDay: Codable, Equatable, Identifiable {
     public let identity: String
     public let dayNumber: Int
     public let title: String?
     public let start: PublicRoutePlace?
     public let end: PublicRoutePlace?
     public let distance: RouteDistance?
     public let estimatedDuration: RouteDuration?
     public let ascent: RouteElevationGain?
     public let descent: RouteElevationLoss?
     public let maxElevation: RouteElevation?
     public let minElevation: RouteElevation?
    public let accommodation: String?
    public let notes: String?
    public let mainTrackRange: PublicRouteMainTrackRange?
    public var id: String { identity }

    public init(
        identity: String,
        dayNumber: Int,
        title: String?,
        start: PublicRoutePlace?,
        end: PublicRoutePlace?,
        distance: RouteDistance?,
        estimatedDuration: RouteDuration?,
        ascent: RouteElevationGain?,
        descent: RouteElevationLoss?,
        maxElevation: RouteElevation?,
        minElevation: RouteElevation?,
        accommodation: String?,
        notes: String?,
        mainTrackRange: PublicRouteMainTrackRange? = nil
    ) {
        self.identity = identity
        self.dayNumber = dayNumber
        self.title = title
        self.start = start
        self.end = end
        self.distance = distance
        self.estimatedDuration = estimatedDuration
        self.ascent = ascent
        self.descent = descent
        self.maxElevation = maxElevation
        self.minElevation = minElevation
        self.accommodation = accommodation
        self.notes = notes
        self.mainTrackRange = mainTrackRange
    }
}

public struct RouteGenerationEligibility: Codable, Equatable {
     public let eligible: Bool
     public let missingReasons: [RouteGenerationMissingReason]?

     public init(eligible: Bool, missingReasons: [RouteGenerationMissingReason]? = nil) {
        self.eligible = eligible
        self.missingReasons = missingReasons
    }

    public enum CodingKeys: String, CodingKey {
        case eligible, missingReasons
    }
}

public struct PublicRouteSegment: Codable, Equatable, Identifiable {
     public let identity: String
     public let order: Int
     public let name: String
     public let start: PublicRoutePlace?
     public let end: PublicRoutePlace?
     public let distance: RouteDistance?
     public let estimatedDuration: RouteDuration?
     public let ascent: RouteElevationGain?
     public let descent: RouteElevationLoss?
     public let difficulty: String?
     public let terrainOrRoadType: String?
     public let description: String?
     public let notes: String?
     public let mainTrackRange: PublicRouteMainTrackRange?

     public var id: String { identity }

     public init(
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

    public enum CodingKeys: String, CodingKey {
        case identity, order, name, start, end, distance, estimatedDuration
        case ascent, descent, difficulty, terrainOrRoadType, description, notes, mainTrackRange
    }
}

public struct PublicRouteNamedPoint: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let positions: [PublicRouteGeoPosition]
     public let category: String?
     public let description: String?
     public let elevation: RouteElevation?
     public let media: [String]?

     public var id: String { identity }

     public init(
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

public struct PublicRouteCampsite: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let positions: [PublicRouteGeoPosition]
     public let elevation: RouteElevation?
     public let details: String?
     public let status: String?

     public var id: String { identity }

    public init(
        identity: String,
        name: String,
        positions: [PublicRouteGeoPosition],
        elevation: RouteElevation?,
        details: String?,
        status: String?
    ) {
        self.identity = identity
        self.name = name
        self.positions = positions
        self.elevation = elevation
        self.details = details
        self.status = status
    }
}

public struct PublicRouteOvernightPlace: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let positions: [PublicRouteGeoPosition]
     public let elevation: RouteElevation?
     public let type: String?
     public let facilities: [String]?
     public let details: String?
     public let status: String?

     public var id: String { identity }

    public init(
        identity: String,
        name: String,
        positions: [PublicRouteGeoPosition],
        elevation: RouteElevation?,
        type: String?,
        facilities: [String]?,
        details: String?,
        status: String?
    ) {
        self.identity = identity
        self.name = name
        self.positions = positions
        self.elevation = elevation
        self.type = type
        self.facilities = facilities
        self.details = details
        self.status = status
    }
}

public struct PublicRouteWaterSource: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let positions: [PublicRouteGeoPosition]
     public let elevation: RouteElevation?
     public let sourceType: String?
     public let seasonalReliability: String?
     public let treatmentRecommended: Bool?
     public let treatmentAdvice: String?
     public let description: String?

     public var id: String { identity }

    public enum CodingKeys: String, CodingKey {
        case identity, name, positions, elevation, sourceType, seasonalReliability
        case treatmentRecommended, treatmentAdvice, description
    }

    public init(
        identity: String,
        name: String,
        positions: [PublicRouteGeoPosition],
        elevation: RouteElevation?,
        sourceType: String?,
        seasonalReliability: String?,
        treatmentRecommended: Bool?,
        treatmentAdvice: String?,
        description: String?
    ) {
        self.identity = identity
        self.name = name
        self.positions = positions
        self.elevation = elevation
        self.sourceType = sourceType
        self.seasonalReliability = seasonalReliability
        self.treatmentRecommended = treatmentRecommended
        self.treatmentAdvice = treatmentAdvice
        self.description = description
    }
}

public struct PublicRouteSupplyPoint: Codable, Equatable, Identifiable {
     public let identity: String
     public let name: String
     public let positions: [PublicRouteGeoPosition]
     public let supplyType: String?
     public let availableItems: [String]?
     public let description: String?

     public var id: String { identity }

    public enum CodingKeys: String, CodingKey {
        case identity, name, positions, supplyType, availableItems, description
    }

    public init(
        identity: String,
        name: String,
        positions: [PublicRouteGeoPosition],
        supplyType: String?,
        availableItems: [String]?,
        description: String?
    ) {
        self.identity = identity
        self.name = name
        self.positions = positions
        self.supplyType = supplyType
        self.availableItems = availableItems
        self.description = description
    }
}

public struct PublicRouteCommunicationAndSafety: Codable, Equatable {
     public let coverageSummary: String?
     public let notices: [PublicRouteSafetyNotice]?

     public init(coverageSummary: String? = nil, notices: [PublicRouteSafetyNotice]? = nil) {
        self.coverageSummary = coverageSummary
        self.notices = notices
    }
}

public struct PublicRouteSafetyNotice: Codable, Equatable, Identifiable {
     public let identity: String
     public let kind: String
     public let title: String
     public let description: String
     public let positions: [PublicRouteGeoPosition]?

     public var id: String { identity }

    public init(
        identity: String,
        kind: String,
        title: String,
        description: String,
        positions: [PublicRouteGeoPosition]?
    ) {
        self.identity = identity
        self.kind = kind
        self.title = title
        self.description = description
        self.positions = positions
    }
}

public struct PublicRouteSeasonalWeather: Codable, Equatable {
     public let bestSeasons: [String]?
     public let conditions: [PublicRouteSeasonalWeatherCondition]?

    public init(
        bestSeasons: [String]?,
        conditions: [PublicRouteSeasonalWeatherCondition]?
    ) {
        self.bestSeasons = bestSeasons
        self.conditions = conditions
    }
}

public struct PublicRouteSeasonalWeatherCondition: Codable, Equatable, Identifiable {
     public let identity: String
     public let season: String
     public let typicalWeather: String?
     public let environmentalRisks: [String]?
     public let notes: String?
     public var id: String { identity }

    public init(
        identity: String,
        season: String,
        typicalWeather: String?,
        environmentalRisks: [String]?,
        notes: String?
    ) {
        self.identity = identity
        self.season = season
        self.typicalWeather = typicalWeather
        self.environmentalRisks = environmentalRisks
        self.notes = notes
    }
}

public enum PublicRouteEquipmentRecommendationLevel: String, Codable, Equatable {
    case required
    case recommended
}

public struct PublicRouteSeasonalEquipmentRecommendation: Codable, Equatable, Identifiable {
     public let identity: String
     public let seasonOrCondition: String
     public let name: String
     public let level: PublicRouteEquipmentRecommendationLevel
     public let reason: String?
     public var id: String { identity }

    public init(
        identity: String,
        seasonOrCondition: String,
        name: String,
        level: PublicRouteEquipmentRecommendationLevel,
        reason: String?
    ) {
        self.identity = identity
        self.seasonOrCondition = seasonOrCondition
        self.name = name
        self.level = level
        self.reason = reason
    }
}

public struct PublicRouteImage: Codable, Equatable, Identifiable {
     public let identity: String
     public let mediaReference: String
     public let role: PublicRouteImageRole
     public let caption: String?
     public let description: String?
     public let position: PublicRouteGeoPosition?

     public var id: String { identity }

     public init(
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

    public enum CodingKeys: String, CodingKey {
        case identity, mediaReference, role, caption, description, position
    }
}
