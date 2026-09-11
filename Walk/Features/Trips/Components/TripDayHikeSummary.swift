import SwiftUI
import WalkData
import WalkDesignSystem

/// 业务组合 TripDayHikeSummary（L2c）：自然日徒步段摘要：段落、距离、爬升、用时与有序节点。
/// 视觉合同见 docs/ui/components/business/composites/trip-day-hike-summary/spec.md。
struct TripDayHikeNodeProjection: Equatable {
    let type: String
    var name: String?
    var position: String?
}

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

extension TripBusinessComponents {
    struct TripDayHikeSummary: View {
        let projection: TripDayHikeSummaryProjection

        var body: some View {
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

                if !projection.nodes.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        ForEach(Array(projection.nodes.enumerated()), id: \.offset) { _, node in
                            nodeRow(node)
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColors.surfaceSoft,
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
            .accessibilityElement(children: .combine)
        }

        private func nodeRow(_ node: TripDayHikeNodeProjection) -> some View {
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

#if DEBUG
#Preview("TripDayHikeSummary.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayHikeSummary(
            projection: TripDayHikeSummaryProjection(
                segment: "长坪沟入口至一号营地",
                distance: "12.4 km",
                ascent: "860 m",
                duration: "5.0 小时",
                nodes: [
                    TripDayHikeNodeProjection(type: "起点", name: "长坪沟入口", position: nil),
                    TripDayHikeNodeProjection(type: "终点", name: "一号营地", position: nil),
                ]
            )
        )
        .padding(Spacing.lg)
    }
}

#Preview("TripDayHikeSummary.sparse") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayHikeSummary(
            projection: TripDayHikeSummaryProjection(
                segment: "营地至木骡子",
                distance: nil,
                ascent: nil,
                duration: nil,
                nodes: [
                    TripDayHikeNodeProjection(type: "起点", name: "一号营地", position: nil),
                    TripDayHikeNodeProjection(type: "终点", name: "木骡子", position: nil),
                ]
            )
        )
        .padding(Spacing.lg)
    }
}
#endif
