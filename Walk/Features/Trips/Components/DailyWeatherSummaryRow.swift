import SwiftUI
import WalkData
import WalkDesignSystem

extension TripBusinessComponents {
    /// 行程详情页每日天气摘要行：D 序 + 日期 + 冻结天气地点｜状况 + 温度 + 进入天气页入口。
    /// 只承担「扫一眼」摘要；四字段明细归 PAGE-TRIP-WEATHER 的 DailyWeatherCard，本行不重复。
    struct DailyWeatherSummaryRow: View {
        let day: TripWeatherDayProjection

        var body: some View {
            HStack(alignment: .center, spacing: Spacing.md) {
                Text("D\(day.dayNumber)")
                    .font(.sequenceCompact)
                    .foregroundStyle(AppColors.interactionPrimary)
                    .frame(width: 30, height: 30)
                    .background(
                        AppColors.interactionBackground,
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(day.date)
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let place = tripNonEmpty(day.placeContext) {
                        Text(place)
                            .font(.micro)
                            .foregroundStyle(AppColors.textWeak)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if day.weather.condition.isUnavailable, day.weather.temperature.isUnavailable {
                    Text("该日天气暂不可用")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textWeak)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(alignment: .center, spacing: Spacing.xs) {
                        Image(systemName: Self.conditionSymbol(day.weather.condition.value))
                            .font(.appCaption)
                            .foregroundStyle(AppColors.interactionPrimary)
                            .accessibilityHidden(true)

                        if let condition = tripNonEmpty(day.weather.condition.value) {
                            Text(condition)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }

                        if let temperature = tripNonEmpty(day.weather.temperature.value) {
                            Text(temperature)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.micro)
                    .foregroundStyle(AppColors.textWeak)
                    .accessibilityHidden(true)
            }
            .accessibilityElement(children: .combine)
        }

        /// 装饰性图标按冻结状况文本确定性映射，不引入新天气事实。
        private static func conditionSymbol(_ condition: String?) -> String {
            guard let condition = tripNonEmpty(condition) else { return "cloud.sun" }
            if condition.contains("雨") || condition.contains("雪") || condition.contains("雷") {
                return "cloud.rain"
            }
            if condition.contains("雾") || condition.contains("霾") { return "cloud.fog" }
            if condition.contains("晴") { return "sun.max" }
            if condition.contains("阴") { return "cloud" }
            return "cloud.sun"
        }
    }
}

#if DEBUG
#Preview("DailyWeatherSummaryRow.known") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.DailyWeatherSummaryRow(
            day: BusinessComponentPreviewFixtures.weatherDayRowKnown
        )
    }
}

#Preview("DailyWeatherSummaryRow.unavailable") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.DailyWeatherSummaryRow(
            day: BusinessComponentPreviewFixtures.weatherDayUnavailable
        )
    }
}
#endif
