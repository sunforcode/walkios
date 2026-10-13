import SwiftUI
import CoreLocation
import Observation
import WalkData
import WalkDesignSystem

struct RoutePOIAnnotation: Identifiable, Equatable {
    let id: String
    let objectIdentity: String
    let title: String
    let category: String
    let subCategory: String
    let detail: String
    let elevation: String
    let imageURL: URL?
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct RouteTrackPointMetadata: Identifiable, Equatable {
    let id: String
    let objectIdentity: String
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
    let objectIdentity: String
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

struct RouteMapSegment: Identifiable {
    let id: String
    let name: String
    let colorHex: String?
    let coordinates: [CLLocationCoordinate2D]
}

/// 纯地图划分徽标投影：位于对应范围起点，发出 `selectSpan(spanID)`。
struct RouteDivisionBadgeProjection: Equatable {
    let spanID: String
    let label: String
    let colorHex: String
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: RouteDivisionBadgeProjection, rhs: RouteDivisionBadgeProjection) -> Bool {
        lhs.spanID == rhs.spanID
            && lhs.label == rhs.label
            && lhs.colorHex == rhs.colorHex
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

struct RouteSelectableSegment: Identifiable {
    let id: String
    let segment: PublicRouteSegment
    let isSelected: Bool
}

struct RouteElevationSample: Identifiable, Equatable {
    let sequenceNumber: Int
    let distance: Double
    let elevation: Double

    var id: Int { sequenceNumber }
}

struct RouteElevationProfilePresentation: Equatable {
    let minElevation: Double
    let maxElevation: Double
    let samples: [RouteElevationSample]
}

enum RouteMapSelection: Identifiable, Equatable {
    case poi(RoutePOIAnnotation)
    case trackPoint(RouteTrackPointMetadata)
    case waypoint(RouteWaypointAnnotation)

    var id: String {
        switch self {
        case .poi(let point): "poi-\(point.id)"
        case .trackPoint(let point): "track-\(point.id)"
        case .waypoint(let point): "waypoint-\(point.id)"
        }
    }

    var identity: String {
        switch self {
        case .poi(let point): point.objectIdentity
        case .trackPoint(let point): point.objectIdentity
        case .waypoint(let point): point.objectIdentity
        }
    }

    var annotationID: String {
        switch self {
        case .poi(let point): point.id
        case .trackPoint(let point): point.id
        case .waypoint(let point): point.id
        }
    }
}

struct RouteSummaryMetric: Equatable {
    let title: String
    let value: String
    let systemImage: String
}

enum RouteDetailSectionID: String, CaseIterable, Hashable {
    case overview
    case professionalAnalysis
    case elevation
    case referenceDays
    case segments
    case keyPoints
    case interestPoints
    case campsites
    case overnightPlaces
    case waterSources
    case supplyPoints
    case safeguards
    case seasonalWeather
    case seasonalEquipment
    case imagery
}

enum RoutePointGroupID: Hashable {
    case journey
    case support
}

struct RoutePointGroupProjection: Identifiable, Equatable {
    let id: RoutePointGroupID
    let sections: [RoutePointSectionProjection]
}

struct RouteDetailSectionItem: Identifiable, Equatable {
    let id: String
    let bookmark: String?
    let title: String
    let value: String

    init(id: String, bookmark: String? = nil, title: String, value: String) {
        self.id = id
        self.bookmark = bookmark
        self.title = title
        self.value = value
    }
}

struct RouteDetailSectionPresentation: Identifiable, Equatable {
    let id: RouteDetailSectionID
    let title: String
    let items: [RouteDetailSectionItem]
}

struct RouteDetailImagePresentation: Identifiable, Equatable {
    let id: String
    let source: String
    let caption: String?
    let failurePlaceholderSystemImage = "photo"
}

struct RouteDetailScenePresentation: Identifiable, Equatable {
    let id: String
    let source: String
    let contextLabel: String
}

struct RouteDetailActionPolicy: Equatable {
    let shareText: String
    let usesSystemShareSheet = true
}

struct RouteGenerationActionPresentation: Equatable {
    let title: String
    let isEnabled: Bool
    let unavailableMessage: String?
}

struct RouteDetailPresentation: Equatable {
    let route: PublicRouteDetail
    var scenes: PublicRouteScenes? = nil

    var version: PublicRouteVersionDetail { route.currentVersion }
    var summary: PublicRouteSummary { version.summary }
    var name: String { summary.name ?? "未命名路线" }
    var versionLabel: String? { version.versionLabel }
    var elevationProfile: RouteElevationProfilePresentation? {
        guard version.mainTrackAvailability == .valid,
              let profile = version.elevationProfile,
              !profile.samples.isEmpty else { return nil }
        return RouteElevationProfilePresentation(
            minElevation: profile.minElevation.meters,
            maxElevation: profile.maxElevation.meters,
            samples: profile.samples.enumerated().map { index, sample in
                RouteElevationSample(
                    sequenceNumber: index + 1,
                    distance: sample.distance.meters,
                    elevation: sample.elevation.meters
                )
            }
        )
    }
    var actionPolicy: RouteDetailActionPolicy { .init(shareText: name) }
    var generationAction: RouteGenerationActionPresentation {
        .init(
            title: "生成我的行程",
            isEnabled: version.generationEligibility.eligible,
            unavailableMessage: generationMessage
        )
    }

    var summaryTags: [String] {
        ([version.versionLabel, routeTypeText, summary.region, summary.difficulty, summary.direction]
            .compactMap(Self.nonEmpty) + (summary.tags ?? []) + [
                summary.maxElevation.map { "最高海拔 \(Self.meters($0.meters))" },
                summary.suggestedDays.map { "建议 \($0) 天" },
            ].compactMap { $0 })
    }

    var routeTypeText: String {
        switch summary.routeType {
        case .oneDay: "一日路线"
        case .multiDay: "多日路线"
        }
    }

    var endpointText: String? {
        guard let start = Self.nonEmpty(summary.start?.name),
              let end = Self.nonEmpty(summary.end?.name) else { return nil }
        return "\(start) → \(end)"
    }

    var summaryMetrics: [RouteSummaryMetric] {
        var metrics: [RouteSummaryMetric] = []
        if let distance = summary.distance {
            metrics.append(.init(title: "距离", value: Self.distance(distance.meters), systemImage: "point.topleft.down.curvedto.point.bottomright.up"))
        }
        if let duration = summary.estimatedDuration {
            metrics.append(.init(title: "预计用时", value: Self.duration(duration.seconds), systemImage: "clock"))
        }
        if let ascent = summary.ascent {
            metrics.append(.init(title: "累计爬升", value: Self.meters(ascent.meters), systemImage: "arrow.up.right"))
        }
        if let descent = summary.descent {
            metrics.append(.init(title: "累计下降", value: Self.meters(descent.meters), systemImage: "arrow.down.right"))
        }
        return metrics
    }

    var routeSummaryProjection: RouteSummaryProjection {
        RouteSummaryProjection(
            name: Self.nonEmpty(summary.name),
            introduction: Self.nonEmpty(summary.introduction),
            tags: summaryTags,
            metrics: summaryMetrics.map {
                MetricItemModel(id: $0.title, value: $0.value, label: $0.title)
            }
        )
    }

    var routeIntroductionProjection: RouteIntroductionProjection? {
        let values: [(String, String, String, QualifiedString?)] = [
            ("fitness-requirement", "体", "体能要求", version.professionalAnalysis?.fitnessRequirement),
            ("experience-requirement", "经", "经验要求", version.professionalAnalysis?.experienceRequirement),
            ("main-terrain", "地", "主要地形", version.professionalAnalysis?.mainTerrain),
            ("technical-difficulty", "技", "技术难点", version.professionalAnalysis?.technicalDifficulty),
            ("high-altitude-impact", "高", "高海拔影响", version.professionalAnalysis?.highAltitudeImpact),
            ("exposed-sections", "露", "暴露路段", version.professionalAnalysis?.exposedSections),
            ("danger-areas", "险", "危险区域", version.professionalAnalysis?.dangerAreas),
            ("signal-coverage", "信", "信号覆盖", version.professionalAnalysis?.signalCoverage),
            ("evacuation-difficulty", "撤", "撤离难度", version.professionalAnalysis?.evacuationDifficulty),
        ]
        let analysisItems: [RouteAnalysisItemProjection] = values.compactMap { value in
            guard let description = Self.nonEmpty(value.3?.value) else { return nil }
            return RouteAnalysisItemProjection(
                id: value.0,
                mark: value.1,
                title: value.2,
                description: description,
                confidence: value.3?.confidence
            )
        }
        let introduction = Self.nonEmpty(summary.introduction)
        guard introduction != nil || !analysisItems.isEmpty else { return nil }
        return RouteIntroductionProjection(
            introduction: introduction,
            analysisItems: analysisItems
        )
    }

    var elevationProfileProjection: ElevationProfileProjection? {
        guard version.mainTrackAvailability == .valid,
              let profile = version.elevationProfile,
              !profile.samples.isEmpty else { return nil }
        return ElevationProfileProjection(
            minimumLabel: Self.meters(profile.minElevation.meters),
            maximumLabel: Self.meters(profile.maxElevation.meters),
            minimumElevation: profile.minElevation.meters,
            maximumElevation: profile.maxElevation.meters,
            samples: profile.samples.map {
                RouteElevationSampleProjection(
                    id: $0.identity,
                    distance: $0.distance.meters,
                    elevation: $0.elevation.meters
                )
            }
        )
    }

    var referenceDayProjections: [RouteReferenceDayProjection] {
        guard summary.routeType == .multiDay else { return [] }
        return (version.referenceDays ?? []).map { day in
            var metrics: [String] = []
            if let endpoint = Self.endpoint(start: day.start?.name, end: day.end?.name) {
                metrics.append(endpoint)
            }
            if let distance = day.distance?.meters { metrics.append(Self.distance(distance)) }
            if let duration = day.estimatedDuration?.seconds { metrics.append(Self.duration(duration)) }
            if let ascent = day.ascent?.meters { metrics.append("爬升 \(Self.meters(ascent))") }
            if let descent = day.descent?.meters { metrics.append("下降 \(Self.meters(descent))") }
            if let minimum = day.minElevation?.meters { metrics.append("最低 \(Self.meters(minimum))") }
            if let maximum = day.maxElevation?.meters { metrics.append("最高 \(Self.meters(maximum))") }
            return RouteReferenceDayProjection(
                id: day.identity,
                dayNumber: day.dayNumber,
                title: Self.nonEmpty(day.title),
                metrics: metrics,
                description: Self.joined([day.accommodation, day.notes])
            )
        }
    }

    var routeSegmentListProjection: RouteSegmentListProjection? {
        let segments = (version.segments ?? []).map { segment in
            var metrics: [String] = []
            if let distance = segment.distance?.meters { metrics.append(Self.distance(distance)) }
            if let duration = segment.estimatedDuration?.seconds { metrics.append(Self.duration(duration)) }
            if let ascent = segment.ascent?.meters { metrics.append("爬升 \(Self.meters(ascent))") }
            if let descent = segment.descent?.meters { metrics.append("下降 \(Self.meters(descent))") }
            [segment.difficulty, segment.terrainOrRoadType]
                .compactMap(Self.nonEmpty)
                .forEach { metrics.append($0) }
            return RouteSegmentProjection(
                id: segment.identity,
                order: segment.order,
                name: segment.name,
                start: Self.nonEmpty(segment.start?.name),
                end: Self.nonEmpty(segment.end?.name),
                metrics: metrics,
                description: Self.joined([segment.description, segment.notes])
            )
        }
        guard !segments.isEmpty else { return nil }
        return RouteSegmentListProjection(segments: segments)
    }

    var routePointSectionProjections: [RoutePointSectionProjection] {
        let keyPoints = pointSection(
            title: "关键点",
            bookmark: "关",
            points: version.keyPoints ?? []
        )
        let interestPoints = pointSection(
            title: "兴趣点",
            bookmark: "景",
            points: version.interestPoints ?? []
        )
        let campsites = RoutePointSectionProjection(
            title: "营地",
            points: (version.campsites ?? []).map {
                RoutePointRowProjection(
                    id: $0.identity,
                    bookmark: "营",
                    name: $0.name,
                    elevation: $0.elevation.map { Self.meters($0.meters) },
                    type: Self.nonEmpty($0.status),
                    location: nil,
                    description: Self.nonEmpty($0.details)
                )
            }
        )
        let overnightPlaces = RoutePointSectionProjection(
            title: "过夜点",
            points: (version.overnightPlaces ?? []).map {
                RoutePointRowProjection(
                    id: $0.identity,
                    bookmark: "宿",
                    name: $0.name,
                    elevation: $0.elevation.map { Self.meters($0.meters) },
                    type: Self.nonEmpty($0.type),
                    location: nil,
                    description: Self.joined([
                        $0.facilities?.compactMap(Self.nonEmpty).joined(separator: "、"),
                        $0.details,
                        $0.status,
                    ])
                )
            }
        )
        let waterSources = RoutePointSectionProjection(
            title: "水源",
            points: (version.waterSources ?? []).map {
                RoutePointRowProjection(
                    id: $0.identity,
                    bookmark: "水",
                    name: $0.name,
                    elevation: $0.elevation.map { Self.meters($0.meters) },
                    type: Self.nonEmpty($0.sourceType),
                    location: nil,
                    description: Self.joined([
                        $0.seasonalReliability,
                        $0.treatmentRecommended.map { $0 ? "建议处理后饮用" : "未要求处理" },
                        $0.treatmentAdvice,
                        $0.description,
                    ])
                )
            }
        )
        let supplyPoints = RoutePointSectionProjection(
            title: "补给",
            points: (version.supplyPoints ?? []).map {
                RoutePointRowProjection(
                    id: $0.identity,
                    bookmark: "补",
                    name: $0.name,
                    elevation: nil,
                    type: Self.nonEmpty($0.supplyType),
                    location: nil,
                    description: Self.joined([
                        $0.availableItems?.compactMap(Self.nonEmpty).joined(separator: "、"),
                        $0.description,
                    ])
                )
            }
        )
        return [keyPoints, interestPoints, waterSources, supplyPoints, campsites, overnightPlaces]
            .filter { !$0.points.isEmpty }
    }

    /// 点位资料按途中要点与保障与住宿两个稳定分组呈现，组内类别顺序固定，
    /// 空类别整体省略，两组均空时不产生空分组（route-detail-point-presentation）。
    var routePointGroupProjections: [RoutePointGroupProjection] {
        let sectionsByTitle = Dictionary(uniqueKeysWithValues: routePointSectionProjections.map { ($0.title, $0) })
        let groupDefinitions: [(id: RoutePointGroupID, titles: [String])] = [
            (.journey, ["关键点", "兴趣点"]),
            (.support, ["水源", "补给", "营地", "过夜点"]),
        ]
        return groupDefinitions.compactMap { group in
            let sections = group.titles.compactMap { sectionsByTitle[$0] }
            return sections.isEmpty ? nil : RoutePointGroupProjection(id: group.id, sections: sections)
        }
    }

    var routeFactSectionProjections: [RouteFactSectionProjection] {
        [safetySection, seasonalWeatherSection, seasonalEquipmentSection]
            .filter { !$0.items.isEmpty }
            .map { section in
                RouteFactSectionProjection(
                    title: section.title,
                    items: section.items.map {
                        RouteFactItemProjection(
                            id: $0.id,
                            bookmark: $0.bookmark ?? "",
                            title: $0.title,
                            content: $0.value
                        )
                    }
                )
            }
    }

    var sections: [RouteDetailSectionPresentation] {
        var sections = [
            introductionAndAnalysisSection,
            professionalAnalysisSection,
            elevationSection,
            referenceDaysSection,
            segmentSection,
            namedPointSection(id: .keyPoints, title: "关键点", points: version.keyPoints ?? [], prefix: "关"),
            namedPointSection(id: .interestPoints, title: "兴趣点", points: version.interestPoints ?? [], prefix: "景"),
            campsiteSection,
            overnightPlaceSection,
            waterSourceSection,
            supplyPointSection,
            safetySection,
            seasonalWeatherSection,
            seasonalEquipmentSection,
            imageSection,
        ].filter { !$0.items.isEmpty }

        if let analysisIndex = sections.firstIndex(where: { $0.id == .professionalAnalysis }) {
            let analysisItems = sections.remove(at: analysisIndex).items
            if let overviewIndex = sections.firstIndex(where: { $0.id == .overview }) {
                sections[overviewIndex] = RouteDetailSectionPresentation(
                    id: .overview,
                    title: "路线介绍与专业分析",
                    items: sections[overviewIndex].items + analysisItems
                )
            } else {
                sections.insert(
                    RouteDetailSectionPresentation(
                        id: .overview,
                        title: "路线介绍与专业分析",
                        items: analysisItems
                    ),
                    at: 0
                )
            }
        }
        return sections
    }

    var images: [RouteDetailImagePresentation] {
        (version.images ?? []).map {
            RouteDetailImagePresentation(id: $0.identity, source: $0.mediaReference, caption: $0.caption)
        }
    }

    var sceneImages: [RouteDetailScenePresentation] {
        guard let scenes, scenes.isValid(routeID: route.routeId, routeVersionID: version.versionId,
                                        referenceDayIDs: Set((version.referenceDays ?? []).map(\.identity))) else { return [] }
        var artwork: [RouteDetailScenePresentation] = []
        if let overview = scenes.overview {
            artwork.append(.init(id: "scene-overview-\(overview.mediaID)", source: overview.imageURL, contextLabel: "全程 · AIGC 场景示意"))
        }
        for day in (version.referenceDays ?? []).sorted(by: { $0.dayNumber < $1.dayNumber }) {
            guard let image = scenes.days.first(where: { $0.referenceDayID == day.identity })?.image else { continue }
            artwork.append(.init(id: "scene-day-\(day.identity)", source: image.imageURL, contextLabel: "第\(day.dayNumber)天 · AIGC 场景示意"))
        }
        return artwork
    }

    var generationMessage: String? {
        RouteGenerationEligibilityPresentation(
            eligibility: version.generationEligibility
        ).unavailableMessage
    }

    private var introductionAndAnalysisSection: RouteDetailSectionPresentation {
        let items = Self.nonEmpty(summary.introduction).map {
            [RouteDetailSectionItem(id: "introduction", title: "路线介绍", value: $0)]
        } ?? []
        return .init(id: .overview, title: "路线介绍与专业分析", items: items)
    }

    private var elevationSection: RouteDetailSectionPresentation {
        guard version.mainTrackAvailability == .valid,
              let profile = version.elevationProfile,
              !profile.samples.isEmpty else {
            return .init(id: .elevation, title: "海拔曲线", items: [])
        }
        let range = "\(Self.meters(profile.minElevation.meters)) - \(Self.meters(profile.maxElevation.meters))"
        return .init(
            id: .elevation,
            title: "海拔曲线",
            items: [.init(id: "elevation-profile", title: range, value: "")]
        )
    }

    private var professionalAnalysisSection: RouteDetailSectionPresentation {
        guard let analysis = version.professionalAnalysis else {
            return .init(id: .professionalAnalysis, title: "路线介绍与专业分析", items: [])
        }
        let values: [(String, QualifiedString?)] = [
            ("体能要求", analysis.fitnessRequirement),
            ("经验要求", analysis.experienceRequirement),
            ("主要地形", analysis.mainTerrain),
            ("技术难点", analysis.technicalDifficulty),
            ("高海拔影响", analysis.highAltitudeImpact),
            ("暴露路段", analysis.exposedSections),
            ("危险区域", analysis.dangerAreas),
            ("信号覆盖", analysis.signalCoverage),
            ("撤离难度", analysis.evacuationDifficulty),
        ]
        return .init(
            id: .professionalAnalysis,
            title: "路线介绍与专业分析",
            items: values.compactMap { title, qualified in
                guard let value = Self.nonEmpty(qualified?.value) else { return nil }
                return .init(id: title, bookmark: "析", title: title, value: value)
            }
        )
    }

    private var referenceDaysSection: RouteDetailSectionPresentation {
        guard summary.routeType == .multiDay else {
            return .init(id: .referenceDays, title: "参考分日", items: [])
        }
        return .init(
            id: .referenceDays,
            title: "参考分日",
            items: (version.referenceDays ?? []).map { day in
                var facts = [day.start?.name, day.end?.name, day.accommodation, day.notes].compactMap(Self.nonEmpty)
                if let distance = day.distance?.meters { facts.append(Self.distance(distance)) }
                if let duration = day.estimatedDuration?.seconds { facts.append(Self.duration(duration)) }
                if let ascent = day.ascent?.meters { facts.append("爬升 \(Self.meters(ascent))") }
                if let descent = day.descent?.meters { facts.append("下降 \(Self.meters(descent))") }
                if let minimum = day.minElevation?.meters { facts.append("最低 \(Self.meters(minimum))") }
                if let maximum = day.maxElevation?.meters { facts.append("最高 \(Self.meters(maximum))") }
                return .init(
                    id: day.identity,
                    bookmark: "D\(day.dayNumber)",
                    title: day.title ?? "第 \(day.dayNumber) 天",
                    value: facts.joined(separator: " · ")
                )
            }
        )
    }

    private var segmentSection: RouteDetailSectionPresentation {
        let items = (version.segments ?? []).map { segment in
            var facts: [String] = []
            if let start = Self.nonEmpty(segment.start?.name), let end = Self.nonEmpty(segment.end?.name) {
                facts.append("\(start) → \(end)")
            }
            if let distance = segment.distance?.meters { facts.append(Self.distance(distance)) }
            if let duration = segment.estimatedDuration?.seconds { facts.append(Self.duration(duration)) }
            if let ascent = segment.ascent?.meters { facts.append("爬升 \(Self.meters(ascent))") }
            if let descent = segment.descent?.meters { facts.append("下降 \(Self.meters(descent))") }
            [segment.difficulty, segment.terrainOrRoadType, segment.description, segment.notes]
                .compactMap(Self.nonEmpty)
                .forEach { facts.append($0) }
            return RouteDetailSectionItem(
                id: segment.identity,
                bookmark: "S\(segment.order)",
                title: segment.name,
                value: facts.joined(separator: " · ")
            )
        }
        return .init(id: .segments, title: "路线分段", items: items)
    }

    private func namedPointSection(
        id: RouteDetailSectionID,
        title: String,
        points: [PublicRouteNamedPoint],
        prefix: String
    ) -> RouteDetailSectionPresentation {
        .init(id: id, title: title, items: pointItems(points, prefix: prefix))
    }

    private var campsiteSection: RouteDetailSectionPresentation {
        .init(id: .campsites, title: "营地", items: (version.campsites ?? []).map {
            pointItem(id: $0.identity, prefix: "营", name: $0.name, category: $0.status, detail: $0.details, elevation: $0.elevation?.meters)
        })
    }

    private var overnightPlaceSection: RouteDetailSectionPresentation {
        .init(id: .overnightPlaces, title: "过夜点", items: (version.overnightPlaces ?? []).map {
            pointItem(
                id: $0.identity,
                prefix: "宿",
                name: $0.name,
                category: $0.type,
                detail: [$0.facilities?.joined(separator: "、"), $0.details, $0.status].compactMap(Self.nonEmpty).joined(separator: " · "),
                elevation: $0.elevation?.meters
            )
        })
    }

    private var waterSourceSection: RouteDetailSectionPresentation {
        .init(id: .waterSources, title: "水源", items: (version.waterSources ?? []).map {
            pointItem(
                id: $0.identity,
                prefix: "水",
                name: $0.name,
                category: $0.sourceType,
                detail: [
                    $0.seasonalReliability,
                    $0.treatmentRecommended.map { $0 ? "建议处理后饮用" : "未要求处理" },
                    $0.treatmentAdvice,
                    $0.description,
                ].compactMap(Self.nonEmpty).joined(separator: " · "),
                elevation: $0.elevation?.meters
            )
        })
    }

    private var supplyPointSection: RouteDetailSectionPresentation {
        .init(id: .supplyPoints, title: "补给", items: (version.supplyPoints ?? []).map {
            pointItem(
                id: $0.identity,
                prefix: "补",
                name: $0.name,
                category: $0.supplyType,
                detail: [$0.availableItems?.joined(separator: "、"), $0.description]
                    .compactMap(Self.nonEmpty)
                    .joined(separator: " · "),
                elevation: nil
            )
        })
    }

    private var safetySection: RouteDetailSectionPresentation {
        var items: [RouteDetailSectionItem] = []
        if let coverage = Self.nonEmpty(version.communicationAndSafety?.coverageSummary) {
            items.append(.init(id: "coverage", bookmark: "信", title: "通信覆盖", value: coverage))
        }
        items.append(contentsOf: (version.communicationAndSafety?.notices ?? []).map {
            RouteDetailSectionItem(
                id: $0.identity,
                bookmark: Self.safetyBookmark(for: $0.kind),
                title: $0.title,
                value: [$0.kind, $0.description].compactMap(Self.nonEmpty).joined(separator: " · ")
            )
        })
        return .init(id: .safeguards, title: "通信与安全", items: items)
    }

    private var seasonalWeatherSection: RouteDetailSectionPresentation {
        guard let weather = version.seasonalWeather else {
            return .init(id: .seasonalWeather, title: "季节天气", items: [])
        }
        var items: [RouteDetailSectionItem] = []
        if let seasons = weather.bestSeasons, !seasons.isEmpty {
            items.append(.init(id: "best-seasons", bookmark: "季", title: "适合季节", value: seasons.joined(separator: "、")))
        }
        items.append(contentsOf: (weather.conditions ?? []).map {
            .init(
                id: $0.identity,
                bookmark: Self.seasonBookmark(for: $0.season),
                title: $0.season,
                value: [$0.typicalWeather, $0.environmentalRisks?.joined(separator: "、"), $0.notes]
                    .compactMap(Self.nonEmpty)
                    .joined(separator: " · ")
            )
        })
        return .init(id: .seasonalWeather, title: "季节天气", items: items)
    }

    private var seasonalEquipmentSection: RouteDetailSectionPresentation {
        .init(
            id: .seasonalEquipment,
            title: "季节装备",
            items: (version.seasonalEquipmentRecommendations ?? []).map {
                .init(
                    id: $0.identity,
                    bookmark: $0.level == .required ? "必" : "荐",
                    title: $0.name,
                    value: [$0.seasonOrCondition, $0.level == .required ? "必需" : "建议", $0.reason]
                        .compactMap(Self.nonEmpty)
                        .joined(separator: " · ")
                )
            }
        )
    }

    private var imageSection: RouteDetailSectionPresentation {
        .init(
            id: .imagery,
            title: "路线影像",
            items: images.map {
                .init(id: $0.id, title: $0.caption ?? "", value: $0.source)
            }
        )
    }

    private func pointSection(
        title: String,
        bookmark: String,
        points: [PublicRouteNamedPoint]
    ) -> RoutePointSectionProjection {
        RoutePointSectionProjection(
            title: title,
            points: points.map {
                RoutePointRowProjection(
                    id: $0.identity,
                    bookmark: bookmark,
                    name: $0.name,
                    elevation: $0.elevation.map { Self.meters($0.meters) },
                    type: Self.nonEmpty($0.category),
                    location: nil,
                    description: Self.nonEmpty($0.description)
                )
            }
        )
    }

    private func pointItems(_ points: [PublicRouteNamedPoint], prefix: String) -> [RouteDetailSectionItem] {
        points.map {
            pointItem(
                id: $0.identity,
                prefix: prefix,
                name: $0.name,
                category: $0.category,
                detail: $0.description,
                elevation: $0.elevation?.meters
            )
        }
    }

    private func pointItem(
        id: String,
        prefix: String,
        name: String,
        category: String?,
        detail: String?,
        elevation: Double?
    ) -> RouteDetailSectionItem {
        var facts = [category, detail].compactMap(Self.nonEmpty)
        if let elevation { facts.append(Self.meters(elevation)) }
        return .init(id: id, bookmark: prefix, title: name, value: facts.joined(separator: " · "))
    }

    private static func safetyBookmark(for value: String) -> String {
        if value.contains("信") { return "信" }
        if value.contains("撤") { return "撤" }
        if value.contains("险") || value.contains("危") { return "险" }
        return "安"
    }

    private static func seasonBookmark(for value: String) -> String {
        nonEmpty(value).map { String($0.prefix(1)) } ?? "季"
    }

    static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private static func joined(_ values: [String?]) -> String? {
        let values = values.compactMap(nonEmpty)
        return values.isEmpty ? nil : values.joined(separator: " · ")
    }

    static func endpoint(start: String?, end: String?) -> String? {
        let start = nonEmpty(start)
        let end = nonEmpty(end)
        if let start, let end { return "\(start) → \(end)" }
        return start ?? end
    }

    static func distance(_ meters: Double) -> String {
        if meters >= 1_000 {
            return "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
        }
        return Self.meters(meters)
    }

    static func meters(_ meters: Double) -> String {
        "\(meters.formatted(.number.precision(.fractionLength(0...1)))) m"
    }

    static func duration(_ seconds: Double) -> String {
        let hours = seconds / 3_600
        if hours >= 24 {
            return "\((hours / 24).formatted(.number.precision(.fractionLength(0...1)))) 天"
        }
        return "\(hours.formatted(.number.precision(.fractionLength(0...1)))) 小时"
    }
}

@MainActor
@Observable
final class RouteDetailViewModel {
    private(set) var state = RouteDetailState()

    var route: PublicRouteDetail? { state.route }
    var isLoading: Bool { state.isLoading }
    var errorMessage: String? { state.errorMessage }
    var selectedSegmentID: String? { state.selectedSegmentID }
    var highlightedPointIdentity: String? { state.highlightedPointIdentity }

    var highlightedAnnotationIDs: Set<String> {
        guard let identity = highlightedPointIdentity else { return [] }
        return Set(
            poiAnnotations.filter { $0.objectIdentity == identity }.map(\.id)
                + selectableTrackPoints.filter { $0.objectIdentity == identity }.map(\.id)
                + waypointAnnotations.filter { $0.objectIdentity == identity }.map(\.id)
        )
    }

    var presentation: RouteDetailPresentation? { route.map { .init(route: $0, scenes: state.scenes) } }
    var sceneRequestID: UUID? { isLoading || route == nil ? nil : state.sceneRequestID }
    var hasUnavailableTrack: Bool {
        guard let route else { return false }
        return route.currentVersion.mainTrackAvailability != .valid
    }
    var mapStartCoordinate: CLLocationCoordinate2D? {
        validCoordinate(route?.currentVersion.summary.start?.position?.coordinate)
    }
    var mapEndCoordinate: CLLocationCoordinate2D? {
        validCoordinate(route?.currentVersion.summary.end?.position?.coordinate)
    }
    var hasMissingTrack: Bool { hasUnavailableTrack }
    var selectableSegments: [RouteSelectableSegment] {
        guard let segments = route?.currentVersion.segments else { return [] }
        let selectableIDs = Set(mapSegments.map(\.id))
        return segments
            .filter { selectableIDs.contains($0.identity) }
            .map { .init(id: $0.identity, segment: $0, isSelected: $0.identity == selectedSegmentID) }
    }

    private let service: any RouteDetailServicing
    @ObservationIgnored private var loadGeneration = 0
    @ObservationIgnored private var sceneGeneration = 0

    init(service: any RouteDetailServicing) {
        self.service = service
    }

    func loadRoute(id: String) async {
        guard !Task.isCancelled else { return }
        loadGeneration += 1
        let generation = loadGeneration
        if state.routeID != id {
            state = RouteDetailState(routeID: id)
        }
        state.phase = .loading

        await withTaskCancellationHandler {
            do {
                let detail = try await service.getRouteDetail(id: id)
                guard generation == loadGeneration, state.routeID == id else { return }
                try Task.checkCancellation()
                let snapshot = try await Self.makeSnapshot(from: detail)
                guard generation == loadGeneration, state.routeID == id else { return }
                try Task.checkCancellation()
                state = RouteDetailState(routeID: id, snapshot: snapshot, phase: .ready)
            } catch {
                guard generation == loadGeneration, state.routeID == id else { return }
                if Task.isCancelled || error is CancellationError
                    || (error as? APIClientError) == .transport(.cancelled) {
                    cancelLoad(generation: generation, id: id)
                } else {
                    state.phase = .failed(Self.message(for: error))
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelLoad(generation: generation, id: id)
            }
        }
    }

    func retry() async {
        guard let routeID = state.routeID else { return }
        await loadRoute(id: routeID)
    }

    func refreshScenes() async {
        guard !Task.isCancelled, let batch = sceneRequestID, let route else { return }
        sceneGeneration += 1
        let generation = sceneGeneration
        do {
            let value = try await service.getRouteScenes(id: route.routeId, routeVersionID: route.currentVersion.versionId)
            guard !Task.isCancelled, generation == sceneGeneration, sceneRequestID == batch else { return }
            guard value.isValid(routeID: route.routeId, routeVersionID: route.currentVersion.versionId,
                                referenceDayIDs: Set((route.currentVersion.referenceDays ?? []).map(\.identity))) else {
                state.scenes = nil
                return
            }
            state.scenes = value
        } catch {
            guard !Task.isCancelled, generation == sceneGeneration, sceneRequestID == batch else { return }
            state.scenes = nil
        }
    }

    private func cancelLoad(generation: Int, id: String) {
        guard generation == loadGeneration, state.routeID == id, isLoading else { return }
        loadGeneration += 1
        state.phase = route == nil ? .idle : .ready
    }

    func canSelectSegment(_ id: String) -> Bool {
        mapSegments.contains(where: { $0.id == id })
    }

    func selectSegment(_ id: String) {
        guard canSelectSegment(id) else { return }
        state.selectedSegmentID = selectedSegmentID == id ? nil : id
    }

    func togglePointHighlight(for identity: String) {
        state.highlightedPointIdentity = highlightedPointIdentity == identity ? nil : identity
    }

    func highlightPoint(_ selection: RouteMapSelection) {
        state.highlightedPointIdentity = selection.identity
    }

    private func validCoordinate(_ coordinate: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        guard let coordinate, CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        return coordinate
    }

    // body 只读快照；选中/高亮变化不重新构造轨迹、标注或海拔数组。
    var mapCoordinates: [CLLocationCoordinate2D] { state.snapshot?.mapCoordinates ?? [] }
    var elevationSamples: [RouteElevationSample] { state.snapshot?.elevationSamples ?? [] }
    var elevationProfileProjection: ElevationProfileProjection? { state.snapshot?.elevationProfile }
    var mapSegments: [RouteMapSegment] { state.snapshot?.mapSegments ?? [] }
    var poiAnnotations: [RoutePOIAnnotation] { state.snapshot?.poiAnnotations ?? [] }
    var waypointAnnotations: [RouteWaypointAnnotation] { state.snapshot?.waypointAnnotations ?? [] }
    var selectableTrackPoints: [RouteTrackPointMetadata] { [] }

    /// Swift 5.9 nonisolated async 在 generic executor 执行，不继承调用方 MainActor。
    /// 每个被接受的响应构造一次，回到 MainActor 后再次校验代际才整体发布。
    nonisolated static func makeSnapshot(from detail: PublicRouteDetail) async throws -> RouteDetailSnapshot {
        try Task.checkCancellation()
        let version = detail.currentVersion
        let mainTrack = version.mainTrackAvailability == .valid ? version.mainTrack : nil
        let mapCoordinates = try (mainTrack?.path ?? []).compactMap { position -> CLLocationCoordinate2D? in
            try Task.checkCancellation()
            return CLLocationCoordinate2DIsValid(position.coordinate) ? position.coordinate : nil
        }
        var mapSegments: [RouteMapSegment] = []
        var coloredMapSegments: [RouteMapSegment] = []
        var dayMapSegments: [RouteMapSegment] = []
        if let mainTrack {
            for segment in version.segments ?? [] {
                try Task.checkCancellation()
                guard let range = segment.mainTrackRange,
                      let coordinates = Self.coordinates(in: range, path: mainTrack.path) else { continue }
                mapSegments.append(RouteMapSegment(
                    id: segment.identity, name: segment.name, colorHex: nil, coordinates: coordinates
                ))
                coloredMapSegments.append(RouteMapSegment(
                    id: segment.identity, name: segment.name,
                    colorHex: RouteDivisionPalette.hex(for: max(segment.order - 1, 0)), coordinates: coordinates
                ))
            }
            for day in version.referenceDays ?? [] {
                try Task.checkCancellation()
                guard let range = day.mainTrackRange,
                      let coordinates = Self.coordinates(in: range, path: mainTrack.path) else { continue }
                dayMapSegments.append(RouteMapSegment(
                    id: day.identity, name: day.title ?? "第 \(day.dayNumber) 天",
                    colorHex: RouteDivisionPalette.hex(for: max(day.dayNumber - 1, 0)), coordinates: coordinates
                ))
            }
        }
        try Task.checkCancellation()
        let poiAnnotations = annotatedPoints(version.interestPoints ?? [], fallbackCategory: "兴趣点")
            + annotatedCampsites(version.campsites ?? [])
            + annotatedOvernightPlaces(version.overnightPlaces ?? [])
            + annotatedWaterSources(version.waterSources ?? [])
            + annotatedSupplyPoints(version.supplyPoints ?? [])
        let waypointAnnotations = annotatedWaypoints(version.keyPoints ?? [])
        let presentation = RouteDetailPresentation(route: detail)
        let elevationSamples = mainTrack == nil ? [] : (presentation.elevationProfile?.samples ?? [])
        let elevationProfile = presentation.elevationProfileProjection
        try Task.checkCancellation()
        return RouteDetailSnapshot(
            route: detail, mapCoordinates: mapCoordinates, mapSegments: mapSegments,
            dayMapSegments: dayMapSegments, coloredMapSegments: coloredMapSegments,
            poiAnnotations: poiAnnotations, waypointAnnotations: waypointAnnotations,
            elevationSamples: elevationSamples, elevationProfile: elevationProfile
        )
    }

    nonisolated private static func annotatedPoints(_ points: [PublicRouteNamedPoint], fallbackCategory: String) -> [RoutePOIAnnotation] {
        points.flatMap { point in
            point.positions.compactMap { position in
                guard CLLocationCoordinate2DIsValid(position.coordinate) else { return nil }
                return .init(
                    id: "\(point.identity)-\(position.latitude)-\(position.longitude)",
                    objectIdentity: point.identity,
                    title: point.name,
                    category: point.category ?? fallbackCategory,
                    subCategory: "",
                    detail: point.description ?? "",
                    elevation: point.elevation.map { Self.formatElevation($0.meters) } ?? "",
                    imageURL: point.media?.first.flatMap(URL.init(string:)),
                    latitude: position.latitude,
                    longitude: position.longitude
                )
            }
        }
    }

    nonisolated private static func annotatedWaypoints(_ points: [PublicRouteNamedPoint]) -> [RouteWaypointAnnotation] {
        points.flatMap { point in
            point.positions.compactMap { position in
                guard CLLocationCoordinate2DIsValid(position.coordinate) else { return nil }
                return .init(
                    id: "\(point.identity)-\(position.latitude)-\(position.longitude)",
                    objectIdentity: point.identity,
                    title: point.name,
                    detail: point.description ?? "",
                    elevation: point.elevation.map { Self.formatElevation($0.meters) } ?? "",
                    type: point.category ?? "关键点",
                    imageURL: point.media?.first.flatMap(URL.init(string:)),
                    latitude: position.latitude,
                    longitude: position.longitude
                )
            }
        }
    }

    nonisolated private static func annotatedCampsites(_ campsites: [PublicRouteCampsite]) -> [RoutePOIAnnotation] {
        campsites.flatMap { campsite in
            campsite.positions.compactMap { position in
                guard CLLocationCoordinate2DIsValid(position.coordinate) else { return nil }
                return .init(
                    id: "\(campsite.identity)-\(position.latitude)-\(position.longitude)",
                    objectIdentity: campsite.identity,
                    title: campsite.name,
                    category: "营地",
                    subCategory: campsite.status ?? "",
                    detail: campsite.details ?? "",
                    elevation: campsite.elevation.map { Self.formatElevation($0.meters) } ?? "",
                    imageURL: nil,
                    latitude: position.latitude,
                    longitude: position.longitude
                )
            }
        }
    }

    nonisolated private static func annotatedOvernightPlaces(_ places: [PublicRouteOvernightPlace]) -> [RoutePOIAnnotation] {
        places.flatMap { place in
            place.positions.compactMap { position in
                guard CLLocationCoordinate2DIsValid(position.coordinate) else { return nil }
                return .init(
                    id: "\(place.identity)-\(position.latitude)-\(position.longitude)",
                    objectIdentity: place.identity,
                    title: place.name,
                    category: "过夜点",
                    subCategory: place.type ?? "",
                    detail: [place.facilities?.joined(separator: "、"), place.details, place.status]
                        .compactMap { value in
                            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                                  !value.isEmpty else { return nil }
                            return value
                        }
                        .joined(separator: " · "),
                    elevation: place.elevation.map { Self.formatElevation($0.meters) } ?? "",
                    imageURL: nil,
                    latitude: position.latitude,
                    longitude: position.longitude
                )
            }
        }
    }

    nonisolated private static func annotatedWaterSources(_ sources: [PublicRouteWaterSource]) -> [RoutePOIAnnotation] {
        sources.flatMap { source in
            source.positions.compactMap { position in
                guard CLLocationCoordinate2DIsValid(position.coordinate) else { return nil }
                return .init(
                    id: "\(source.identity)-\(position.latitude)-\(position.longitude)",
                    objectIdentity: source.identity,
                    title: source.name,
                    category: "水源",
                    subCategory: source.sourceType ?? "",
                    detail: source.description ?? "",
                    elevation: source.elevation.map { Self.formatElevation($0.meters) } ?? "",
                    imageURL: nil,
                    latitude: position.latitude,
                    longitude: position.longitude
                )
            }
        }
    }

    nonisolated private static func annotatedSupplyPoints(_ points: [PublicRouteSupplyPoint]) -> [RoutePOIAnnotation] {
        points.flatMap { point in
            point.positions.compactMap { position in
                guard CLLocationCoordinate2DIsValid(position.coordinate) else { return nil }
                return .init(
                    id: "\(point.identity)-\(position.latitude)-\(position.longitude)",
                    objectIdentity: point.identity,
                    title: point.name,
                    category: "补给",
                    subCategory: point.supplyType ?? "",
                    detail: point.description ?? "",
                    elevation: "",
                    imageURL: nil,
                    latitude: position.latitude,
                    longitude: position.longitude
                )
            }
        }
    }

    nonisolated private static func coordinates(
        in range: PublicRouteMainTrackRange,
        path: [PublicRouteGeoPosition]
    ) -> [CLLocationCoordinate2D]? {
        guard let start = coordinate(at: range.startPathPosition, path: path),
              let end = coordinate(at: range.endPathPosition, path: path) else {
            return nil
        }
        let startIndex = range.startPathPosition.precedingPositionIndex
        let endIndex = range.endPathPosition.precedingPositionIndex
        let startProgress = range.startPathPosition.progressToNextPosition ?? 0
        let endProgress = range.endPathPosition.progressToNextPosition ?? 0
        guard startIndex < endIndex || (startIndex == endIndex && startProgress < endProgress) else {
            return nil
        }

        var result = [start]
        let firstWholeIndex = startProgress == 0 ? startIndex + 1 : startIndex + 1
        if firstWholeIndex <= endIndex {
            for index in firstWholeIndex...endIndex where index < path.count {
                let point = path[index].coordinate
                if CLLocationCoordinate2DIsValid(point), !sameCoordinate(result.last, point) {
                    result.append(point)
                }
            }
        }
        if !sameCoordinate(result.last, end) { result.append(end) }
        return result.count >= 2 ? result : nil
    }

    nonisolated private static func coordinate(
        at position: PublicRoutePathPosition,
        path: [PublicRouteGeoPosition]
    ) -> CLLocationCoordinate2D? {
        let index = position.precedingPositionIndex
        guard path.indices.contains(index) else { return nil }
        let progress = position.progressToNextPosition
        if index == path.count - 1 {
            guard progress == nil else { return nil }
            return path[index].coordinate
        }
        guard let progress, progress >= 0, progress < 1 else { return nil }
        let start = path[index]
        let end = path[index + 1]
        let coordinate = CLLocationCoordinate2D(
            latitude: start.latitude + (end.latitude - start.latitude) * progress,
            longitude: start.longitude + (end.longitude - start.longitude) * progress
        )
        return CLLocationCoordinate2DIsValid(coordinate) ? coordinate : nil
    }

    nonisolated private static func sameCoordinate(_ left: CLLocationCoordinate2D?, _ right: CLLocationCoordinate2D) -> Bool {
        guard let left else { return false }
        return left.latitude == right.latitude && left.longitude == right.longitude
    }

    nonisolated private static func formatElevation(_ meters: Double) -> String {
        "\(meters.formatted(.number.precision(.fractionLength(0...1)))) m"
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}

// MARK: - 纯地图模式（route-detail-map-mode）划分投影

extension RouteDetailViewModel {
    private var validMainTrack: PublicRouteMainTrack? {
        guard route?.currentVersion.mainTrackAvailability == .valid else { return nil }
        return route?.currentVersion.mainTrack
    }

    /// 主轨迹可用时才提供纯地图状态。
    var pureMapAvailable: Bool { validMainTrack != nil }

    /// 范围 → 全程累计距离区间。仅当海拔剖面采样数与主轨迹 path 位置数一一对应时成立，
    /// 否则返回 nil（该划分不提供曲线区间与位置行，不做任何推断）。
    private func cumulativeDistances(for range: PublicRouteMainTrackRange) -> (start: Double, end: Double)? {
        guard let mainTrack = validMainTrack,
              let profile = state.snapshot?.elevationProfile,
              profile.samples.count == mainTrack.path.count else { return nil }
        let samples = profile.samples

        func distance(at position: PublicRoutePathPosition) -> Double? {
            let index = position.precedingPositionIndex
            guard samples.indices.contains(index) else { return nil }
            let base = samples[index].distance
            if index == samples.count - 1 {
                return position.progressToNextPosition == nil ? base : nil
            }
            guard let progress = position.progressToNextPosition, progress >= 0, progress < 1 else { return nil }
            return base + (samples[index + 1].distance - base) * progress
        }

        guard let start = distance(at: range.startPathPosition),
              let end = distance(at: range.endPathPosition),
              end > start else { return nil }
        return (start, end)
    }

    func pureMapSpans(for division: RouteDivisionKind) -> [RouteDivisionSpanProjection] {
        switch division {
        case .day:
            guard presentation?.summary.routeType == .multiDay else { return [] }
            return (route?.currentVersion.referenceDays ?? []).map { day in
                let distances = day.mainTrackRange.flatMap { cumulativeDistances(for: $0) }
                return RouteDivisionSpanProjection(
                    id: day.identity,
                    label: "D\(day.dayNumber)",
                    title: day.title,
                    colorHex: RouteDivisionPalette.hex(for: max(day.dayNumber - 1, 0)),
                    startDistance: distances?.start,
                    endDistance: distances?.end
                )
            }
        case .segment:
            return (route?.currentVersion.segments ?? []).map { segment in
                let distances = segment.mainTrackRange.flatMap { cumulativeDistances(for: $0) }
                return RouteDivisionSpanProjection(
                    id: segment.identity,
                    label: "S\(segment.order)",
                    title: segment.name,
                    colorHex: RouteDivisionPalette.hex(for: max(segment.order - 1, 0)),
                    startDistance: distances?.start,
                    endDistance: distances?.end
                )
            }
        }
    }

    var pureMapDockProjection: RouteMapDockProjection {
        RouteMapDockProjection(
            elevation: state.snapshot?.elevationProfile,
            daySpans: pureMapSpans(for: .day),
            segmentSpans: pureMapSpans(for: .segment)
        )
    }

    /// 纯地图轨迹划分着色：只着色具有可靠范围事实的区间，缺失区间不着色划界。
    func divisionMapSegments(for division: RouteDivisionKind) -> [RouteMapSegment] {
        switch division {
        case .day: state.snapshot?.dayMapSegments ?? []
        case .segment: state.snapshot?.coloredMapSegments ?? []
        }
    }

    /// 划分徽标：位于对应范围起点，供地图层发出 selectSpan。
    func divisionBadges(for division: RouteDivisionKind) -> [RouteDivisionBadgeProjection] {
        guard let mainTrack = validMainTrack else { return [] }

        func badge(spanID: String, label: String, colorHex: String, range: PublicRouteMainTrackRange?) -> RouteDivisionBadgeProjection? {
            guard let range,
                  let coordinate = Self.coordinate(at: range.startPathPosition, path: mainTrack.path) else { return nil }
            return RouteDivisionBadgeProjection(spanID: spanID, label: label, colorHex: colorHex, coordinate: coordinate)
        }

        switch division {
        case .day:
            return (route?.currentVersion.referenceDays ?? []).compactMap { day in
                badge(
                    spanID: day.identity,
                    label: "D\(day.dayNumber)",
                    colorHex: RouteDivisionPalette.hex(for: max(day.dayNumber - 1, 0)),
                    range: day.mainTrackRange
                )
            }
        case .segment:
            return (route?.currentVersion.segments ?? []).compactMap { segment in
                badge(
                    spanID: segment.identity,
                    label: "S\(segment.order)",
                    colorHex: RouteDivisionPalette.hex(for: max(segment.order - 1, 0)),
                    range: segment.mainTrackRange
                )
            }
        }
    }

    /// 曲线滑动定位 → 主轨迹沿线坐标。
    func pathCoordinate(at position: PublicRoutePathPosition) -> CLLocationCoordinate2D? {
        guard let mainTrack = validMainTrack else { return nil }
        return Self.coordinate(at: position, path: mainTrack.path)
    }

    func spanCardProjection(spanID: String, division: RouteDivisionKind) -> RouteSpanCardProjection? {
        switch division {
        case .day:
            guard presentation?.summary.routeType == .multiDay,
                  let day = (route?.currentVersion.referenceDays ?? []).first(where: { $0.identity == spanID }) else {
                return nil
            }
            return daySpanCardProjection(day)
        case .segment:
            guard let segment = (route?.currentVersion.segments ?? []).first(where: { $0.identity == spanID }) else {
                return nil
            }
            return segmentSpanCardProjection(segment)
        }
    }

    private func daySpanCardProjection(_ day: PublicRouteReferenceDay) -> RouteSpanCardProjection {
        var metrics: [RouteSpanMetricProjection] = []
        if let distance = day.distance?.meters {
            metrics.append(RouteSpanMetricProjection(label: "里程", value: RouteDetailPresentation.distance(distance)))
        }
        if let ascent = day.ascent?.meters {
            metrics.append(RouteSpanMetricProjection(label: "累计爬升", value: "+\(RouteDetailPresentation.meters(ascent))", isEmphasized: true))
        }
        if let descent = day.descent?.meters {
            metrics.append(RouteSpanMetricProjection(label: "累计下降", value: "-\(RouteDetailPresentation.meters(descent))", isEmphasized: true))
        }
        // 最高与最低海拔同时缺失时该两项一并省略。
        if let maximum = day.maxElevation?.meters, let minimum = day.minElevation?.meters {
            metrics.append(RouteSpanMetricProjection(label: "最高海拔", value: RouteDetailPresentation.meters(maximum)))
            metrics.append(RouteSpanMetricProjection(label: "最低海拔", value: RouteDetailPresentation.meters(minimum)))
        }

        var position: String?
        var duration: String?
        if let range = day.mainTrackRange, let distances = cumulativeDistances(for: range) {
            position = "全程 \(RouteDetailPresentation.distance(distances.start)) – \(RouteDetailPresentation.distance(distances.end))"
        }
        if let estimatedDuration = day.estimatedDuration?.seconds {
            duration = "参考用时 \(RouteDetailPresentation.duration(estimatedDuration))"
        }

        return RouteSpanCardProjection(
            spanID: day.identity,
            kind: .day(number: day.dayNumber),
            colorHex: RouteDivisionPalette.hex(for: max(day.dayNumber - 1, 0)),
            headerTitle: "D\(day.dayNumber) · \(day.title ?? "第 \(day.dayNumber) 天")",
            metrics: metrics,
            endpoints: RouteDetailPresentation.endpoint(start: day.start?.name, end: day.end?.name),
            position: position,
            duration: duration,
            lifecycle: day.accommodation.flatMap(RouteDetailPresentation.nonEmpty).map { "住宿：\($0)" },
            trait: nil,
            caution: day.notes.flatMap(RouteDetailPresentation.nonEmpty)
        )
    }

    private func segmentSpanCardProjection(_ segment: PublicRouteSegment) -> RouteSpanCardProjection {
        var metrics: [RouteSpanMetricProjection] = []
        if let distance = segment.distance?.meters {
            metrics.append(RouteSpanMetricProjection(label: "里程", value: RouteDetailPresentation.distance(distance)))
        }
        if let ascent = segment.ascent?.meters {
            metrics.append(RouteSpanMetricProjection(label: "累计爬升", value: "+\(RouteDetailPresentation.meters(ascent))", isEmphasized: true))
        }
        if let descent = segment.descent?.meters {
            metrics.append(RouteSpanMetricProjection(label: "累计下降", value: "-\(RouteDetailPresentation.meters(descent))", isEmphasized: true))
        }

        var position: String?
        var duration: String?
        if let range = segment.mainTrackRange, let distances = cumulativeDistances(for: range) {
            position = "全程 \(RouteDetailPresentation.distance(distances.start)) – \(RouteDetailPresentation.distance(distances.end))"
        }
        if let estimatedDuration = segment.estimatedDuration?.seconds {
            duration = "徒步参考时长 \(RouteDetailPresentation.duration(estimatedDuration))"
        }

        let trait = [segment.difficulty.map { "难度：\($0)" }, segment.terrainOrRoadType.map { "地形：\($0)" }]
            .compactMap { $0.flatMap(RouteDetailPresentation.nonEmpty) }
            .joined(separator: " · ")

        return RouteSpanCardProjection(
            spanID: segment.identity,
            kind: .segment(order: segment.order),
            colorHex: RouteDivisionPalette.hex(for: max(segment.order - 1, 0)),
            headerTitle: "S\(segment.order) · \(segment.name)",
            metrics: metrics,
            endpoints: RouteDetailPresentation.endpoint(start: segment.start?.name, end: segment.end?.name),
            position: position,
            duration: duration,
            lifecycle: nil,
            trait: trait.isEmpty ? nil : trait,
            caution: segment.notes.flatMap(RouteDetailPresentation.nonEmpty)
        )
    }
}

private extension PublicRouteGeoPosition {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
