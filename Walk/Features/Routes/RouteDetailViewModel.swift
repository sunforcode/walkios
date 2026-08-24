import SwiftUI
import CoreLocation

struct RoutePOIAnnotation: Identifiable, Equatable {
    let id: String
    let title: String
    let category: String
    let subCategory: String
    let detail: String
    let elevation: String
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct RouteTrackPointMetadata: Identifiable, Equatable {
    let id: String
    let title: String
    let type: String
    let detail: String
    let imageURL: URL?
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct RouteWaypointAnnotation: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let elevation: String
    let type: String
    let imageURL: URL?
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct RouteSummaryMetric: Equatable {
    let title: String
    let value: String
    let icon: String
}

struct RouteContactPresentation: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let location: String
    let price: String
    let verification: String
    let phone: String
    let showsPhoneByDefault = false
}

enum RouteDetailSectionID: String, CaseIterable, Hashable {
    case overview
    case itinerary
    case safeguards
    case preparation
    case imagery
    case related
}

struct RouteDetailSectionItem: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct RouteDetailSectionPresentation: Identifiable, Equatable {
    let id: RouteDetailSectionID
    let title: String
    let items: [RouteDetailSectionItem]
    let emptyState: String
}

struct RouteDetailImagePresentation: Identifiable, Equatable {
    let id: Int
    let source: String
    let failurePlaceholderSystemImage = "photo"
}

struct RouteDetailActionPolicy: Equatable {
    let shareText: String
    let usesSystemShareSheet = true
    let initiatesPhoneCall = false

