import Foundation

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

enum InformationCategory: String, Codable {
    case publicRouteFact = "public_route_fact"
    case dynamicExternalInformation = "dynamic_external_information"
    case generatedSuggestion = "generated_suggestion"
}

struct InformationConfidence: Codable, Equatable {
    let status: String
    var category: InformationCategory? = nil
    var source: String? = nil
    var updatedAt: Instant? = nil
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

struct QualifiedInstant: Codable, Equatable {
    let value: Instant?
    let confidence: InformationConfidence?
}

struct WeatherOverview: Codable, Equatable {
    let summary: QualifiedString
    var importantImpacts: [ImportantWeatherImpact]? = nil
}

struct ImportantWeatherImpact: Codable, Equatable {
    let sequence: Int
    let content: QualifiedString
}

struct QualifiedDistance: Codable, Equatable {
    let value: RouteDistance?
    let confidence: InformationConfidence?
}

struct QualifiedElevationGain: Codable, Equatable {
    let value: RouteElevationGain?
    let confidence: InformationConfidence?
}

struct TemperatureRange: Codable, Equatable {
    let low: Double?
    let high: Double?
}

struct QualifiedTemperatureRange: Codable, Equatable {
    let value: TemperatureRange?
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
    let weatherOverview: WeatherOverview?
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
    let ascent: QualifiedElevationGain?

    var id: Int { sequence }

    enum CodingKeys: String, CodingKey {
        case sequence, actionType, origin, destination, mode, keyTimes
        case estimatedDuration, transferNotes, routeSectionSnapshot
        case start, end, distance, ascent
    }
}

struct PersonalTripDayWeather: Codable, Equatable {
    let condition: QualifiedString
    let temperatureRange: QualifiedTemperatureRange
    let precipitation: QualifiedString
    let wind: QualifiedString
    let placeContext: QualifiedString
    let routeSectionContext: QualifiedString?
    let source: QualifiedString?
    let updatedAt: QualifiedInstant?

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

struct LegacyPersonalTripWeather: Codable, Equatable {
    let tripID: String
    let revision: String
    let routeName: String
    let startDate: LocalDate
    let endDate: LocalDate
    let days: [PersonalTripWeatherDay]
    let weatherOverview: WeatherOverview?

    enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case revision, routeName, startDate, endDate, days, weatherOverview
    }
}

struct WeatherQualifiedValue<Value: Codable & Equatable>: Codable, Equatable {
    let value: Value?
    let confidence: InformationConfidence?

    init(value: Value? = nil, confidence: InformationConfidence? = nil) {
        self.value = value
        self.confidence = confidence
    }
}

struct WeatherLocation: Codable, Equatable {
    let position: PublicRouteGeoPosition
    let name: String?

    init(position: PublicRouteGeoPosition, name: String? = nil) {
        self.position = position
        self.name = name
    }
}

struct WeatherCondition: Codable, Equatable {
    let description: String

    init(description: String) {
        self.description = description
    }
}

struct PrecipitationAmount: Codable, Equatable {
    let millimeters: Double

    init(millimeters: Double) {
        self.millimeters = millimeters
    }
}

struct WindSpeed: Codable, Equatable {
    let metersPerSecond: Double

    init(metersPerSecond: Double) {
        self.metersPerSecond = metersPerSecond
    }
}

struct WeatherPrecipitation: Codable, Equatable {
    let description: String?
    let probability: Double?
    let amount: PrecipitationAmount?

    init(
        description: String? = nil,
        probability: Double? = nil,
        amount: PrecipitationAmount? = nil
    ) {
        self.description = description
        self.probability = probability
        self.amount = amount
    }
}

struct WeatherWind: Codable, Equatable {
    let description: String?
    let averageSpeed: WindSpeed?
    let gustSpeed: WindSpeed?
    let direction: String?

