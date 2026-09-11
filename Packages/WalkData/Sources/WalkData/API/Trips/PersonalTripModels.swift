import Foundation

public struct FrozenRouteBasis: Codable, Equatable {
     public let routeName: String
     public let routeType: String
     public let region: String
     public let start: PublicRoutePlace
     public let end: PublicRoutePlace
     public let estimatedDuration: RouteDuration
     public let mainTrackPath: [PublicRouteGeoPosition]
     public let versionLabel: String?
     public let cover: String?
     public let direction: String?
     public let distance: RouteDistance?
     public let ascent: RouteElevationGain?
     public let descent: RouteElevationLoss?
     public let maxElevation: RouteElevation?

    public enum CodingKeys: String, CodingKey {
        case routeName, routeType, region, start, end, estimatedDuration
        case mainTrackPath, versionLabel, cover, direction, distance, ascent, descent, maxElevation
    }

    public init(
        routeName: String,
        routeType: String,
        region: String,
        start: PublicRoutePlace,
        end: PublicRoutePlace,
        estimatedDuration: RouteDuration,
        mainTrackPath: [PublicRouteGeoPosition],
        versionLabel: String?,
        cover: String?,
        direction: String?,
        distance: RouteDistance?,
        ascent: RouteElevationGain?,
        descent: RouteElevationLoss?,
        maxElevation: RouteElevation?
    ) {
        self.routeName = routeName
        self.routeType = routeType
        self.region = region
        self.start = start
        self.end = end
        self.estimatedDuration = estimatedDuration
        self.mainTrackPath = mainTrackPath
        self.versionLabel = versionLabel
        self.cover = cover
        self.direction = direction
        self.distance = distance
        self.ascent = ascent
        self.descent = descent
        self.maxElevation = maxElevation
    }
}

public struct PersonalTripRouteReference: Codable, Equatable {
     public let routeID: String
     public let adoptedRouteVersionID: String

    public enum CodingKeys: String, CodingKey {
        case routeID = "routeId"
        case adoptedRouteVersionID = "adoptedRouteVersionId"
    }

    public init(
        routeID: String,
        adoptedRouteVersionID: String
    ) {
        self.routeID = routeID
        self.adoptedRouteVersionID = adoptedRouteVersionID
    }
}

public enum PersonalTripStatus: String, Codable, Equatable {
    case planned
    case inProgress = "in_progress"
    case completed
    case cancelled

     public var title: String {
        switch self {
        case .planned: "规划中"
        case .inProgress: "进行中"
        case .completed: "已完成"
        case .cancelled: "已取消"
        }
    }
}

public struct PersonalTripSummary: Codable, Equatable, Identifiable {
     public let tripID: String
     public let revision: String
     public let name: String
     public let status: PersonalTripStatus
     public let routeReference: PersonalTripRouteReference
     public let routeName: String
     public let routeType: String
     public let start: PublicRoutePlace
     public let end: PublicRoutePlace
     public let estimatedDuration: RouteDuration
     public let startDate: LocalDate
     public let endDate: LocalDate
     public let totalDayCount: Int
     public let hikingDayCount: Int
     public let versionLabel: String?
     public let cover: String?
     public let direction: String?
     public let distance: RouteDistance?
     public let ascent: RouteElevationGain?

     public var id: String { tripID }

     public var dateRangeDescription: String {
        startDate == endDate ? startDate.description : "\(startDate) - \(endDate)"
    }

    public enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case revision, name, status, routeReference, routeName, routeType
        case start, end, estimatedDuration, startDate, endDate
        case totalDayCount, hikingDayCount, versionLabel, cover, direction, distance, ascent
    }

    public init(
        tripID: String,
        revision: String,
        name: String,
        status: PersonalTripStatus,
        routeReference: PersonalTripRouteReference,
        routeName: String,
        routeType: String,
        start: PublicRoutePlace,
        end: PublicRoutePlace,
        estimatedDuration: RouteDuration,
        startDate: LocalDate,
        endDate: LocalDate,
        totalDayCount: Int,
        hikingDayCount: Int,
        versionLabel: String?,
        cover: String?,
        direction: String?,
        distance: RouteDistance?,
        ascent: RouteElevationGain?
    ) {
        self.tripID = tripID
        self.revision = revision
        self.name = name
        self.status = status
        self.routeReference = routeReference
        self.routeName = routeName
        self.routeType = routeType
        self.start = start
        self.end = end
        self.estimatedDuration = estimatedDuration
        self.startDate = startDate
        self.endDate = endDate
        self.totalDayCount = totalDayCount
        self.hikingDayCount = hikingDayCount
        self.versionLabel = versionLabel
        self.cover = cover
        self.direction = direction
        self.distance = distance
        self.ascent = ascent
    }
}

public struct PersonalTripFocus: Codable, Equatable {
     public let trip: PersonalTripSummary?

