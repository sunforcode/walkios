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
            if !rows.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        Text(row.1)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(Array(details.flatMap { item in
                        item.notices.map { (item.id, $0) }
                    }.enumerated()), id: \.offset) { _, notice in
                        NoticeView(message: notice.1, tone: .warning)
                    }
                }
            }
        }

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
#Preview("TripDayArrangement.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayArrangement(
            projection: BusinessComponentPreviewFixtures.tripArrangementDefault
        )
        .frame(height: 700)
    }
}

#Preview("TripDayArrangement.transportOnly") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayArrangement(
            projection: BusinessComponentPreviewFixtures.tripArrangementTransportOnly
        )
        .frame(height: 620)
    }
}

#Preview("TripDayArrangement.weatherUnavailable") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayArrangement(
            projection: BusinessComponentPreviewFixtures.tripArrangementWeatherUnavailable
        )
        .frame(height: 700)
    }
}
#endif
