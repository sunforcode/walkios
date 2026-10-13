import SwiftUI
import WalkData
import WalkDesignSystem

/// 自然日去程或返程大交通与路线接驳摘要。
struct TripDayTransportSummaryProjection: Equatable {
    enum Direction: Equatable {
        case outbound
        case `return`
    }

    let direction: Direction
    let title: String
    var timeRange: String?
    var duration: String?
    var path: String?
    var modes: String?
    var notice: String?

    var isUnavailable: Bool {
        path == nil && timeRange == nil && duration == nil && modes == nil
    }

    var fallbackTitle: String {
        direction == .outbound ? "大交通与路线接驳" : "返程接驳与大交通"
    }
}

/// 徒步段节点：起点、终点或上游徒步段节点合同定义的有序节点。
struct TripDayHikeNodeProjection: Equatable {
    let type: String
    var name: String?
    var position: String?
}

/// 徒步段摘要：段落、距离、爬升、用时与有序节点。
struct TripDayHikeSummaryProjection: Equatable {
    let segment: String
    var distance: String?
    var ascent: String?
    var duration: String?
    var nodes: [TripDayHikeNodeProjection]

    var metricsText: String? {
        tripNonEmpty([
            tripNonEmpty(distance),
            ascent.map { "爬升 \($0)" },
            tripNonEmpty(duration),
        ].compactMap { $0 }.joined(separator: " · "))
    }
}

/// 自然日内容块：浏览页在块边界把一个自然日拆为一个或多个连续分页，
/// 组件不感知页边界，只按固定顺序渲染给定的块切片。
enum TripDayContentBlock: Equatable {
    /// 去程或返程交通块，附同方向交通行动的补充说明与提示。
    case transport(TripDayTransportSummaryProjection, details: [TripTimelineItemProjection])
    /// 徒步块：段落摘要 + 行动说明 + 有序节点 + 沿途点位。
    case hike(
        TripDayHikeSummaryProjection,
        details: [TripTimelineItemProjection],
        points: [TripPointProjection]
    )
    /// 当日天气块。
    case weather(TripWeatherProjection)
    /// 已采纳参考日的冻结说明和参考行进数据，与实际徒步块分开。
    case routeGuide(TripRouteGuideProjection)
}

struct TripDayArrangementProjection: Equatable {
    let blocks: [TripDayContentBlock]
}

