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
        content(horizontalPadding: FocusTripLayout.horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .bottomLeading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("继续行程：\(model.routeName)。\(accessibilitySummary)")
            .accessibilityHint("打开个人行程详情")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onOpen() }
    }

    private func content(horizontalPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            routeIdentity

            MetricGroup(items: model.metrics, variant: .inline)

            WeatherSummary(model: resolvedWeather)
        }
        .padding(.bottom, FocusTripLayout.contentBottomPadding)
        .padding(.horizontal, horizontalPadding)
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

}

private enum FocusTripLayout {
    static let horizontalPadding: CGFloat = 18
    static let compactHorizontalPadding = Spacing.lg
    static let routeIdentityMaxWidth: CGFloat = 290
    static let contentBottomPadding: CGFloat = 32
}

#if DEBUG
extension FocusTripSummaryModel {
    static let complete = FocusTripSummaryModel(
        routeName: "云岭环线",
        start: "云栈口",
        end: "云栈口",
        distance: "12.1",
        distanceUnit: "km",
        ascent: "600",
        ascentUnit: "m",
        estimatedDuration: "约 5 h 20 min",
        weather: .available
    )

    static let missingMetrics = FocusTripSummaryModel(
        routeName: "云岭环线",
        start: "云栈口",
        end: "云栈口",
        distance: nil,
        distanceUnit: "km",
        ascent: nil,
        ascentUnit: "m",
        estimatedDuration: "约 5 h 20 min",
        weather: .available
    )

    static let weatherOmitted = FocusTripSummaryModel(
        routeName: "云岭环线",
        start: "云栈口",
        end: "云栈口",
        distance: "12.1",
        distanceUnit: "km",
        ascent: "600",
        ascentUnit: "m",
        estimatedDuration: "约 5 h 20 min",
        weather: nil
    )

    static let longContent = FocusTripSummaryModel(
        routeName: "云岭北坡高山草甸与连续山脊全景环线",
        start: "云栈口游客中心北侧长距离接驳点",
        end: "云栈口游客中心南侧返程集合点",
        distance: "12.1",
        distanceUnit: "km",
        ascent: "600",
        ascentUnit: "m",
        estimatedDuration: "约 5 h 20 min",
        weather: .longContent
    )
}

#Preview("complete") {
    FocusTripSummary(model: FocusTripSummaryModel.complete, onOpen: {})
        .frame(width: 390, height: 760)
        .background(AppColors.pageBase)
}

#Preview("missingMetrics") {
    FocusTripSummary(model: FocusTripSummaryModel.missingMetrics, onOpen: {})
        .frame(width: 390, height: 760)
        .background(AppColors.pageBase)
}

#Preview("weatherOmitted") {
    FocusTripSummary(model: FocusTripSummaryModel.weatherOmitted, onOpen: {})
        .frame(width: 390, height: 760)
        .background(AppColors.pageBase)
}

#Preview("longContent") {
    FocusTripSummary(model: FocusTripSummaryModel.longContent, onOpen: {})
        .frame(width: 320, height: 760)
        .background(AppColors.pageBase)
        .environment(\.dynamicTypeSize, .accessibility2)
}
#endif
