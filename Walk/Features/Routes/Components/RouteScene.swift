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
                    .immersiveBottomContentPadding(Spacing.xl)
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
extension RouteSceneProjection {
    private static let sampleMetrics = [
        MetricItemModel(id: "distance", value: "42.8", unit: "km", label: "距离"),
        MetricItemModel(id: "ascent", value: "2,340", unit: "m", label: "累计爬升"),
        MetricItemModel(id: "duration", value: "4", unit: "天", label: "预计用时"),
    ]

    static let `default` = RouteSceneProjection(
        routeID: "route-001",
        coverAvailable: true,
        name: "贡嘎西南坡环线",
        region: "四川 · 甘孜",
        difficulty: "进阶",
        metrics: RouteSceneProjection.sampleMetrics
    )

    static let neutral = RouteSceneProjection(
        routeID: "route-002",
        coverAvailable: false,
        name: "河谷森林线",
        region: "云南 · 怒江",
        difficulty: "中等",
        metrics: RouteSceneProjection.sampleMetrics
    )

    static let nameMissing = RouteSceneProjection(
        routeID: "route-003",
        coverAvailable: true,
        name: nil,
        region: "青海 · 海西",
        difficulty: "困难",
        metrics: RouteSceneProjection.sampleMetrics
    )

    static let tagsOmitted = RouteSceneProjection(
        routeID: "route-004",
        coverAvailable: true,
        name: "高山草甸环线",
        region: nil,
        difficulty: nil,
        metrics: RouteSceneProjection.sampleMetrics
    )

    static let partialMetrics = RouteSceneProjection(
        routeID: "route-005",
        coverAvailable: true,
        name: "山谷观景线",
        region: "北京 · 延庆",
        difficulty: "中等",
        metrics: [RouteSceneProjection.sampleMetrics[0]]
    )

    static let metricsOmitted = RouteSceneProjection(
        routeID: "route-006",
        coverAvailable: true,
        name: "林线短程路线",
        region: "四川 · 阿坝",
        difficulty: "简单",
        metrics: []
    )

    static let long = RouteSceneProjection(
        routeID: "route-007",
        coverAvailable: true,
        name: "穿越原始森林、高山草甸与连续垭口的长距离环形徒步路线",
        region: "四川省甘孜藏族自治州",
        difficulty: "高海拔进阶路线",
        metrics: RouteSceneProjection.sampleMetrics
    )
}

#Preview("RouteScene.default") {
    RouteBusinessComponents.RouteScene(
        projection: RouteSceneProjection.default,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .ridge)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.neutralTerrain") {
    RouteBusinessComponents.RouteScene(
        projection: RouteSceneProjection.neutral,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .forest)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.nameMissing") {
    RouteBusinessComponents.RouteScene(
        projection: RouteSceneProjection.nameMissing,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .water)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.tagsOmitted") {
    RouteBusinessComponents.RouteScene(
        projection: RouteSceneProjection.tagsOmitted,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .ridge)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.partialMetrics") {
    RouteBusinessComponents.RouteScene(
        projection: RouteSceneProjection.partialMetrics,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .forest)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.metricsOmitted") {
    RouteBusinessComponents.RouteScene(
        projection: RouteSceneProjection.metricsOmitted,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .ridge)
    }
    .frame(width: 390, height: 700)
}

#Preview("RouteScene.longContent") {
    RouteBusinessComponents.RouteScene(
        projection: RouteSceneProjection.long,
        onSelect: { _ in }
    ) {
        RouteDeterministicImageSurface(style: .water)
    }
    .frame(width: 390, height: 700)
}
#endif