    public init(
        trip: PersonalTripSummary?
    ) {
        self.trip = trip
    }
}

public struct PersonalTripCollection: Codable, Equatable {
     public let currentTrips: [PersonalTripSummary]
     public let historicalTrips: [PersonalTripSummary]

    public init(
        currentTrips: [PersonalTripSummary],
        historicalTrips: [PersonalTripSummary]
    ) {
        self.currentTrips = currentTrips
        self.historicalTrips = historicalTrips
    }
}

public struct PersonalTripCalendarDay: Codable, Equatable, Identifiable {
     public let date: LocalDate
     public let tripCount: Int

     public var id: LocalDate { date }

    public init(
        date: LocalDate,
        tripCount: Int
    ) {
        self.date = date
        self.tripCount = tripCount
    }
}

public struct PersonalTripCalendar: Codable, Equatable {
     public let windowStartDate: LocalDate
     public let windowEndDate: LocalDate
     public let days: [PersonalTripCalendarDay]

    public init(
        windowStartDate: LocalDate,
        windowEndDate: LocalDate,
        days: [PersonalTripCalendarDay]
    ) {
        self.windowStartDate = windowStartDate
        self.windowEndDate = windowEndDate
        self.days = days
    }
}

public enum InformationCategory: String, Codable {
    case publicRouteFact = "public_route_fact"
    case dynamicExternalInformation = "dynamic_external_information"
    case generatedSuggestion = "generated_suggestion"
}

public struct InformationConfidence: Codable, Equatable {
     public let status: String
     public var category: InformationCategory? = nil
     public var source: String? = nil
     public var updatedAt: Instant? = nil

    public init(
        status: String,
        category: InformationCategory? = nil,
        source: String? = nil,
        updatedAt: Instant? = nil
    ) {
        self.status = status
        self.category = category
        self.source = source
        self.updatedAt = updatedAt
    }
}

public struct QualifiedString: Codable, Equatable {
     public let value: String?
     public let confidence: InformationConfidence?

    public init(
        value: String?,
        confidence: InformationConfidence?
    ) {
        self.value = value
        self.confidence = confidence
    }
}

public struct QualifiedStringList: Codable, Equatable {
     public let value: [String]?
     public let confidence: InformationConfidence?

    public init(
        value: [String]?,
        confidence: InformationConfidence?
    ) {
        self.value = value
        self.confidence = confidence
    }
}

public struct QualifiedInteger: Codable, Equatable {
     public let value: Int?
     public let confidence: InformationConfidence?

    public init(
        value: Int?,
        confidence: InformationConfidence?
    ) {
        self.value = value
        self.confidence = confidence
    }
}

public struct QualifiedDuration: Codable, Equatable {
     public let value: RouteDuration?
     public let confidence: InformationConfidence?

    public init(
        value: RouteDuration?,
        confidence: InformationConfidence?
    ) {
        self.value = value
        self.confidence = confidence
    }
}

public struct QualifiedInstant: Codable, Equatable {
     public let value: Instant?
     public let confidence: InformationConfidence?

    public init(
        value: Instant?,
        confidence: InformationConfidence?
    ) {
        self.value = value
        self.confidence = confidence
    }
}

public struct WeatherOverview: Codable, Equatable {
     public let summary: QualifiedString
     public var importantImpacts: [ImportantWeatherImpact]? = nil

    public init(
        summary: QualifiedString,
        importantImpacts: [ImportantWeatherImpact]? = nil
    ) {
        self.summary = summary
        self.importantImpacts = importantImpacts
    }
}

public struct ImportantWeatherImpact: Codable, Equatable {
     public let sequence: Int
     public let content: QualifiedString

    public init(
        sequence: Int,
        content: QualifiedString
    ) {
        self.sequence = sequence
        self.content = content
    }
}

public struct QualifiedDistance: Codable, Equatable {
     public let value: RouteDistance?
     public let confidence: InformationConfidence?

    public init(
        value: RouteDistance?,
        confidence: InformationConfidence?
    ) {
        self.value = value
        self.confidence = confidence
    }
}

public struct QualifiedElevationGain: Codable, Equatable {
     public let value: RouteElevationGain?
     public let confidence: InformationConfidence?

    public init(
        value: RouteElevationGain?,
        confidence: InformationConfidence?
    ) {
        self.value = value
        self.confidence = confidence
    }
}

public struct TemperatureRange: Codable, Equatable {
     public let low: Double?
     public let high: Double?

    public init(
        low: Double?,
        high: Double?
    ) {
        self.low = low
        self.high = high
    }
}

public struct QualifiedTemperatureRange: Codable, Equatable {
     public let value: TemperatureRange?
     public let confidence: InformationConfidence?

    public init(
        value: TemperatureRange?,
        confidence: InformationConfidence?
    ) {
        self.value = value
        self.confidence = confidence
    }
}

