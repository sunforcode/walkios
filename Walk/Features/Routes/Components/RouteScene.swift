import SwiftUI
import WalkData
import WalkDesignSystem

struct RouteSceneProjection: Equatable {
    let routeID: String
    var coverAvailable: Bool
    var name: String?
    var region: String?
    var difficulty: String?
    var metrics: [MetricItemModel]
}

extension RouteBusinessComponents {
    struct RouteScene<Visual: View>: View {
        let projection: RouteSceneProjection
        let onSelect: (String) -> Void
        private let visual: Visual

        init(
            projection: RouteSceneProjection,
            onSelect: @escaping (String) -> Void,
            @ViewBuilder visual: () -> Visual
        ) {
            self.projection = projection
            self.onSelect = onSelect
            self.visual = visual()
        }

        var body: some View {
            Button {
                onSelect(projection.routeID)
            } label: {
                ZStack(alignment: .topLeading) {
                    Group {
                        if projection.coverAvailable {
                            visual
                        } else {
                            RouteDeterministicImageSurface(style: .forest)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .accessibilityHidden(true)

                    LinearGradient(
                        colors: [
                            AppColors.pageBase.opacity(0.08),
                            AppColors.pageBase.opacity(0.12),
                            AppColors.pageBase.opacity(0.70),
                            AppColors.pageBase,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        Spacer(minLength: Spacing.xxl)

                        Text(routeNonEmpty(projection.name) ?? "路线名称未提供")
                            .font(.sceneTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if !tags.isEmpty {
                            RouteWrapLayout {
                                ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                                    InfoTag(title: tag, tone: .overlay)
                                }
                            }
                        }

                        if !projection.metrics.isEmpty {
                            MetricGroup(items: projection.metrics, variant: .inline)
                        }
                    }
                    .frame(maxWidth: 390, alignment: .leading)
                    .padding(Spacing.lg)
                    .padding(.bottom, Spacing.xl)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("查看路线详情")
        }

        private var tags: [String] {
            [projection.region, projection.difficulty].compactMap(routeNonEmpty)
        }

        private var accessibilityLabel: String {
            let name = routeNonEmpty(projection.name) ?? "路线名称未提供"
            let metricText = projection.metrics.compactMap { item -> String? in
                guard let value = item.value else { return nil }
                return "\(item.label) \(value)\(item.unit ?? "")"
            }
            return ([name] + tags + metricText).joined(separator: "，")
        }
    }
}

#if DEBUG
#Preview("RouteScene.default") {
    RouteBusinessComponents.RouteScene(
        projection: BusinessComponentPreviewFixtures.routeScene,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .ridge)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.neutralTerrain") {
    RouteBusinessComponents.RouteScene(
        projection: BusinessComponentPreviewFixtures.routeSceneNeutral,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .forest)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.nameMissing") {
    RouteBusinessComponents.RouteScene(
        projection: BusinessComponentPreviewFixtures.routeSceneNameMissing,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .water)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.tagsOmitted") {
    RouteBusinessComponents.RouteScene(
        projection: BusinessComponentPreviewFixtures.routeSceneTagsOmitted,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .ridge)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.partialMetrics") {
    RouteBusinessComponents.RouteScene(
        projection: BusinessComponentPreviewFixtures.routeScenePartialMetrics,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .forest)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.metricsOmitted") {
    RouteBusinessComponents.RouteScene(
        projection: BusinessComponentPreviewFixtures.routeSceneMetricsOmitted,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .ridge)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.longContent") {
    RouteBusinessComponents.RouteScene(
        projection: BusinessComponentPreviewFixtures.routeSceneLong,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .water)
    }
    .frame(width: 390, height: 700)
}
#endif
