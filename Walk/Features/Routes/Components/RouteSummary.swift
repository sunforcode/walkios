import SwiftUI
import WalkData
import WalkDesignSystem

struct RouteSummaryProjection: Equatable {
    var name: String?
    var start: String?
    var end: String?
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

                if let endpointText {
                    Text(endpointText)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
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

        private var endpointText: String? {
            let start = routeNonEmpty(projection.start)
            let end = routeNonEmpty(projection.end)
            if let start, let end { return "\(start) → \(end)" }
            return start ?? end
        }
    }
}

#if DEBUG
#Preview("RouteSummary.default") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSummary(
            projection: BusinessComponentPreviewFixtures.routeSummary
        )
    }
}

#Preview("RouteSummary.partial") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSummary(
            projection: BusinessComponentPreviewFixtures.routeSummaryPartial
        )
    }
}

#Preview("RouteSummary.longContent") {
    BusinessComponentPreviewHost {
        RouteBusinessComponents.RouteSummary(
            projection: BusinessComponentPreviewFixtures.routeSummaryLong
        )
    }
}
#endif
