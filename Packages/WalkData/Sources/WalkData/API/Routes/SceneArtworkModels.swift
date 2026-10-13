import Foundation

/// 独立艺术资源；不是路线几何、导航资料或海拔来源。
public struct SceneImage: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case aigc }
    public let mediaID: String
    public let imageURL: String
    public let width: Int
    public let height: Int
    public let kind: Kind

    enum CodingKeys: String, CodingKey {
        case mediaID = "mediaId", imageURL = "imageUrl", width, height, kind
    }

    public init(mediaID: String, imageURL: String, width: Int, height: Int, kind: Kind) {
        self.mediaID = mediaID
        self.imageURL = imageURL
        self.width = width
        self.height = height
        self.kind = kind
    }

    public var remoteURL: URL? {
        guard !mediaID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              width > 0, height > 0,
              let url = URL(string: imageURL),
              ["https", "http"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}

public struct PublicRouteScenes: Codable, Equatable, Sendable {
    public struct Day: Codable, Equatable, Sendable {
        public let referenceDayID: String
        public let image: SceneImage
        enum CodingKeys: String, CodingKey { case referenceDayID = "referenceDayId", image }
        public init(referenceDayID: String, image: SceneImage) {
            self.referenceDayID = referenceDayID
            self.image = image
        }
    }

    public let routeID: String
    public let routeVersionID: String
    public let sceneRevision: String
    public let overview: SceneImage?
    public let days: [Day]
    enum CodingKeys: String, CodingKey {
        case routeID = "routeId", routeVersionID = "routeVersionId", sceneRevision, overview, days
    }

    public init(routeID: String, routeVersionID: String, sceneRevision: String, overview: SceneImage? = nil, days: [Day]) {
        self.routeID = routeID
        self.routeVersionID = routeVersionID
        self.sceneRevision = sceneRevision
        self.overview = overview
        self.days = days
    }

    public func isValid(routeID: String, routeVersionID: String, referenceDayIDs: Set<String>) -> Bool {
        self.routeID == routeID && self.routeVersionID == routeVersionID
            && !sceneRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Set(days.map(\.referenceDayID)).count == days.count
            && days.allSatisfy { referenceDayIDs.contains($0.referenceDayID) && $0.image.remoteURL != nil }
            && (overview == nil || overview?.remoteURL != nil)
    }
}

public struct PersonalTripScenes: Codable, Equatable, Sendable {
    public struct Day: Codable, Equatable, Sendable {
        public let tripDayID: String
        public let image: SceneImage
        enum CodingKeys: String, CodingKey { case tripDayID = "tripDayId", image }
        public init(tripDayID: String, image: SceneImage) {
            self.tripDayID = tripDayID
            self.image = image
        }
    }

    public let tripID: String
    public let tripRevision: String
    public let routeVersionID: String
    public let sceneRevision: String
    public let overview: SceneImage?
    public let days: [Day]
    enum CodingKeys: String, CodingKey {
        case tripID = "tripId", tripRevision, routeVersionID = "routeVersionId", sceneRevision, overview, days
    }

    public init(tripID: String, tripRevision: String, routeVersionID: String, sceneRevision: String, overview: SceneImage? = nil, days: [Day]) {
        self.tripID = tripID
        self.tripRevision = tripRevision
        self.routeVersionID = routeVersionID
        self.sceneRevision = sceneRevision
        self.overview = overview
        self.days = days
    }

    public func isValid(tripID: String, tripRevision: String, routeVersionID: String, tripDayIDs: Set<String>) -> Bool {
        self.tripID == tripID && self.tripRevision == tripRevision && self.routeVersionID == routeVersionID
            && !sceneRevision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Set(days.map(\.tripDayID)).count == days.count
            && days.allSatisfy { tripDayIDs.contains($0.tripDayID) && $0.image.remoteURL != nil }
            && (overview == nil || overview?.remoteURL != nil)
    }
}
