import SwiftUI
import WalkData
import WalkDesignSystem

struct TripRouteMetricsSummaryProjection: Equatable {
    let distance: String?
    let ascent: String?
    let estimatedDuration: String

    var metrics: [MetricItemModel] {
        [
            MetricItemModel(id: "distance", value: distance, unit: nil, label: "徒步距离"),
            MetricItemModel(id: "ascent", value: ascent, unit: nil, label: "累计爬升"),
            MetricItemModel(id: "estimated-duration", value: estimatedDuration, unit: nil, label: "预计徒步用时"),
        ]
    }
}

extension TripBusinessComponents {
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
#Preview("TripRouteMetricsSummary.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteMetricsSummary(
            projection: BusinessComponentPreviewFixtures.tripRouteMetricsDefault
        )
    }
}

#Preview("TripRouteMetricsSummary.partial") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteMetricsSummary(
            projection: BusinessComponentPreviewFixtures.tripRouteMetricsPartial
        )
    }
}

#Preview("TripRouteMetricsSummary.longValues") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteMetricsSummary(
            projection: BusinessComponentPreviewFixtures.tripRouteMetricsLong
        )
    }
}
#endif