    static func canCopyPhone(_ phone: String) -> Bool {
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct RouteDetailPresentation: Equatable {
    let route: RouteDetailResponse

    var sections: [RouteDetailSectionPresentation] {
        [
            .init(id: .overview, title: "概览与环境", items: overviewItems, emptyState: "暂无数据"),
            .init(id: .itinerary, title: "行程安排", items: itineraryItems, emptyState: "暂无数据"),
            .init(id: .safeguards, title: "沿途保障", items: [], emptyState: "营地、水源、补给暂无数据"),
            .init(id: .preparation, title: "出行准备", items: preparationItems, emptyState: "季节装备、拼车联系人暂无数据"),
            .init(id: .imagery, title: "路线影像与热度", items: imageryItems, emptyState: "暂无数据"),
            .init(id: .related, title: "相关内容", items: [], emptyState: "相关路线、相关行程暂无数据")
        ]
    }
    var name: String { RouteDetailFormatting.text(route.name) }
    var difficulty: String { route.difficulty?.displayText ?? "暂无数据" }
    var routeType: String { route.routeType?.displayText ?? "暂无数据" }
    var loopState: String { route.isLoop ? "环线" : "非环线" }
    var region: String { RouteDetailFormatting.text(route.region) }
    var creatorName: String {
        guard let creator = route.creator else { return "暂无数据" }
        let nickname = RouteDetailFormatting.text(creator.nickname)
        return nickname == "暂无数据" ? RouteDetailFormatting.text(creator.username) : nickname
    }
    var actionPolicy: RouteDetailActionPolicy { .init(shareText: name) }
    var collapsedSummaryFields: [String] {
        [name, creatorName, difficulty, routeType, loopState, region] + summaryMetrics.map(\.value)
    }
    var summaryMetrics: [RouteSummaryMetric] {
        [
            .init(title: "距离", value: decimal(route.distance, unit: "km"), icon: "point.topleft.down.curvedto.point.bottomright.up"),
            .init(title: "时长", value: integer(route.duration, unit: "天"), icon: "clock"),
            .init(title: "爬升", value: decimal(route.elevationGain, unit: "m"), icon: "arrow.up.right"),
            .init(title: "下降", value: decimal(route.elevationLoss, unit: "m"), icon: "arrow.down.right")
        ]
    }
    var images: [RouteDetailImagePresentation] {
        ([route.coverUrl].compactMap { $0 } + route.imageUrls)
            .enumerated()
            .map { RouteDetailImagePresentation(id: $0.offset, source: $0.element) }
    }
    var contacts: [RouteContactPresentation] {
        route.hitchhikeContacts.map {
            RouteContactPresentation(
                id: $0.id,
                name: RouteDetailFormatting.text($0.name),
                description: RouteDetailFormatting.text($0.description),
                location: RouteDetailFormatting.text($0.location),
                price: decimal($0.price, unit: "元"),
                verification: $0.lastVerified ? "已认证" : "未认证",
                phone: $0.phone
            )
        }
    }

    private var overviewItems: [RouteDetailSectionItem] {
        let seasonalWeather = route.weatherInfo?.seasonalWeather
            .sorted { $0.key < $1.key }
            .map { "\($0.key)：\(text($0.value))" }
            .joined(separator: "、")

        return [
            .init(id: "description", title: "路线描述", value: text(route.description)),
            .init(id: "tags", title: "标签", value: route.tags.isEmpty ? "暂无数据" : route.tags.map(text).joined(separator: "、")),
            .init(id: "rating-overall", title: "总评分", value: decimal(route.ratings?.overall)),
            .init(id: "rating-count", title: "评分人数", value: integer(route.ratings?.ratingCount)),
            .init(id: "rating-scenery", title: "风景评分", value: decimal(route.ratings?.scenery)),
            .init(id: "rating-difficulty", title: "难度评分", value: decimal(route.ratings?.difficulty)),
            .init(id: "rating-experience", title: "体验评分", value: decimal(route.ratings?.experience)),
            .init(id: "rating-facilities", title: "设施评分", value: decimal(route.ratings?.facilities)),
            .init(id: "region", title: "区域", value: region),
            .init(id: "route-type", title: "路线类型", value: routeType),
            .init(id: "is-loop", title: "路线形态", value: loopState),
            .init(id: "weather-description", title: "天气描述", value: text(route.weatherInfo?.description)),
            .init(id: "weather-precautions", title: "天气注意事项", value: text(route.weatherInfo?.precautions)),
            .init(
                id: "best-seasons",
                title: "最佳季节",
                value: route.weatherInfo?.bestSeasons.isEmpty == false
                    ? route.weatherInfo?.bestSeasons.map(text).joined(separator: "、") ?? "暂无数据"
                    : "暂无数据"
            ),
            .init(
                id: "seasonal-weather",
                title: "季节天气",
                value: seasonalWeather?.isEmpty == false ? seasonalWeather ?? "暂无数据" : "暂无数据"
            )
        ]
    }

    private var itineraryItems: [RouteDetailSectionItem] {
        var items: [RouteDetailSectionItem] = []
        if !route.dailyPlans.isEmpty {
            items.append(.init(id: "daily-plans", title: "每日计划", value: route.dailyPlans.sorted { $0.dayNumber < $1.dayNumber }.map { text($0.title) }.joined(separator: "、")))
        }
        if !route.segmentSchemes.isEmpty {
            items.append(.init(id: "segment-schemes", title: "分段方案", value: route.segmentSchemes.map { text($0.label) }.joined(separator: "、")))
        }
        if !route.poiPoints.isEmpty {
            items.append(.init(id: "poi-points", title: "沿途兴趣点", value: route.poiPoints.map { text($0.name) }.joined(separator: "、")))
        }
        return items
    }

    private var preparationItems: [RouteDetailSectionItem] {
        guard !contacts.isEmpty else { return [] }
        return [.init(id: "contacts", title: "拼车联系人", value: contacts.map(\.name).joined(separator: "、"))]
    }

    private var imageryItems: [RouteDetailSectionItem] {
        var items = [
            RouteDetailSectionItem(id: "popularity", title: "路线热度", value: "\(route.popularity)"),
            RouteDetailSectionItem(id: "usage-count", title: "使用次数", value: "\(route.usageCount)"),
            RouteDetailSectionItem(id: "creator", title: "创建者", value: creatorName)
        ]
        if !images.isEmpty { items.insert(.init(id: "images", title: "路线影像", value: "\(images.count) 张"), at: 0) }
        return items
    }

    func text(_ value: String?) -> String { RouteDetailFormatting.text(value) }
    func decimal(_ value: Double?, unit: String = "") -> String {
        guard let value else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(0...1))))\(unit)"
    }
    func integer(_ value: Int?, unit: String = "") -> String {
        guard let value else { return "—" }
        return "\(value)\(unit)"
    }
}