public struct QualifiedPlace: Codable, Equatable {
     public let value: PublicRoutePlace?
     public let confidence: InformationConfidence?

    public init(
        value: PublicRoutePlace?,
        confidence: InformationConfidence?
    ) {
        self.value = value
        self.confidence = confidence
    }
}

public struct QualifiedPosition: Codable, Equatable {
     public let value: PublicRouteGeoPosition?
     public let confidence: InformationConfidence?

    public init(
        value: PublicRouteGeoPosition?,
        confidence: InformationConfidence?
    ) {
        self.value = value
        self.confidence = confidence
    }
}

public struct PersonalTripImportantNotice: Codable, Equatable, Identifiable {
     public let sequence: Int
     public let type: String
     public let content: QualifiedString

     public var id: Int { sequence }

    public init(
        sequence: Int,
        type: String,
        content: QualifiedString
    ) {
        self.sequence = sequence
        self.type = type
        self.content = content
    }
}

public struct PersonalTripProjection: Codable, Equatable {
     public let identity: String
     public let name: String
     public let firstGeneratedAt: Date
     public let status: PersonalTripStatus
     public let departureCity: String
     public let startDate: LocalDate
     public let endDate: LocalDate
     public let totalDayCount: Int
     public let hikingDayCount: Int
     public let frozenRouteBasis: FrozenRouteBasis
     public let weatherOverview: WeatherOverview?
     public let importantNotices: [PersonalTripImportantNotice]?

    public enum CodingKeys: String, CodingKey {
        case identity, name, firstGeneratedAt, status, departureCity
        case startDate, endDate, totalDayCount, hikingDayCount
        case frozenRouteBasis, weatherOverview, importantNotices
    }

    public init(
        identity: String,
        name: String,
        firstGeneratedAt: Date,
        status: PersonalTripStatus,
        departureCity: String,
        startDate: LocalDate,
        endDate: LocalDate,
        totalDayCount: Int,
        hikingDayCount: Int,
        frozenRouteBasis: FrozenRouteBasis,
        weatherOverview: WeatherOverview?,
        importantNotices: [PersonalTripImportantNotice]?
    ) {
        self.identity = identity
        self.name = name
        self.firstGeneratedAt = firstGeneratedAt
        self.status = status
        self.departureCity = departureCity
        self.startDate = startDate
        self.endDate = endDate
        self.totalDayCount = totalDayCount
        self.hikingDayCount = hikingDayCount
        self.frozenRouteBasis = frozenRouteBasis
        self.weatherOverview = weatherOverview
        self.importantNotices = importantNotices
    }
}

public struct PersonalTripRouteSectionSnapshot: Codable, Equatable {
     public let start: PublicRoutePlace
     public let end: PublicRoutePlace
     public let name: String?
     public let path: [PublicRouteGeoPosition]?

    public init(
        start: PublicRoutePlace,
        end: PublicRoutePlace,
        name: String?,
        path: [PublicRouteGeoPosition]?
    ) {
        self.start = start
        self.end = end
        self.name = name
        self.path = path
    }
}

public struct PersonalTripAction: Codable, Equatable, Identifiable {
     public let sequence: Int
     public let actionType: String
     public let origin: QualifiedPlace?
     public let destination: QualifiedPlace?
     public let mode: QualifiedString?
     public let keyTimes: QualifiedStringList?
     public let estimatedDuration: QualifiedDuration?
     public let transferNotes: QualifiedStringList?
     public let routeSectionSnapshot: PersonalTripRouteSectionSnapshot?
     public let start: QualifiedPlace?
     public let end: QualifiedPlace?
     public let distance: QualifiedDistance?
     public let ascent: QualifiedElevationGain?

     public var id: Int { sequence }

    public enum CodingKeys: String, CodingKey {
        case sequence, actionType, origin, destination, mode, keyTimes
        case estimatedDuration, transferNotes, routeSectionSnapshot
        case start, end, distance, ascent
    }

    public init(
        sequence: Int,
        actionType: String,
        origin: QualifiedPlace?,
        destination: QualifiedPlace?,
        mode: QualifiedString?,
        keyTimes: QualifiedStringList?,
        estimatedDuration: QualifiedDuration?,
        transferNotes: QualifiedStringList?,
        routeSectionSnapshot: PersonalTripRouteSectionSnapshot?,
        start: QualifiedPlace?,
        end: QualifiedPlace?,
        distance: QualifiedDistance?,
        ascent: QualifiedElevationGain?
    ) {
        self.sequence = sequence
        self.actionType = actionType
        self.origin = origin
        self.destination = destination
        self.mode = mode
        self.keyTimes = keyTimes
        self.estimatedDuration = estimatedDuration
        self.transferNotes = transferNotes
        self.routeSectionSnapshot = routeSectionSnapshot
        self.start = start
        self.end = end
        self.distance = distance
        self.ascent = ascent
    }
}

