import SwiftUI
import CoreLocation

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

struct RouteDetailActionPolicy: Equatable {
    let shareText: String
    let usesSystemShareSheet = true
}

struct RouteGenerationActionPresentation: Equatable {
    let title: String
    let isEnabled: Bool
    let unavailableMessage: String?
}

struct RouteGenerationEligibilityPresentation: Equatable {
    let unavailableMessage: String?

    init(eligibility: RouteGenerationEligibility) {
        guard !eligibility.eligible else {
            unavailableMessage = nil
            return
        }
        let labels = (eligibility.missingReasons ?? []).map { reason in
            switch reason {
            case .name: "路线名称"
            case .region: "所在地区"
            case .estimatedDuration: "预计用时"
            case .start: "起点"
            case .end: "终点"
            case .validMainTrack: "有效主轨迹"
            }
        }
        unavailableMessage = labels.isEmpty
            ? "当前路线资料不足，暂不能生成行程"
            : "缺少：\(labels.joined(separator: "、"))"
    }
}

struct RouteDetailPresentation: Equatable {
    let route: PublicRouteDetail

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
            start: Self.nonEmpty(summary.start?.name),
            end: Self.nonEmpty(summary.end?.name),
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
        return [keyPoints, interestPoints, campsites, overnightPlaces, waterSources, supplyPoints]
            .filter { !$0.points.isEmpty }
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
            .init(id: $0.identity, source: $0.mediaReference, caption: $0.caption)
        }
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
        guard let profile = elevationProfile else {
            return .init(id: .elevation, title: "海拔曲线", items: [])
        }
        let range = "\(Self.meters(profile.minElevation)) - \(Self.meters(profile.maxElevation))"
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
                .init(id: $0.id, title: $0.caption ?? "路线图片", value: $0.source)
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

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private static func joined(_ values: [String?]) -> String? {
        let values = values.compactMap(nonEmpty)
        return values.isEmpty ? nil : values.joined(separator: " · ")
    }

    private static func endpoint(start: String?, end: String?) -> String? {
        let start = nonEmpty(start)
        let end = nonEmpty(end)
        if let start, let end { return "\(start) → \(end)" }
        return start ?? end
    }

    private static func distance(_ meters: Double) -> String {
        if meters >= 1_000 {
            return "\((meters / 1_000).formatted(.number.precision(.fractionLength(0...1)))) km"
        }
        return Self.meters(meters)
    }

    private static func meters(_ meters: Double) -> String {
        "\(meters.formatted(.number.precision(.fractionLength(0...1)))) m"
    }

    private static func duration(_ seconds: Double) -> String {
        let hours = seconds / 3_600
        if hours >= 24 {
            return "\((hours / 24).formatted(.number.precision(.fractionLength(0...1)))) 天"
        }
        return "\(hours.formatted(.number.precision(.fractionLength(0...1)))) 小时"
    }
}

@MainActor
final class RouteDetailViewModel: ObservableObject {
    @Published private(set) var route: PublicRouteDetail?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var mapCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var poiAnnotations: [RoutePOIAnnotation] = []
    @Published private(set) var selectableTrackPoints: [RouteTrackPointMetadata] = []
    @Published private(set) var waypointAnnotations: [RouteWaypointAnnotation] = []
    @Published private(set) var mapSegments: [RouteMapSegment] = []
    @Published private(set) var elevationSamples: [RouteElevationSample] = []
    @Published private(set) var selectedSegmentID: String?
    @Published private(set) var highlightedPointIdentity: String?

    var highlightedAnnotationIDs: Set<String> {
        guard let identity = highlightedPointIdentity else { return [] }
        return Set(
            poiAnnotations.filter { $0.objectIdentity == identity }.map(\.id)
                + selectableTrackPoints.filter { $0.objectIdentity == identity }.map(\.id)
                + waypointAnnotations.filter { $0.objectIdentity == identity }.map(\.id)
        )
    }