@MainActor
final class RouteDetailViewModel: ObservableObject {
    @Published private(set) var route: RouteDetailResponse?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var mapCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var poiAnnotations: [RoutePOIAnnotation] = []
    @Published private(set) var selectableTrackPoints: [RouteTrackPointMetadata] = []
    @Published private(set) var waypointAnnotations: [RouteWaypointAnnotation] = []
    @Published private(set) var isFavorite = false
    @Published var actionMessage: String?

    var presentation: RouteDetailPresentation? { route.map(RouteDetailPresentation.init) }
    var hasMissingTrack: Bool { route != nil && mapCoordinates.isEmpty }

    private let service: any RouteDetailServicing
    private var routeID: String?

    init(service: any RouteDetailServicing) {
        self.service = service
    }

    func loadRoute(id: String) async {
        routeID = id
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let detail = try await service.getRouteDetailResponse(id: id)
            route = detail
            isFavorite = detail.isFavorite
            projectMapData(from: detail)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func retry() async {
        guard let routeID else { return }
        await loadRoute(id: routeID)
    }

    func toggleFavorite() async {
        guard let route else { return }
        let previousValue = isFavorite
        isFavorite.toggle()
        actionMessage = nil
        do {
            try await service.setFavorite(routeID: route.id, isFavorite: isFavorite)
        } catch {
            isFavorite = previousValue
            actionMessage = Self.message(for: error)
        }
    }

    func copyPhone(_ phone: String, using writeToClipboard: (String) -> Void) {
        guard RouteDetailActionPolicy.canCopyPhone(phone) else { return }
        writeToClipboard(phone)
        actionMessage = "号码已复制"
    }

    private func projectMapData(from route: RouteDetailResponse) {
        let sorted = route.trackPoints.sorted { lhs, rhs in
            if lhs.sequenceNumber == rhs.sequenceNumber { return lhs.id < rhs.id }
            return lhs.sequenceNumber < rhs.sequenceNumber
        }
        mapCoordinates = sorted.map(\.coordinate)
        poiAnnotations = route.poiPoints
            .filter { CLLocationCoordinate2DIsValid($0.coordinate) }
            .map {
                RoutePOIAnnotation(
                    id: $0.id,
                    title: RouteDetailFormatting.text($0.name),
                    category: RouteDetailFormatting.text($0.category),
                    subCategory: RouteDetailFormatting.text($0.subCategory),
                    detail: RouteDetailFormatting.text($0.description),
                    elevation: $0.elevation.map { "\($0.formatted(.number.precision(.fractionLength(0...1))))m" } ?? "—",
                    latitude: $0.latitude,
                    longitude: $0.longitude
                )
            }
        selectableTrackPoints = sorted.compactMap {
            let hasMetadata = [$0.name, $0.type, $0.description, $0.imageUrl]
                .contains { value in value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            guard hasMetadata else { return nil }
            return RouteTrackPointMetadata(
                id: $0.id,
                title: RouteDetailFormatting.text($0.name),
                type: RouteDetailFormatting.text($0.type),
                detail: RouteDetailFormatting.text($0.description),
                imageURL: $0.imageUrl.flatMap(URL.init(string:)),
                latitude: $0.latitude,
                longitude: $0.longitude
            )
        }

        var seenWaypointIDs = Set<String>()
        waypointAnnotations = route.segmentSchemes
            .flatMap(\.segments)
            .flatMap { segment in [segment.startPoint, segment.endPoint].compactMap { $0 } + segment.keypoints }
            .filter { waypoint in
                CLLocationCoordinate2DIsValid(waypoint.coordinate)
                    && seenWaypointIDs.insert(waypoint.id).inserted
            }
            .map {
                RouteWaypointAnnotation(
                    id: $0.id,
                    title: RouteDetailFormatting.text($0.name),
                    detail: RouteDetailFormatting.text($0.description),
                    elevation: $0.elevation.map { "\($0.formatted(.number.precision(.fractionLength(0...1))))m" } ?? "—",
                    type: RouteDetailFormatting.text($0.type),
                    imageURL: [$0.imageUrl, $0.iconUrl].compactMap { $0 }.compactMap(URL.init(string:)).first,
                    latitude: $0.latitude,
                    longitude: $0.longitude
                )
            }
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}

private extension RouteTrackPoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension RouteWaypoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension RoutePOIPoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
