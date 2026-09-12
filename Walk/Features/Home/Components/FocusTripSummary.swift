import SwiftUI
import WalkData
import WalkDesignSystem

struct FocusTripSummaryModel: Equatable {
    let routeName: String
    let start: String
    let end: String
    let distance: String?
    let distanceUnit: String?
    let ascent: String?
    let ascentUnit: String?
    let estimatedDuration: String
    let weather: WeatherSummaryModel?

    var metrics: [MetricItemModel] {
        [
            MetricItemModel(
                id: "distance",
                value: distance,
                unit: distanceUnit,
                label: "距离"
            ),
            MetricItemModel(
                id: "ascent",
                value: ascent,
                unit: ascentUnit,
                label: "累计爬升"
            ),
            MetricItemModel(
                id: "duration",
                value: estimatedDuration,
                label: "预计用时"
            ),
        ]
    }
}

struct FocusTripSummary: View {
    let model: FocusTripSummaryModel
    let onOpen: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content(horizontalPadding: horizontalPadding(for: proxy.size.width))
                    .frame(minHeight: proxy.size.height, alignment: .bottomLeading)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("继续行程：\(model.routeName)。\(accessibilitySummary)")
            .accessibilityHint("打开个人行程详情")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onOpen() }
        }
    }

    private func content(horizontalPadding: CGFloat) -> some View {
        // 左侧单一信息块：沉底左下、全局一级导航之上；
        // 路线名、一句话描述（起终点）、距离/爬升/用时、天气自上而下排列。
        VStack(alignment: .leading, spacing: Spacing.lg) {
            routeIdentity

            MetricGroup(items: model.metrics, variant: .inline)

            WeatherSummary(model: resolvedWeather)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.bottom, FocusTripLayout.contentBottomPadding)
        .foregroundStyle(AppColors.textPrimary)
    }

    /// H1：weather 整体省略时仍渲染 WeatherSummary 两个中性槽位（不得解释为 unavailable）。
    private var resolvedWeather: WeatherSummaryModel {
        model.weather ?? WeatherSummaryModel(
            conclusion: "本次未提供天气摘要",
            impact: "行程其他内容仍可查看",
            state: .omitted
        )
    }

    private var routeIdentity: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(model.routeName)
                .font(.displayTitle)
                .tracking(-1.2)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(model.start) → \(model.end)")
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: FocusTripLayout.routeIdentityMaxWidth, alignment: .leading)
    }

    private var accessibilitySummary: String {
        let metricSummary = model.metrics.map { item in
            guard let value = item.value else { return "\(item.label)未提供" }
            return "\(item.label)\(value)\(item.unit ?? "")"
        }
        var summary = ["\(model.start)到\(model.end)"] + metricSummary
        summary.append(contentsOf: [resolvedWeather.conclusion, resolvedWeather.impact])
        return summary.joined(separator: "，")
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        width < 390 ? FocusTripLayout.compactHorizontalPadding : FocusTripLayout.horizontalPadding
    }
}

private enum FocusTripLayout {
    static let horizontalPadding: CGFloat = 18
    static let compactHorizontalPadding = Spacing.lg
    static let routeIdentityMaxWidth: CGFloat = 290
    static let contentBottomPadding: CGFloat = 32
}

#if DEBUG
#Preview("complete") {
    FocusTripSummary(model: HomePreviewFixtures.focusComplete, onOpen: {})
        .frame(width: 390, height: 760)
        .background(AppColors.pageBase)
}

#Preview("missingMetrics") {
    FocusTripSummary(model: HomePreviewFixtures.focusMissingMetrics, onOpen: {})
        .frame(width: 390, height: 760)
        .background(AppColors.pageBase)
}

#Preview("weatherOmitted") {
    FocusTripSummary(model: HomePreviewFixtures.focusWeatherOmitted, onOpen: {})
        .frame(width: 390, height: 760)
        .background(AppColors.pageBase)
}

#Preview("longContent") {
    FocusTripSummary(model: HomePreviewFixtures.focusLongContent, onOpen: {})
        .frame(width: 320, height: 760)
        .background(AppColors.pageBase)
        .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
