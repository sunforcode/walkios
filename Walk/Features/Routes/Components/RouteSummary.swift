import SwiftUI
import WalkData
import WalkDesignSystem

struct RouteSummaryProjection: Equatable {
    var name: String?
    var introduction: String?
    var tags: [String]
    var metrics: [MetricItemModel]
}

extension RouteBusinessComponents {
    struct RouteSummary: View {
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize
        let projection: RouteSummaryProjection

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                if let name = routeNonEmpty(projection.name) {
                    Text(name)
                        .font(.heroTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let introduction = routeNonEmpty(projection.introduction) {
                    Text(introduction)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Spacing.sm)
                }

                if !projection.tags.isEmpty {
                    RouteWrapLayout {
                        ForEach(Array(projection.tags.enumerated()), id: \.offset) { _, tag in
                            InfoTag(title: tag, tone: .neutral)
                        }
                    }
                    .padding(.top, Spacing.md)
                }

                if !projection.metrics.isEmpty {
                    MetricGroup(items: projection.metrics, variant: .grid)
                        .padding(.top, Spacing.lg)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        }
    }
}

#if DEBUG
extension RouteSummaryProjection {
    private static let sampleMetrics = [
        MetricItemModel(id: "summary-distance", value: "42.8", unit: "km", label: "距离"),
        MetricItemModel(id: "summary-duration", value: "4", unit: "天", label: "预计用时"),
        MetricItemModel(id: "summary-ascent", value: "2,340", unit: "m", label: "累计爬升"),
        MetricItemModel(id: "summary-descent", value: "2,180", unit: "m", label: "累计下降"),
    ]

    static let `default` = RouteSummaryProjection(
        name: "贡嘎西南坡环线",
        introduction: "环绕贡嘎西南坡的经典徒步线路，翻越垭口远眺主峰，冰川、草甸与森林交替呈现。",
        tags: ["四川 · 甘孜", "进阶", "多日路线"],
        metrics: RouteSummaryProjection.sampleMetrics
    )

    static let partial = RouteSummaryProjection(
        name: "河谷森林线",
        introduction: nil,
        tags: ["中等"],
        metrics: [RouteSummaryProjection.sampleMetrics[0]]
    )

    static let long = RouteSummaryProjection(
        name: "穿越原始森林、高山草甸与连续垭口的长距离环形徒步路线",
        introduction: "从高山村北侧徒步入口出发，沿河谷溯溪而上，穿越原始森林与连续垭口后下撤至河谷游客服务站。",
        tags: ["四川省甘孜藏族自治州", "高海拔进阶路线", "多日路线"],
        metrics: RouteSummaryProjection.sampleMetrics
    )
}

#Preview("RouteSummary.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSummary(
            projection: RouteSummaryProjection.default
        )
    }
}

#Preview("RouteSummary.partial") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSummary(
            projection: RouteSummaryProjection.partial
        )
    }
}

#Preview("RouteSummary.longContent") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSummary(
            projection: RouteSummaryProjection.long
        )
    }
}
#endif