public struct PersonalTripDayWeather: Codable, Equatable {
     public let condition: QualifiedString
     public let temperatureRange: QualifiedTemperatureRange
     public let precipitation: QualifiedString
     public let wind: QualifiedString
     public let placeContext: QualifiedString
     public let routeSectionContext: QualifiedString?
     public let source: QualifiedString?
     public let updatedAt: QualifiedInstant?

    public enum CodingKeys: String, CodingKey {
        case condition, temperatureRange, precipitation, wind
        case placeContext, routeSectionContext, source, updatedAt
    }

    public init(
        condition: QualifiedString,
        temperatureRange: QualifiedTemperatureRange,
        precipitation: QualifiedString,
        wind: QualifiedString,
        placeContext: QualifiedString,
        routeSectionContext: QualifiedString?,
        source: QualifiedString?,
        updatedAt: QualifiedInstant?
    ) {
        self.condition = condition
        self.temperatureRange = temperatureRange
        self.precipitation = precipitation
        self.wind = wind
        self.placeContext = placeContext
        self.routeSectionContext = routeSectionContext
        self.source = source
        self.updatedAt = updatedAt
    }
}

public struct PersonalTripPoint: Codable, Equatable, Identifiable {
     public let sequence: Int
     public let category: String
     public let type: String
     public let name: String?
     public let distance: QualifiedDistance?
     public let location: QualifiedPosition?
     public let details: QualifiedString?
     public let isAlternative: Bool?

     public var id: Int { sequence }

    public enum CodingKeys: String, CodingKey {
        case sequence, category, type, name, distance, location, details, isAlternative
    }

    public init(
        sequence: Int,
        category: String,
        type: String,
        name: String?,
        distance: QualifiedDistance?,
        location: QualifiedPosition?,
        details: QualifiedString?,
        isAlternative: Bool?
    ) {
        self.sequence = sequence
        self.category = category
        self.type = type
        self.name = name
        self.distance = distance
        self.location = location
        self.details = details
        self.isAlternative = isAlternative
    }
}

public struct PersonalTripDay: Codable, Equatable, Identifiable {
     public let identity: String
     public let dayNumber: Int
     public let date: LocalDate
     public let primaryStage: String
     public let hikingDayNumber: Int?
     public let actions: [PersonalTripAction]
     public let weather: PersonalTripDayWeather
     public let points: [PersonalTripPoint]?

     public var id: String { identity }

    public enum CodingKeys: String, CodingKey {
        case identity, dayNumber, date, primaryStage, hikingDayNumber, actions, weather, points
    }

    public init(
        identity: String,
        dayNumber: Int,
        date: LocalDate,
        primaryStage: String,
        hikingDayNumber: Int?,
        actions: [PersonalTripAction],
        weather: PersonalTripDayWeather,
        points: [PersonalTripPoint]?
    ) {
        self.identity = identity
        self.dayNumber = dayNumber
        self.date = date
        self.primaryStage = primaryStage
        self.hikingDayNumber = hikingDayNumber
        self.actions = actions
        self.weather = weather
        self.points = points
    }
}

public struct PersonalTripEquipmentSummary: Codable, Equatable {
     public let itemCount: Int
     public let knownTotalWeight: EquipmentWeight
     public let missingWeightItemCount: Int
     public let ownedItemCount: Int
     public let unconfirmedOwnedItemCount: Int

    public enum CodingKeys: String, CodingKey {
        case itemCount, knownTotalWeight, missingWeightItemCount
        case ownedItemCount, unconfirmedOwnedItemCount
    }

    public init(
        itemCount: Int,
        knownTotalWeight: EquipmentWeight,
        missingWeightItemCount: Int,
        ownedItemCount: Int,
        unconfirmedOwnedItemCount: Int
    ) {
        self.itemCount = itemCount
        self.knownTotalWeight = knownTotalWeight
        self.missingWeightItemCount = missingWeightItemCount
        self.ownedItemCount = ownedItemCount
        self.unconfirmedOwnedItemCount = unconfirmedOwnedItemCount
    }
}

public struct PersonalTripEquipmentSnapshotReference: Codable, Equatable {
     public let snapshotID: String
     public let summary: PersonalTripEquipmentSummary

    public enum CodingKeys: String, CodingKey {
        case snapshotID = "snapshotId"
        case summary
    }

    public init(
        snapshotID: String,
        summary: PersonalTripEquipmentSummary
    ) {
        self.snapshotID = snapshotID
        self.summary = summary
    }
}

public struct PersonalTripRouteVersionReference: Codable, Equatable {
     public let routeVersionID: String
     public let versionLabel: String?

