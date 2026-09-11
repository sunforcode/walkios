import SwiftUI
import WalkData
import WalkDesignSystem

struct WeatherOverviewProjection: Equatable {
    let summary: TripWeatherValueProjection
    let importantImpacts: [String]
}

extension TripBusinessComponents {
    struct WeatherOverview: View {
        let projection: WeatherOverviewProjection

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(projection.summary.displayText)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if projection.summary.state == .stale {
                    NoticeView(
                        message: "概况内容仍保留，请结合逐日天气判断。",
                        title: "天气概况可能过期",
                        tone: .stale
                    )
                }

                ForEach(Array(projection.importantImpacts.enumerated()), id: \.offset) { _, impact in
                    NoticeView(
                        message: impact,
                        title: "重要影响",
                        icon: "exclamationmark.triangle",
                        tone: .warning
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        }
    }
}

#if DEBUG
#Preview("WeatherOverview.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.WeatherOverview(
            projection: BusinessComponentPreviewFixtures.weatherOverviewDefault
        )
    }
}

#Preview("WeatherOverview.stale") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.WeatherOverview(
            projection: BusinessComponentPreviewFixtures.weatherOverviewStale
        )
    }
}
#endif