extension TripBusinessComponents {
    /// 业务组合 TripDayArrangement（L2c）：完整承载一个自然日的全部内容，
    /// 以独立信息块纵向排列；所属浏览页在块边界切片，组件内不建立滚动层。
    /// 合同见 docs/ui/components/business/composites/trip-day-arrangement/spec.md。
    struct TripDayArrangement: View {
        let projection: TripDayArrangementProjection
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(Array(projection.blocks.enumerated()), id: \.offset) { _, block in
                    blockCard(block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        @ViewBuilder
        private func blockCard(_ block: TripDayContentBlock) -> some View {
            WalkPanel(variant: .default) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    switch block {
                    case let .transport(transport, details):
                        TripBusinessComponents.transportBlock(transport)
                        detailRows(details)
                    case let .hike(hike, details, points):
                        TripBusinessComponents.hikeSummaryBlock(hike)
                        detailRows(details)
                        if !hike.nodes.isEmpty {
                            nodeRows(hike.nodes)
                        }
                        if !points.isEmpty {
                            pointRows(points)
                        }
                    case let .weather(weather):
                        TripBusinessComponents.weatherFieldsBlock(weather)
                    case let .routeGuide(guide):
                        routeGuide(guide)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        @ViewBuilder
        private func detailRows(_ details: [TripTimelineItemProjection]) -> some View {
            let rows = details.flatMap { item in
                item.details.map { (item.id, $0) }
            }
            let notices = details.flatMap { item in item.notices.map { (item.id, $0) } }
            if !rows.isEmpty || !notices.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Text(row.1)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(notices.enumerated()), id: \.offset) { _, notice in
                        NoticeView(message: notice.1, tone: .warning)
                    }
                }
            }
        }

        private func routeGuide(_ guide: TripRouteGuideProjection) -> some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("路线参考")
                    .font(dynamicTypeSize.isAccessibilitySize ? .headline : .listTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                ForEach(guide.fields) { field in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(field.title)
                            .font(guideBodyFont.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                        if let scopeNote = field.scopeNote {
                            Text(scopeNote)
                                .font(guideBodyFont)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        if let value = field.value {
                            Text(value)
                                .font(guideBodyFont)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        ForEach(Array(field.notices.enumerated()), id: \.offset) { _, notice in
                            Text(notice)
                                .font(guideBodyFont)
                                .foregroundStyle(AppColors.warning)
                        }
                        if let category = field.category {
                            Text(category).font(guideMetadataFont).foregroundStyle(AppColors.textWeak)
                        }
                        if let source = field.source {
                            Text("来源：\(source)").font(guideMetadataFont).foregroundStyle(AppColors.textWeak)
                        }
                        if let updatedAt = field.updatedAt {
                            Text("资料时间：\(updatedAt)").font(guideMetadataFont).foregroundStyle(AppColors.textWeak)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
            .accessibilityIdentifier("trip-route-guide")
        }

        private var guideBodyFont: Font { dynamicTypeSize.isAccessibilitySize ? .body : .appCaption }
        private var guideMetadataFont: Font { dynamicTypeSize.isAccessibilitySize ? .caption : .micro }

        private func nodeRows(_ nodes: [TripDayHikeNodeProjection]) -> some View {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { _, node in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                        Text(node.type)
                            .font(.appCaption.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text([
                            tripNonEmpty(node.name),
                            tripNonEmpty(node.position),
                        ].compactMap { $0 }.joined(separator: " · "))
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }

        private func pointRows(_ points: [TripPointProjection]) -> some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("沿途点位")
                    .font(.microStrong)
                    .foregroundStyle(AppColors.textWeak)
                ForEach(points) { point in
                    HStack(alignment: .top, spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(point.title)
                                .font(.listTitle)
                                .foregroundStyle(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(Array(point.details.enumerated()), id: \.offset) { _, detail in
                                Text(detail)
                                    .font(.appCaption)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        if let trailing = tripNonEmpty(point.trailing) {
                            Text(trailing)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textWeak)
                        }
                    }
                }
            }
        }
    }

    /// 交通块：标题 + 摘要行 + 补充 chips；不可用时保留块并显示「暂不可用」。
    static func transportBlock(_ projection: TripDayTransportSummaryProjection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text(tripNonEmpty(projection.title) ?? projection.fallbackTitle)
                    .font(.listTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if projection.isUnavailable {
                    Text("暂不可用")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textWeak)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text([
                        tripNonEmpty(projection.timeRange),
                        tripNonEmpty(projection.duration),
                    ].compactMap { $0 }.joined(separator: " · "))
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textWeak)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if projection.isUnavailable {
                Text("不会补造班次、时间或完整衔接方案，请在出发前自行核验。")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                if let path = tripNonEmpty(projection.path) {
                    Text(path)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let modes = tripNonEmpty(projection.modes)
                let notice = tripNonEmpty(projection.notice)
                if modes != nil || notice != nil {
                    HStack(spacing: Spacing.xs) {
                        if let modes {
                            InfoTag(title: modes, tone: .neutral)
                        }
                        if let notice {
                            InfoTag(title: notice, tone: .warning)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// 徒步摘要块：段落标题 + 指标行。
    static func hikeSummaryBlock(_ projection: TripDayHikeSummaryProjection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                Text("徒步 · \(projection.segment)")
                    .font(.listTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let metrics = projection.metricsText {
                    Text(metrics)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textWeak)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// 天气字段块：四字段网格 + 过期提示。
    static func weatherFieldsBlock(_ weather: TripWeatherProjection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("当天行程天气")
                .font(.action)
                .foregroundStyle(AppColors.textPrimary)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 2),
                spacing: Spacing.md
            ) {
                ForEach(Array(weather.fields.enumerated()), id: \.offset) { _, field in
                    TripWeatherField(label: field.label, value: field.value)
                }
            }

            if weather.hasStaleField {
                NoticeView(
                    message: "过期状态只作用于对应天气字段，其他内容仍按原值展示。",
                    title: "部分天气可能过期",
                    tone: .stale
                )
            }
        }
    }
}

#if DEBUG
extension TripDayArrangementProjection {
    private static let dayActions = [
        TripTimelineItemProjection(
            id: "trip-action-1",
            time: "07:30",
            title: "路线接驳",
            details: ["上木居 → 徒步入口", "预计 45 分钟"]
        ),
        TripTimelineItemProjection(
            id: "trip-action-2",
            time: "08:30",
            title: "河谷入口至林线营地",
            details: ["14.8 km", "累计爬升 920 m", "预计 7 小时"],
            notices: ["末段路面湿滑，保留通过时间。"]
        ),
    ]

    private static let transportActions = [
        TripTimelineItemProjection(
            id: "trip-action-transport",
            time: nil,
            title: "大交通",
            details: ["成都 → 康定", "班次时间待核验"]
        ),
    ]

    private static let dayPoints = [
        TripPointProjection(
            id: "trip-point-1",
            title: "石壁溪流",
            details: ["路线第 8.4 km", "枯水季可能断流"],
            trailing: "水源"
        ),
        TripPointProjection(
            id: "trip-point-2",
            title: "林线营地",
            details: ["平缓台地，避开低洼积水区域"],
            trailing: "营地"
        ),
    ]

    private static let routeMetrics = [
        MetricItemModel(id: "day-distance", value: "14.8", unit: "km", label: "距离"),
        MetricItemModel(id: "day-ascent", value: "920", unit: "m", label: "累计爬升"),
        MetricItemModel(id: "day-duration", value: "7", unit: "小时", label: "预计用时"),
    ]

    private static let dayResources = [
        TripDayResourceProjection(id: "point-1", category: "水源", name: "河谷水源点", distance: "2.2 km"),
        TripDayResourceProjection(id: "point-2", category: "营地", name: "林线营地", distance: nil),
    ]

    private static let dayDefault = TripDayProjection(
        tripDayID: "trip-day-2",
        dayNumber: 2,
        date: "2026-09-08",
        primaryStage: "翻越北侧垭口",
        hikingDayNumber: 1,
        actions: TripDayArrangementProjection.dayActions,
        points: TripDayArrangementProjection.dayPoints,
        resources: TripDayArrangementProjection.dayResources,
        weather: TripWeatherProjection.known,
        dailyRouteSummary: TripDailyRouteSummaryProjection(
            title: "河谷入口至林线营地",
            endpoints: "徒步入口 → 林线营地",
            metrics: TripDayArrangementProjection.routeMetrics
        ),
        totalTrekDays: 2,
        outboundTransport: TripDayTransportSummaryProjection(
            direction: .outbound,
            title: "大交通与路线接驳",
            timeRange: "08:00 出发",
            duration: "3.0 小时",
            path: "成都 → 四姑娘山镇",
            modes: "公共交通",
            notice: "游客中心换乘"
        ),
        hikeSummary: TripDayHikeSummaryProjection(
            segment: "河谷入口至林线营地",
            distance: "12.4 km",
            ascent: "860 m",
            duration: "5.0 小时",
            nodes: [
                TripDayHikeNodeProjection(type: "起点", name: "河谷入口", position: nil),
                TripDayHikeNodeProjection(type: "终点", name: "林线营地", position: nil),
            ]
        ),
        returnTransport: nil
    )

    private static let dayTransportOnly = TripDayProjection(
        tripDayID: "trip-day-1",
        dayNumber: 1,
        date: "2026-09-07",
        primaryStage: "抵达与适应",
        hikingDayNumber: nil,
        actions: TripDayArrangementProjection.transportActions,
        points: [],
        weather: TripWeatherProjection.known,
        dailyRouteSummary: nil
    )

    private static let dayWeatherUnavailable = TripDayProjection(
        tripDayID: "trip-day-4",
        dayNumber: 4,
        date: "2026-09-10",
        primaryStage: "返程",
        hikingDayNumber: nil,
        actions: TripDayArrangementProjection.transportActions,
        points: TripDayArrangementProjection.dayPoints,
        weather: TripWeatherProjection.unavailable,
        dailyRouteSummary: nil
    )

    static let `default` = TripDayArrangementProjection(
        blocks: [
            .transport(
                TripDayArrangementProjection.dayDefault.outboundTransport ?? TripDayTransportSummaryProjection(
                    direction: .outbound,
                    title: "大交通与路线接驳",
                    timeRange: nil,
                    duration: nil,
                    path: nil,
                    modes: nil,
                    notice: nil
                ),
                details: []
            ),
            .hike(
                TripDayArrangementProjection.dayDefault.hikeSummary ?? TripDayHikeSummaryProjection(
                    segment: "徒步段",
                    distance: nil,
                    ascent: nil,
                    duration: nil,
                    nodes: []
                ),
                details: TripDayArrangementProjection.dayDefault.actions,
                points: TripDayArrangementProjection.dayDefault.points
            ),
            .weather(TripDayArrangementProjection.dayDefault.weather),
        ]
    )

    static let transportOnly = TripDayArrangementProjection(
        blocks: [
            .transport(
                TripDayArrangementProjection.dayTransportOnly.outboundTransport ?? TripDayTransportSummaryProjection(
                    direction: .outbound,
                    title: "大交通与路线接驳",
                    timeRange: nil,
                    duration: nil,
                    path: nil,
                    modes: nil,
                    notice: nil
                ),
                details: TripDayArrangementProjection.transportActions
            ),
            .weather(TripDayArrangementProjection.dayTransportOnly.weather),
        ]
    )

    static let weatherUnavailable = TripDayArrangementProjection(
        blocks: [
            .hike(
                TripDayArrangementProjection.dayWeatherUnavailable.hikeSummary ?? TripDayHikeSummaryProjection(
                    segment: "徒步段",
                    distance: nil,
                    ascent: nil,
                    duration: nil,
                    nodes: []
                ),
                details: TripDayArrangementProjection.dayWeatherUnavailable.actions,
                points: TripDayArrangementProjection.dayWeatherUnavailable.points
            ),
            .weather(TripDayArrangementProjection.dayWeatherUnavailable.weather),
        ]
    )

    static let referenceGuide = referenceGuideSample(longText: false)
    static let referenceGuideLong = referenceGuideSample(longText: true)
    static let hikeSectionUnavailable = TripDayArrangementProjection(blocks: [
        .hike(.init(segment: "徒步区段待确认", distance: nil, ascent: nil, duration: nil, nodes: []),
              details: [.init(id: "unknown-hike", time: nil, title: "徒步", details: [],
                              notices: ["徒步路段：信息不可用", "距离：信息不可用", "预计耗时：信息不可用"])], points: []),
        .weather(TripWeatherProjection.unavailable),
    ])

    private static func referenceGuideSample(longText: Bool) -> TripDayArrangementProjection {
        let pending = InformationConfidence(status: "pending_verification", category: .publicRouteFact,
                                            source: "历史参考资料，尚未复核")
        let description = "原记录包含进山接驳与湖畔扎营，实际徒步起点和活动边界尚待核验。"
            + (longText ? String(repeating: "\n\n参考资料中的行进过程、停留安排及道路状态均按原文字保留；长说明需要完整阅读，不能因为换行或分页丢失待核验提示。", count: 6) : "")
        let guide = PersonalTripRouteGuide(
            sourceReferenceDayID: "preview-reference-day",
            description: .init(value: description, confidence: pending),
            notes: .init(value: "历史费用、道路开放和水源情况需重新确认。", confidence: pending),
            accommodationReference: .init(value: nil, confidence: .init(status: "unknown", category: .publicRouteFact)),
            referenceTrack: .init(distance: .init(meters: 9240), ascent: .init(meters: 700),
                                  descent: .init(meters: 120), estimatedDuration: .init(seconds: 15480),
                                  confidence: .init(status: "pending_verification", category: .publicRouteFact,
                                                    source: "参考范围未确认实际活动方式"))
        )
        return .init(blocks: [.routeGuide(.init(guide: guide)), .weather(TripWeatherProjection.unavailable)])
    }
}

#Preview("TripDayArrangement.referenceGuide") {
    BusinessComponentPreviewHost {
        ScrollView {
            TripBusinessComponents.TripDayArrangement(projection: .referenceGuide)
        }
    }
}

#Preview("TripDayArrangement.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayArrangement(
            projection: TripDayArrangementProjection.default
        )
        .frame(height: 700)
    }
}

#Preview("TripDayArrangement.transportOnly") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayArrangement(
            projection: TripDayArrangementProjection.transportOnly
        )
        .frame(height: 620)
    }
}

#Preview("TripDayArrangement.weatherUnavailable") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayArrangement(
            projection: TripDayArrangementProjection.weatherUnavailable
        )
        .frame(height: 700)
    }
}
#endif
