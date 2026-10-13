import Foundation
import WalkData

/// TripDayArrangement 内的只读字段切片，不提供路线推断或字段互补。
struct TripRouteGuideFieldProjection: Equatable, Identifiable {
    let id: String
    let title: String
    let value: String?
    let notices: [String]
    let source: String?
    let category: String?
    let updatedAt: String?
    let scopeNote: String?

    init(id: String, title: String, value: String?, confidence: InformationConfidence?, scopeNote: String? = nil) {
        self.id = id
        self.title = title
        self.value = tripNonEmpty(value)
        self.notices = confidence.map { [TripContentNotice(field: title, status: $0.status).message] } ?? []
        self.source = tripNonEmpty(confidence?.source)
        self.updatedAt = confidence?.updatedAt?.description
        self.scopeNote = scopeNote
        self.category = confidence?.category.map {
            switch $0 {
            case .publicRouteFact: "路线参考资料"
            case .dynamicExternalInformation: "外部动态信息"
            case .generatedSuggestion: "生成建议"
            }
        }
    }
}

struct TripRouteGuideProjection: Equatable {
    let fields: [TripRouteGuideFieldProjection]

    init(guide: PersonalTripRouteGuide) {
        var fields: [TripRouteGuideFieldProjection] = []
        if let title = guide.title, tripNonEmpty(title.value) != nil || title.confidence != nil {
            fields.append(.init(id: "title", title: "参考走法", value: title.value, confidence: title.confidence))
        }
        for (id, title, place) in [("start", "参考起点", guide.start), ("end", "参考终点", guide.end)] {
            guard let place, tripNonEmpty(place.value?.name) != nil || place.confidence != nil else { continue }
            fields.append(.init(id: id, title: title, value: place.value?.name, confidence: place.confidence))
        }
        for (id, title, qualified) in [
            ("description", "参考说明", guide.description),
            ("notes", "注意事项", guide.notes),
            ("accommodation", "住宿参考", guide.accommodationReference),
        ] {
            guard let qualified, tripNonEmpty(qualified.value) != nil || qualified.confidence != nil else { continue }
            fields.append(.init(id: id, title: title, value: qualified.value, confidence: qualified.confidence))
        }
        if let track = guide.referenceTrack {
            let metrics = [
                track.distance.map { "距离 \(Self.distance($0.meters))" },
                track.ascent.map { "爬升 \(Self.number($0.meters)) m" },
                track.descent.map { "下降 \(Self.number($0.meters)) m" },
                track.estimatedDuration.map { "预计行进 \(Self.number($0.seconds / 3_600)) 小时" },
            ].compactMap { $0 }
            let path = track.path == nil ? "参考轨迹范围尚未确认" : "参考轨迹已提供"
            let profile = track.elevationProfile == nil ? nil : "参考海拔剖面已提供"
            let text = ([tripNonEmpty(metrics.joined(separator: " · "))].compactMap { $0 } + [path] + [profile].compactMap { $0 })
                .joined(separator: "\n")
            fields.append(.init(id: "reference-track", title: "参考日行进", value: text, confidence: track.confidence,
                                scopeNote: "参考行进可能包含接驳等活动，不等同于实际徒步指标。"))
        }
        self.fields = fields
    }

    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    private static func distance(_ meters: Double) -> String {
        meters >= 1_000 ? "\(number(meters / 1_000)) km" : "\(number(meters)) m"
    }
}
