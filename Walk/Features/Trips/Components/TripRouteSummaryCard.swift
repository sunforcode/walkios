import SwiftUI
import WalkData
import WalkDesignSystem

/// 路线走向文字卡投影：只消费本次行程冻结的路线事实；
/// 走向摘要与海拔剖面缺失时按局部状态表达，不从关键点名称或轨迹几何补造。
struct TripRouteSummaryProjection: Equatable {
    let routeName: String
    var versionLabel: String?
    /// 冻结路线走向摘要；nil 表示缺失，按局部不可用表达。
    var routeOrientation: String?
    /// 冻结海拔剖面；nil 表示缺失，不读取当前公共路线替代。
    var elevationSamples: [FrozenRouteElevationSample]?
    /// 冻结指标摘要（距离/爬升/下降/最高海拔），置于海拔图上方；nil 表示不展示。
    var metrics: TripRouteMetricsSummaryProjection?

    var hasElevationChart: Bool {
        (elevationSamples?.count ?? 0) >= 2
    }
}

extension TripBusinessComponents {
    /// 业务独立 TripRouteSummaryCard（L2b）：路线介绍区的走向文字卡，
    /// 整卡单一 activate 进入对应路线的公共路线详情页；指标摘要置于海拔图上方，不展示版本操作。
    /// 合同见 docs/ui/components/business/components/trip-route-summary-card/spec.md。
    struct TripRouteSummaryCard: View {
        let projection: TripRouteSummaryProjection
        let onActivate: () -> Void

        var body: some View {
            Button(action: onActivate) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    orientationText
                    if let metrics = projection.metrics {
                        TripBusinessComponents.TripRouteMetricsSummary(projection: metrics)
                    }
                    if projection.hasElevationChart {
                        elevationChart
                    } else {
                        UnavailableStateView(
                            title: "海拔剖面暂未提供",
                            message: "不读取当前公共路线替代冻结剖面。",
                            icon: "chart.xyaxis.line",
                            variant: .inline
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("进入路线详情")
        }

        private var header: some View {
            Text(projection.routeName)
                .font(.listTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        @ViewBuilder
        private var orientationText: some View {
            if let orientation = tripNonEmpty(projection.routeOrientation) {
                Text(orientation)
                    .font(.appBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("路线走向摘要暂未提供，不从关键点名称或轨迹推断。")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        /// 冻结海拔图：样本按累计距离映射为折线，只使用本次行程冻结剖面；
        /// 带纵轴（最高/最低海拔）与横轴（起点/终点累计距离）坐标轴。
        private var elevationChart: some View {
            let samples = projection.elevationSamples ?? []
            let maxMeters = samples.map(\.elevation.meters).max() ?? 0
            let minMeters = samples.map(\.elevation.meters).min() ?? 0
            let totalKilometers = Int(((samples.last?.distance.meters ?? 0) / 1000).rounded())
            return VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("海拔变化（冻结剖面）")
                    .font(.micro)
                    .foregroundStyle(AppColors.textWeak)

                HStack(alignment: .center, spacing: Spacing.xs) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text("\(Int(maxMeters.rounded())) m")
                        Spacer(minLength: 0)
                        Text("\(Int(minMeters.rounded())) m")
                    }
                    .font(.micro)
                    .foregroundStyle(AppColors.textWeak)

                    GeometryReader { proxy in
                        FrozenElevationChartShape(samples: samples)
                            .stroke(AppColors.interactionPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    }
                }
                .frame(height: 88)

                Divider()

                HStack {
                    Text("0 km")
                    Spacer()
                    Text("\(totalKilometers) km")
                }
                .font(.micro)
                .foregroundStyle(AppColors.textWeak)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("海拔变化图，最高海拔 \(Int(maxMeters.rounded())) 米，最低海拔 \(Int(minMeters.rounded())) 米，全程约 \(totalKilometers) 公里，来自本次行程冻结剖面")
        }
    }
}

/// 折线形状：x = 累计距离占比，y = 海拔占比（顶部为最高海拔）。
struct FrozenElevationChartShape: Shape {
    let samples: [FrozenRouteElevationSample]

    func path(in rect: CGRect) -> Path {
        guard samples.count >= 2 else { return Path() }
        let totalDistance = max(samples.last?.distance.meters ?? 0, 1)
        let elevations = samples.map(\.elevation.meters)
        let minElevation = elevations.min() ?? 0
        let maxElevation = elevations.max() ?? minElevation + 1
        let span = max(maxElevation - minElevation, 1)

        var path = Path()
        for (index, sample) in samples.enumerated() {
            let x = rect.minX + rect.width * CGFloat(sample.distance.meters / totalDistance)
            let y = rect.maxY - rect.height * CGFloat((sample.elevation.meters - minElevation) / span)
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

#if DEBUG
extension TripRouteSummaryProjection {
    static let `default` = TripRouteSummaryProjection(
        routeName: "贡嘎西南坡环线",
        versionLabel: "2026 夏季版",
        routeOrientation: "顺时针环绕贡嘎西坡，自老榆林经上子梅村翻越日乌且垭口至草科结束。",
        elevationSamples: [
            FrozenRouteElevationSample(
                distance: RouteDistance(meters: 0),
                elevation: RouteElevation(meters: 3_800)
            ),
            FrozenRouteElevationSample(
                distance: RouteDistance(meters: 15_000),
                elevation: RouteElevation(meters: 4_500)
            ),
            FrozenRouteElevationSample(
                distance: RouteDistance(meters: 32_000),
                elevation: RouteElevation(meters: 4_980)
            ),
            FrozenRouteElevationSample(
                distance: RouteDistance(meters: 55_000),
                elevation: RouteElevation(meters: 3_300)
            ),
        ]
    )

    static let partial = TripRouteSummaryProjection(
        routeName: "河谷森林线",
        versionLabel: nil,
        routeOrientation: nil,
        elevationSamples: nil
    )

    static let long = TripRouteSummaryProjection(
        routeName: "四川省甘孜藏族自治州高海拔连续垭口环形路线",
        versionLabel: "2026 夏季高海拔连续垭口修正版",
        routeOrientation: "顺时针环绕，连续翻越日乌且垭口、莫溪沟垭口与玉龙西垭口，途中沿河谷与林线交替行进，长距离缓升陡降交替。",
        elevationSamples: (0...12).map { index in
            FrozenRouteElevationSample(
                distance: RouteDistance(meters: Double(index) * 12_500),
                elevation: RouteElevation(meters: 3_200 + Double(index % 5) * 380)
            )
        }
    )
}

#Preview("TripRouteSummaryCard.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteSummaryCard(
            projection: TripRouteSummaryProjection.default,
            onActivate: {}
        )
    }
}

#Preview("TripRouteSummaryCard.partial") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteSummaryCard(
            projection: TripRouteSummaryProjection.partial,
            onActivate: {}
        )
    }
}

#Preview("TripRouteSummaryCard.longContent") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripRouteSummaryCard(
            projection: TripRouteSummaryProjection.long,
            onActivate: {}
        )
    }
}
#endif
