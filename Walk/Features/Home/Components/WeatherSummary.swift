import SwiftUI
import WalkData
import WalkDesignSystem

enum WeatherSummaryState: Equatable {
    case available
    case stale
    case unavailable
    /// 字段整体省略的中性态；不得把省略解释为 unavailable。
    case omitted
}

struct WeatherSummaryModel: Equatable {
    let conclusion: String
    let impact: String
    let state: WeatherSummaryState
}

struct WeatherSummary: View {
    let model: WeatherSummaryModel

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: iconName)
                .font(.bodyEmphasis)
                .foregroundStyle(iconForeground)
                .frame(width: 28, height: 28)
                .background(iconBackground, in: Circle())
                .appShadow(AppShadow.interactionGlow)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(model.conclusion)
                    .font(.weatherConclusion)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(model.impact)
                    .font(.weatherImpact)
                    .foregroundStyle(AppColors.textWeak)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .allowsHitTesting(false)
    }

    private var accessibilitySummary: String {
        [model.conclusion, model.impact, stateDescription]
            .joined(separator: "，")
    }

    private var stateDescription: String {
        switch model.state {
        case .available: "可用"
        case .stale: "可能已过期"
        case .unavailable: "不可用"
        case .omitted: "未提供"
        }
    }

    private var iconName: String {
        switch model.state {
        case .available: "cloud.sun"
        case .stale: "exclamationmark.triangle"
        case .unavailable: "minus"
        case .omitted: "tray"
        }
    }

    private var iconForeground: Color {
        model.state == .available ? AppColors.interactionOnPrimary : AppColors.textPrimary
    }

    private var iconBackground: Color {
        switch model.state {
        case .available: AppColors.interactionPrimary
        case .stale: AppColors.warningBackground
        case .unavailable, .omitted: AppColors.surfaceMuted
        }
    }
}

#if DEBUG
#Preview("default") {
    WeatherSummary(model: HomePreviewFixtures.weatherAvailable)
        .padding()
        .background(AppColors.pageBase)
}

#Preview("omitted") {
    WeatherSummary(model: HomePreviewFixtures.weatherOmitted)
        .padding()
        .background(AppColors.pageBase)
}

#Preview("stale") {
    WeatherSummary(model: HomePreviewFixtures.weatherStale)
        .padding()
        .background(AppColors.pageBase)
}

#Preview("longContent") {
    WeatherSummary(model: HomePreviewFixtures.weatherLongContent)
        .padding()
        .frame(width: 320)
        .background(AppColors.pageBase)
}
#endif
