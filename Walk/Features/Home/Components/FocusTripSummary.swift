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
                    .frame(minHeight: proxy.size.height, alignment: .topLeading)
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
        VStack(alignment: .leading, spacing: 0) {
            routeIdentity
                .frame(maxWidth: FocusTripLayout.routeIdentityMaxWidth, alignment: .leading)
                .padding(.top, FocusTripLayout.routeIdentityTop)

            Spacer(minLength: Spacing.lg)

            MetricGroup(items: model.metrics, variant: .inline)
                .padding(.bottom, Spacing.xl)

            if let weather = model.weather {
                WeatherSummary(model: weather)
                    .padding(.bottom, FocusTripLayout.weatherBottom)
            }
        }
        .padding(.horizontal, horizontalPadding)
        .foregroundStyle(AppColors.textPrimary)
    }

    private var routeIdentity: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(model.routeName)
                .font(.sceneTitle)
                .tracking(-1.2)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(model.start) → \(model.end)")
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var accessibilitySummary: String {
        let metricSummary = model.metrics.map { item in
            guard let value = item.value else { return "\(item.label)未提供" }
            return "\(item.label)\(value)\(item.unit ?? "")"
        }
        var summary = ["\(model.start)到\(model.end)"] + metricSummary
        if let weather = model.weather {
            summary.append(contentsOf: [weather.conclusion, weather.impact])
        }
        return summary.joined(separator: "，")
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        width < 390 ? FocusTripLayout.compactHorizontalPadding : FocusTripLayout.horizontalPadding
    }
}

private enum FocusTripLayout {
    static let horizontalPadding: CGFloat = 18
    static let compactHorizontalPadding = Spacing.lg
    static let routeIdentityTop: CGFloat = 58
    static let routeIdentityMaxWidth: CGFloat = 290
    static let weatherBottom: CGFloat = 26
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
