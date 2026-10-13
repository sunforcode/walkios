import Foundation

/// 日级冻结参考资料；来源身份由后端明确投影，不由客户端按日序匹配。
public struct PersonalTripRouteGuide: Codable, Equatable {
    public let sourceReferenceDayID: String
    public let title: QualifiedString?
    public let start: QualifiedPlace?
    public let end: QualifiedPlace?
    public let description: QualifiedString?
    public let notes: QualifiedString?
    public let accommodationReference: QualifiedString?
    public let referenceTrack: PersonalTripReferenceTrack?

    enum CodingKeys: String, CodingKey {
        case sourceReferenceDayID = "sourceReferenceDayId"
        case title, start, end, description, notes, accommodationReference, referenceTrack
    }

    public init(sourceReferenceDayID: String, description: QualifiedString? = nil,
                notes: QualifiedString? = nil, accommodationReference: QualifiedString? = nil,
                referenceTrack: PersonalTripReferenceTrack? = nil,
                title: QualifiedString? = nil, start: QualifiedPlace? = nil, end: QualifiedPlace? = nil) {
        self.sourceReferenceDayID = sourceReferenceDayID
        self.title = title
        self.start = start
        self.end = end
        self.description = description
        self.notes = notes
        self.accommodationReference = accommodationReference
        self.referenceTrack = referenceTrack
    }
}

/// 参考日完整范围及原行进统计，可能包含交通；绝不作为实际 hike 指标的兜底值。
public struct PersonalTripReferenceTrack: Codable, Equatable {
    public let path: [PublicRouteGeoPosition]?
    public let distance: RouteDistance?
    public let ascent: RouteElevationGain?
    public let descent: RouteElevationLoss?
    public let estimatedDuration: RouteDuration?
    public let elevationProfile: FrozenRouteElevationProfile?
    public let confidence: InformationConfidence

    public init(path: [PublicRouteGeoPosition]? = nil, distance: RouteDistance? = nil,
                ascent: RouteElevationGain? = nil, descent: RouteElevationLoss? = nil,
                estimatedDuration: RouteDuration? = nil, confidence: InformationConfidence,
                elevationProfile: FrozenRouteElevationProfile? = nil) {
        self.path = path
        self.distance = distance
        self.ascent = ascent
        self.descent = descent
        self.estimatedDuration = estimatedDuration
        self.elevationProfile = elevationProfile
        self.confidence = confidence
    }
}
