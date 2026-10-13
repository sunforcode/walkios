import SwiftUI
import WalkData
import WalkDesignSystem

/// 路线指标投影：只读本次行程冻结的 FrozenRouteBasis；
/// 缺失用 missing 语义表达，不补 0、不用当前公共路线替代。
struct TripRouteMetricsSummaryProjection: Equatable {
    var distance: String?
    var ascent: String?
    var descent: String?
    var maxElevation: String?

    var metrics: [MetricItemModel] {
        [
            MetricItemModel(id: "distance", value: distance, unit: nil, label: "徒步距离"),
            MetricItemModel(id: "ascent", value: ascent, unit: nil, label: "累计爬升"),
            MetricItemModel(id: "descent", value: descent, unit: nil, label: "累计下降"),
            MetricItemModel(id: "max-elevation", value: maxElevation, unit: nil, label: "最高海拔"),
        ]
    }
}

extension TripBusinessComponents {
    /// 业务独立 TripRouteMetricsSummary（L2b）：路线介绍区冻结指标摘要，
    /// 固定顺序「徒步距离 → 累计爬升 → 累计下降 → 最高海拔」。
    /// 合同见 docs/ui/components/business/components/trip-route-metrics-summary/spec.md。
    struct TripRouteMetricsSummary: View {
        let projection: TripRouteMetricsSummaryProjection

        var body: some View {
            MetricGroup(items: projection.metrics, variant: .grid)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
        }
    }
}

#if DEBUG
extension TripRouteMetricsSummaryProjection {
    static let `default` = TripRouteMetricsSummaryProjection(
        distance: "42.5 km",
        ascent: "2,300 m",
        descent: "2,180 m",
        maxElevation: "4,980 m"
    )

    static let partial = TripRouteMetricsSummaryProjection(
        distance: "42.5 km",
        ascent: nil,
        descent: nil,
        maxElevation: nil
    )

    static let long = TripRouteMetricsSummaryProjection(
        distance: "126.8 km",
        ascent: "8,940 m",
        descent: "8,410 m",
        maxElevation: "5,220 m"
    )
}

#Preview("TripRouteMetricsSummary.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteMetricsSummary(
            projection: TripRouteMetricsSummaryProjection.default
        )
    }
}

#Preview("TripRouteMetricsSummary.partial") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteMetricsSummary(
            projection: TripRouteMetricsSummaryProjection.partial
        )
    }
}

#Preview("TripRouteMetricsSummary.longValues") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteMetricsSummary(
            projection: TripRouteMetricsSummaryProjection.long
        )
    }
}
#endif