    public enum CodingKeys: String, CodingKey {
        case routeVersionID = "routeVersionId"
        case versionLabel
    }

    public init(
        routeVersionID: String,
        versionLabel: String?
    ) {
        self.routeVersionID = routeVersionID
        self.versionLabel = versionLabel
    }
}

public enum PersonalTripVersionRelationship: String, Codable, Equatable {
    case current
    case newerPublicVersionAvailable = "newer_public_version_available"
    case currentPublicVersionUnavailable = "current_public_version_unavailable"
}

public enum PersonalTripRouteDifferenceCategory: String, Codable, Equatable, CaseIterable {
    case identityAndStructure = "identity_and_structure"
    case trackAndSegments = "track_and_segments"
    case scaleDifficultyAndTime = "scale_difficulty_and_time"
    case planningSupportAndSafety = "planning_support_and_safety"
    case seasonalPreparationAndEquipment = "seasonal_preparation_and_equipment"

     public var title: String {
        switch self {
        case .identityAndStructure: "路线身份与结构"
        case .trackAndSegments: "线路与轨迹"
        case .scaleDifficultyAndTime: "体量、难度与时间"
        case .planningSupportAndSafety: "规划、沿途保障与安全"
        case .seasonalPreparationAndEquipment: "季节准备与装备建议"
        }
    }
}

public enum PersonalTripRouteDifferenceChangeType: String, Codable, Equatable {
    case added
    case noLongerProvided = "no_longer_provided"
    case modified

     public var title: String {
        switch self {
        case .added: "新增"
        case .noLongerProvided: "新版不再提供"
        case .modified: "已修改"
        }
    }
}

public enum PersonalTripRouteMinimumComparisonStatus: String, Codable, Equatable {
    case complete
    case partial
    case unavailable
}

public enum PersonalTripOtherRelevantChangeStatus: String, Codable, Equatable {
    case none
    case changed
    case unknown
}

public struct PersonalTripRouteVersionDifferenceItem: Codable, Equatable, Identifiable {
     public let category: PersonalTripRouteDifferenceCategory
     public let changeType: PersonalTripRouteDifferenceChangeType
     public let subject: String
     public let summary: String
     public let before: QualifiedString?
     public let after: QualifiedString?

     public var id: String { "\(category.rawValue):\(changeType.rawValue):\(subject)" }

    public enum CodingKeys: String, CodingKey {
        case category, changeType, subject, summary, before, after
    }

    public init(
        category: PersonalTripRouteDifferenceCategory,
        changeType: PersonalTripRouteDifferenceChangeType,
        subject: String,
        summary: String,
        before: QualifiedString?,
        after: QualifiedString?
    ) {
        self.category = category
        self.changeType = changeType
        self.subject = subject
        self.summary = summary
        self.before = before
        self.after = after
    }
}

public struct PersonalTripRouteVersionDifference: Codable, Equatable {
     public let minimumComparisonStatus: PersonalTripRouteMinimumComparisonStatus
     public let differences: [PersonalTripRouteVersionDifferenceItem]
     public let unavailableCategories: [PersonalTripRouteDifferenceCategory]
     public let otherRelevantChangeStatus: PersonalTripOtherRelevantChangeStatus
     public let otherRelevantChanges: [String]

    public enum CodingKeys: String, CodingKey {
        case minimumComparisonStatus, differences, unavailableCategories
        case otherRelevantChangeStatus, otherRelevantChanges
    }

    public init(
        minimumComparisonStatus: PersonalTripRouteMinimumComparisonStatus,
        differences: [PersonalTripRouteVersionDifferenceItem],
        unavailableCategories: [PersonalTripRouteDifferenceCategory],
        otherRelevantChangeStatus: PersonalTripOtherRelevantChangeStatus,
        otherRelevantChanges: [String]
    ) {
        self.minimumComparisonStatus = minimumComparisonStatus
        self.differences = differences
        self.unavailableCategories = unavailableCategories
        self.otherRelevantChangeStatus = otherRelevantChangeStatus
        self.otherRelevantChanges = otherRelevantChanges
    }
}

public struct PersonalTripRouteVersionStatus: Codable, Equatable {
     public let tripID: String
     public let tripRevision: String
     public let adoptedVersion: PersonalTripRouteVersionReference
     public let currentPublicVersion: PersonalTripRouteVersionReference?
     public let versionRelationship: PersonalTripVersionRelationship
     public let migrationEligible: Bool
     public let difference: PersonalTripRouteVersionDifference?

    public enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case tripRevision, adoptedVersion, currentPublicVersion
        case versionRelationship, migrationEligible, difference
    }

    public init(
        tripID: String,
        tripRevision: String,
        adoptedVersion: PersonalTripRouteVersionReference,
        currentPublicVersion: PersonalTripRouteVersionReference?,
        versionRelationship: PersonalTripVersionRelationship,
        migrationEligible: Bool,
        difference: PersonalTripRouteVersionDifference?
    ) {
        self.tripID = tripID
        self.tripRevision = tripRevision
        self.adoptedVersion = adoptedVersion
        self.currentPublicVersion = currentPublicVersion
        self.versionRelationship = versionRelationship
        self.migrationEligible = migrationEligible
        self.difference = difference
    }
}