    init(
        description: String? = nil,
        averageSpeed: WindSpeed? = nil,
        gustSpeed: WindSpeed? = nil,
        direction: String? = nil
    ) {
        self.description = description
        self.averageSpeed = averageSpeed
        self.gustSpeed = gustSpeed
        self.direction = direction
    }
}

struct WeatherForecastPeriod: Codable, Equatable {
    let periodStart: Instant
    let periodEnd: Instant
    let condition: WeatherQualifiedValue<WeatherCondition>?
    let temperatureRange: WeatherQualifiedValue<TemperatureRange>?
    let precipitation: WeatherQualifiedValue<WeatherPrecipitation>?
    let wind: WeatherQualifiedValue<WeatherWind>?

    init(
        periodStart: Instant,
        periodEnd: Instant,
        condition: WeatherQualifiedValue<WeatherCondition>? = nil,
        temperatureRange: WeatherQualifiedValue<TemperatureRange>? = nil,
        precipitation: WeatherQualifiedValue<WeatherPrecipitation>? = nil,
        wind: WeatherQualifiedValue<WeatherWind>? = nil
    ) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.condition = condition
        self.temperatureRange = temperatureRange
        self.precipitation = precipitation
        self.wind = wind
    }
}

struct WeatherForecast: Codable, Equatable {
    let identity: String
    let location: WeatherLocation
    let source: String?
    let publishedAt: Instant?
    let periods: [WeatherForecastPeriod]

    init(
        identity: String,
        location: WeatherLocation,
        source: String? = nil,
        publishedAt: Instant? = nil,
        periods: [WeatherForecastPeriod]
    ) {
        self.identity = identity
        self.location = location
        self.source = source
        self.publishedAt = publishedAt
        self.periods = periods
    }
}

enum TripWeatherAssociationScope: String, Codable, Equatable {
    case day
    case hikeAction = "hike_action"
}

struct TripWeatherAssociation: Codable, Equatable, Identifiable {
    let associationIdentity: String
    let sequence: Int
    let scope: TripWeatherAssociationScope
    let hikeActionIdentity: String?
    let targetLocation: WeatherLocation
    let targetPeriodStart: Instant
    let targetPeriodEnd: Instant
    let forecastConfidence: InformationConfidence?
    let forecast: WeatherForecast?

    var id: String { associationIdentity }

    init(
        associationIdentity: String,
        sequence: Int,
        scope: TripWeatherAssociationScope,
        hikeActionIdentity: String? = nil,
        targetLocation: WeatherLocation,
        targetPeriodStart: Instant,
        targetPeriodEnd: Instant,
        forecastConfidence: InformationConfidence? = nil,
        forecast: WeatherForecast? = nil
    ) {
        self.associationIdentity = associationIdentity
        self.sequence = sequence
        self.scope = scope
        self.hikeActionIdentity = hikeActionIdentity
        self.targetLocation = targetLocation
        self.targetPeriodStart = targetPeriodStart
        self.targetPeriodEnd = targetPeriodEnd
        self.forecastConfidence = forecastConfidence
        self.forecast = forecast
    }
}

struct PersonalTripWeatherAssociationDay: Codable, Equatable, Identifiable {
    let tripDayID: String
    let dayNumber: Int
    let date: LocalDate
    let weatherAssociations: [TripWeatherAssociation]

    var id: String { tripDayID }

    init(
        tripDayID: String,
        dayNumber: Int,
        date: LocalDate,
        weatherAssociations: [TripWeatherAssociation]
    ) {
        self.tripDayID = tripDayID
        self.dayNumber = dayNumber
        self.date = date
        self.weatherAssociations = weatherAssociations
    }

    enum CodingKeys: String, CodingKey {
        case tripDayID = "tripDayId"
        case dayNumber, date, weatherAssociations
    }
}

struct PersonalTripWeather: Codable, Equatable {
    let tripID: String
    let revision: String
    let days: [PersonalTripWeatherAssociationDay]

    init(tripID: String, revision: String, days: [PersonalTripWeatherAssociationDay]) {
        self.tripID = tripID
        self.revision = revision
        self.days = days
    }

    enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case revision, days
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
    let estimatedArrivalAt: QualifiedInstant
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
