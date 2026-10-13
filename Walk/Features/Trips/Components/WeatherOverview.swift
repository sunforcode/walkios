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
extension WeatherOverviewProjection {
    static let `default` = WeatherOverviewProjection(
        summary: TripWeatherValueProjection(value: "行程前半段多云，后半段有阵雨。", state: nil),
        importantImpacts: [
            "午后通过垭口时可能遇到短时雷雨。",
            "山脊阵风可能影响队伍行进节奏。",
        ]
    )

    static let stale = WeatherOverviewProjection(
        summary: TripWeatherValueProjection(
            value: "原概况提示垭口区域以多云和间歇阵雨为主。",
            state: .stale
        ),
        importantImpacts: ["请结合逐日天气与实际现场条件判断。"]
    )
}

#Preview("WeatherOverview.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.WeatherOverview(
            projection: WeatherOverviewProjection.default
        )
    }
}

#Preview("WeatherOverview.stale") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.WeatherOverview(
            projection: WeatherOverviewProjection.stale
        )
    }
}
#endif