public struct PersonalTripDetail: Codable, Equatable {
     public let revision: String
     public let trip: PersonalTripProjection
     public let routeReference: PersonalTripRouteReference
     public let days: [PersonalTripDay]
     public let equipmentSnapshot: PersonalTripEquipmentSnapshotReference
     public let routeVersionStatus: PersonalTripRouteVersionStatus

    public enum CodingKeys: String, CodingKey {
        case revision, trip, routeReference, days, equipmentSnapshot, routeVersionStatus
    }

    public init(
        revision: String,
        trip: PersonalTripProjection,
        routeReference: PersonalTripRouteReference,
        days: [PersonalTripDay],
        equipmentSnapshot: PersonalTripEquipmentSnapshotReference,
        routeVersionStatus: PersonalTripRouteVersionStatus
    ) {
        self.revision = revision
        self.trip = trip
        self.routeReference = routeReference
        self.days = days
        self.equipmentSnapshot = equipmentSnapshot
        self.routeVersionStatus = routeVersionStatus
    }
}

public struct PersonalTripDays: Codable, Equatable {
     public let tripID: String
     public let revision: String
     public let startDate: LocalDate
     public let endDate: LocalDate
     public let totalDayCount: Int
     public let hikingDayCount: Int
     public let days: [PersonalTripDay]

    public enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case revision, startDate, endDate, totalDayCount, hikingDayCount, days
    }

    public init(
        tripID: String,
        revision: String,
        startDate: LocalDate,
        endDate: LocalDate,
        totalDayCount: Int,
        hikingDayCount: Int,
        days: [PersonalTripDay]
    ) {
        self.tripID = tripID
        self.revision = revision
        self.startDate = startDate
        self.endDate = endDate
        self.totalDayCount = totalDayCount
        self.hikingDayCount = hikingDayCount
        self.days = days
    }
}

public struct PersonalTripWeatherDay: Codable, Equatable, Identifiable {
     public let tripDayID: String
     public let dayNumber: Int
     public let date: LocalDate
     public let primaryStage: String
     public let hikingDayNumber: Int?
     public let weather: PersonalTripDayWeather

     public var id: String { tripDayID }

    public enum CodingKeys: String, CodingKey {
        case tripDayID = "tripDayId"
        case dayNumber, date, primaryStage, hikingDayNumber, weather
    }

    public init(
        tripDayID: String,
        dayNumber: Int,
        date: LocalDate,
        primaryStage: String,
        hikingDayNumber: Int?,
        weather: PersonalTripDayWeather
    ) {
        self.tripDayID = tripDayID
        self.dayNumber = dayNumber
        self.date = date
        self.primaryStage = primaryStage
        self.hikingDayNumber = hikingDayNumber
        self.weather = weather
    }
}

public struct LegacyPersonalTripWeather: Codable, Equatable {
     public let tripID: String
     public let revision: String
     public let routeName: String
     public let startDate: LocalDate
     public let endDate: LocalDate
     public let days: [PersonalTripWeatherDay]
     public let weatherOverview: WeatherOverview?

    public enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case revision, routeName, startDate, endDate, days, weatherOverview
    }

    public init(
        tripID: String,
        revision: String,
        routeName: String,
        startDate: LocalDate,
        endDate: LocalDate,
        days: [PersonalTripWeatherDay],
        weatherOverview: WeatherOverview?
    ) {
        self.tripID = tripID
        self.revision = revision
        self.routeName = routeName
        self.startDate = startDate
        self.endDate = endDate
        self.days = days
        self.weatherOverview = weatherOverview
    }
}

public struct WeatherQualifiedValue<Value: Codable & Equatable>: Codable, Equatable {
     public let value: Value?
     public let confidence: InformationConfidence?

     public init(value: Value? = nil, confidence: InformationConfidence? = nil) {
        self.value = value
        self.confidence = confidence
    }
}

public struct WeatherLocation: Codable, Equatable {
     public let position: PublicRouteGeoPosition
     public let name: String?

     public init(position: PublicRouteGeoPosition, name: String? = nil) {
        self.position = position
        self.name = name
    }
}

public struct WeatherCondition: Codable, Equatable {
     public let description: String

     public init(description: String) {
        self.description = description
    }
}

public struct PrecipitationAmount: Codable, Equatable {
     public let millimeters: Double

     public init(millimeters: Double) {
        self.millimeters = millimeters
    }
}

public struct WindSpeed: Codable, Equatable {
     public let metersPerSecond: Double