    var presentation: RouteDetailPresentation? { route.map(RouteDetailPresentation.init) }
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
            let detail = try await service.getRouteDetail(id: id)
            route = detail
            projectMapData(from: detail)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func retry() async {
        guard let routeID else { return }
        await loadRoute(id: routeID)
    }

    func canSelectSegment(_ id: String) -> Bool {
        mapSegments.contains(where: { $0.id == id })
    }

    func selectSegment(_ id: String) {
        guard canSelectSegment(id) else { return }
        selectedSegmentID = selectedSegmentID == id ? nil : id
    }

    func togglePointHighlight(for identity: String) {
        highlightedPointIdentity = highlightedPointIdentity == identity ? nil : identity
    }

    func highlightPoint(_ selection: RouteMapSelection) {
        highlightedPointIdentity = selection.identity
    }

    private func validCoordinate(_ coordinate: CLLocationCoordinate2D?) -> CLLocationCoordinate2D? {
        guard let coordinate, CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        return coordinate
    }

    private func projectMapData(from detail: PublicRouteDetail) {
        let version = detail.currentVersion
        highlightedPointIdentity = nil
        selectedSegmentID = nil
        projectPoints(from: version)

        guard version.mainTrackAvailability == .valid, let mainTrack = version.mainTrack else {
            mapCoordinates = []
            mapSegments = []
            elevationSamples = []
            return
        }

        elevationSamples = (version.elevationProfile?.samples ?? []).enumerated().map { index, sample in
            RouteElevationSample(
                sequenceNumber: index + 1,
                distance: sample.distance.meters,
                elevation: sample.elevation.meters
            )
        }
        mapCoordinates = mainTrack.path
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            .filter(CLLocationCoordinate2DIsValid)
        mapSegments = (version.segments ?? []).compactMap { segment in
            guard let range = segment.mainTrackRange,
                  let coordinates = Self.coordinates(in: range, path: mainTrack.path) else {
                return nil
            }
            return RouteMapSegment(
                id: segment.identity,
                name: segment.name,
                colorHex: nil,
                coordinates: coordinates
            )
        }
    }

    private func projectPoints(from version: PublicRouteVersionDetail) {
        poiAnnotations = annotatedPoints(version.interestPoints ?? [], fallbackCategory: "兴趣点")
            + annotatedCampsites(version.campsites ?? [])
            + annotatedOvernightPlaces(version.overnightPlaces ?? [])
            + annotatedWaterSources(version.waterSources ?? [])
            + annotatedSupplyPoints(version.supplyPoints ?? [])
        waypointAnnotations = annotatedWaypoints(version.keyPoints ?? [])
        selectableTrackPoints = []
    }

    private func annotatedPoints(_ points: [PublicRouteNamedPoint], fallbackCategory: String) -> [RoutePOIAnnotation] {
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

    private func annotatedWaypoints(_ points: [PublicRouteNamedPoint]) -> [RouteWaypointAnnotation] {
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

    private func annotatedCampsites(_ campsites: [PublicRouteCampsite]) -> [RoutePOIAnnotation] {
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

    private func annotatedOvernightPlaces(_ places: [PublicRouteOvernightPlace]) -> [RoutePOIAnnotation] {
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

    private func annotatedWaterSources(_ sources: [PublicRouteWaterSource]) -> [RoutePOIAnnotation] {
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

    private func annotatedSupplyPoints(_ points: [PublicRouteSupplyPoint]) -> [RoutePOIAnnotation] {
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

    private static func coordinates(
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

    private static func coordinate(
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

    private static func sameCoordinate(_ left: CLLocationCoordinate2D?, _ right: CLLocationCoordinate2D) -> Bool {
        guard let left else { return false }
        return left.latitude == right.latitude && left.longitude == right.longitude
    }

    private static func formatElevation(_ meters: Double) -> String {
        "\(meters.formatted(.number.precision(.fractionLength(0...1)))) m"
    }

    private static func message(for error: Error) -> String {
        if let error = error as? LocalizedError, let description = error.errorDescription {
            return description
        }
        return "加载失败：\(error.localizedDescription)"
    }
}

private extension PublicRouteGeoPosition {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