     public init(metersPerSecond: Double) {
        self.metersPerSecond = metersPerSecond
    }
}

public struct WeatherPrecipitation: Codable, Equatable {
     public let description: String?
     public let probability: Double?
     public let amount: PrecipitationAmount?

     public init(
        description: String? = nil,
        probability: Double? = nil,
        amount: PrecipitationAmount? = nil
    ) {
        self.description = description
        self.probability = probability
        self.amount = amount
    }
}

public struct WeatherWind: Codable, Equatable {
     public let description: String?
     public let averageSpeed: WindSpeed?
     public let gustSpeed: WindSpeed?
     public let direction: String?

     public init(
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

public struct WeatherForecastPeriod: Codable, Equatable {
     public let periodStart: Instant
     public let periodEnd: Instant
     public let condition: WeatherQualifiedValue<WeatherCondition>?
     public let temperatureRange: WeatherQualifiedValue<TemperatureRange>?
     public let precipitation: WeatherQualifiedValue<WeatherPrecipitation>?
     public let wind: WeatherQualifiedValue<WeatherWind>?

     public init(
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

public struct WeatherForecast: Codable, Equatable {
     public let identity: String
     public let location: WeatherLocation
     public let source: String?
     public let publishedAt: Instant?
     public let periods: [WeatherForecastPeriod]

     public init(
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

public enum TripWeatherAssociationScope: String, Codable, Equatable {
    case day
    case hikeAction = "hike_action"
}

public struct TripWeatherAssociation: Codable, Equatable, Identifiable {
     public let associationIdentity: String
     public let sequence: Int
     public let scope: TripWeatherAssociationScope
     public let hikeActionIdentity: String?
     public let targetLocation: WeatherLocation
     public let targetPeriodStart: Instant
     public let targetPeriodEnd: Instant
     public let forecastConfidence: InformationConfidence?
     public let forecast: WeatherForecast?

     public var id: String { associationIdentity }

     public init(
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

public struct PersonalTripWeatherAssociationDay: Codable, Equatable, Identifiable {
     public let tripDayID: String
     public let dayNumber: Int
     public let date: LocalDate
     public let weatherAssociations: [TripWeatherAssociation]

     public var id: String { tripDayID }

     public init(
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

    public enum CodingKeys: String, CodingKey {
        case tripDayID = "tripDayId"
        case dayNumber, date, weatherAssociations
    }
}

public struct PersonalTripWeather: Codable, Equatable {
     public let tripID: String
     public let revision: String
     public let days: [PersonalTripWeatherAssociationDay]

     public init(tripID: String, revision: String, days: [PersonalTripWeatherAssociationDay]) {
        self.tripID = tripID
        self.revision = revision
        self.days = days
    }

    public enum CodingKeys: String, CodingKey {
        case tripID = "tripId"
        case revision, days
    }
}

public struct PersonalTripGenerationRoute: Codable, Equatable {
     public let routeID: String
     public let currentPublicRouteVersionID: String
     public let routeType: String
     public let generationEligibility: RouteGenerationEligibility
     public let versionLabel: String?
     public let name: String?
     public let region: String?
     public let start: PublicRoutePlace?
     public let end: PublicRoutePlace?
     public let difficulty: String?
     public let distance: RouteDistance?
     public let estimatedDuration: RouteDuration?

    public enum CodingKeys: String, CodingKey {
        case routeID = "routeId"
        case currentPublicRouteVersionID = "currentPublicRouteVersionId"
        case routeType, generationEligibility, versionLabel
        case name, region, start, end, difficulty, distance, estimatedDuration
    }

    public init(
        routeID: String,
        currentPublicRouteVersionID: String,
        routeType: String,
        generationEligibility: RouteGenerationEligibility,
        versionLabel: String?,
        name: String?,
        region: String?,
        start: PublicRoutePlace?,
        end: PublicRoutePlace?,
        difficulty: String?,
        distance: RouteDistance?,
        estimatedDuration: RouteDuration?
    ) {
        self.routeID = routeID
        self.currentPublicRouteVersionID = currentPublicRouteVersionID
        self.routeType = routeType
        self.generationEligibility = generationEligibility
        self.versionLabel = versionLabel
        self.name = name
        self.region = region
        self.start = start
        self.end = end
        self.difficulty = difficulty
        self.distance = distance
        self.estimatedDuration = estimatedDuration
    }
}

public struct PersonalTripGenerationEquipmentListOption: Codable, Equatable, Identifiable {
     public let equipmentListID: String
     public let name: String
     public let summary: EquipmentListSummary

     public var id: String { equipmentListID }

    public enum CodingKeys: String, CodingKey {
        case equipmentListID = "equipmentListId"
        case name, summary
    }

    public init(
        equipmentListID: String,
        name: String,
        summary: EquipmentListSummary
    ) {
        self.equipmentListID = equipmentListID
        self.name = name
        self.summary = summary
    }
}

public struct PersonalTripGenerationContext: Codable, Equatable {
     public let route: PersonalTripGenerationRoute
     public let personalEquipmentSummary: PersonalEquipmentSummary
     public let equipmentLists: [PersonalTripGenerationEquipmentListOption]

    public enum CodingKeys: String, CodingKey {
        case route, personalEquipmentSummary, equipmentLists
    }

    public init(
        route: PersonalTripGenerationRoute,
        personalEquipmentSummary: PersonalEquipmentSummary,
        equipmentLists: [PersonalTripGenerationEquipmentListOption]
    ) {
        self.route = route
        self.personalEquipmentSummary = personalEquipmentSummary
        self.equipmentLists = equipmentLists
    }
}

public struct PersonalTripTransportOption: Codable, Equatable, Identifiable {
     public let transportOptionID: String
     public let transferCount: QualifiedInteger
     public let estimatedArrivalAt: QualifiedInstant
     public let estimatedDuration: QualifiedDuration
     public let verificationItems: [String]

     public var id: String { transportOptionID }

    public enum CodingKeys: String, CodingKey {
        case transportOptionID = "transportOptionId"
        case transferCount, estimatedArrivalAt, estimatedDuration, verificationItems
    }

    public init(
        transportOptionID: String,
        transferCount: QualifiedInteger,
        estimatedArrivalAt: QualifiedInstant,
        estimatedDuration: QualifiedDuration,
        verificationItems: [String]
    ) {
        self.transportOptionID = transportOptionID
        self.transferCount = transferCount
        self.estimatedArrivalAt = estimatedArrivalAt
        self.estimatedDuration = estimatedDuration
        self.verificationItems = verificationItems
    }
}

public struct PersonalTripTransportSelection: Codable, Equatable {
     public let selectionID: String
     public let options: [PersonalTripTransportOption]

    public enum CodingKeys: String, CodingKey {
        case selectionID = "selectionId"
        case options
    }

    public init(
        selectionID: String,
        options: [PersonalTripTransportOption]
    ) {
        self.selectionID = selectionID
        self.options = options
    }
}

public enum PersonalTripGenerationResult: Decodable, Equatable {
    case transportSelectionRequired(PersonalTripTransportSelection)
    case tripCreated(PersonalTripDetail)

    private enum CodingKeys: String, CodingKey {
        case resultType, selection, trip
    }

    private enum ResultType: String, Decodable {
        case transportSelectionRequired = "transport_selection_required"
        case tripCreated = "trip_created"
    }

     public init(from decoder: Decoder) throws {
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

public struct PersonalTripTransportSelectionRequest: Encodable, Equatable {
     public let selectionID: String
     public let transportOptionID: String

    public enum CodingKeys: String, CodingKey {
        case selectionID = "selectionId"
        case transportOptionID = "transportOptionId"
    }

    public init(
        selectionID: String,
        transportOptionID: String
    ) {
        self.selectionID = selectionID
        self.transportOptionID = transportOptionID
    }
}

public struct PersonalTripCreateRequest: Encodable, Equatable {
     public let routeID: String
     public let routeVersionID: String
     public let departureCity: String
     public let startDate: LocalDate
     public let equipmentListID: String?
     public let transportSelection: PersonalTripTransportSelectionRequest?

    public enum CodingKeys: String, CodingKey {
        case routeID = "routeId"
        case routeVersionID = "routeVersionId"
        case departureCity, startDate
        case equipmentListID = "equipmentListId"
        case transportSelection
    }

    public init(
        routeID: String,
        routeVersionID: String,
        departureCity: String,
        startDate: LocalDate,
        equipmentListID: String?,
        transportSelection: PersonalTripTransportSelectionRequest?
    ) {
        self.routeID = routeID
        self.routeVersionID = routeVersionID
        self.departureCity = departureCity
        self.startDate = startDate
        self.equipmentListID = equipmentListID
        self.transportSelection = transportSelection
    }
}

public struct PersonalTripCancelRequest: Encodable, Equatable {
     public let expectedRevision: String
     public let confirmed: Bool

    public init(
        expectedRevision: String,
        confirmed: Bool
    ) {
        self.expectedRevision = expectedRevision
        self.confirmed = confirmed
    }
}

public struct PersonalTripMigrateRequest: Encodable, Equatable {
     public let expectedRevision: String
     public let targetRouteVersionID: String

    public enum CodingKeys: String, CodingKey {
        case expectedRevision
        case targetRouteVersionID = "targetRouteVersionId"
    }

    public init(
        expectedRevision: String,
        targetRouteVersionID: String
    ) {
        self.expectedRevision = expectedRevision
        self.targetRouteVersionID = targetRouteVersionID
    }
}
