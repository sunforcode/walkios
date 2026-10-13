import SwiftUI
import WalkData
import WalkDesignSystem

extension TripBusinessComponents {
    /// 行程详情页每日天气摘要行：D 序 + 日期 + 冻结天气地点｜状况 + 温度 + 进入天气页入口。
    /// 只承担「扫一眼」摘要；四字段明细归 PAGE-TRIP-WEATHER 的 DailyWeatherCard，本行不重复。
    struct DailyWeatherSummaryRow: View {
        enum Presentation {
            case standard
            case inline
        }

        let day: TripWeatherDayProjection
        var presentation: Presentation = .standard

        var body: some View {
            Group {
                switch presentation {
                case .standard:
                    ViewThatFits(in: .horizontal) {
                        horizontalRow
                        compactRow
                    }
                case .inline:
                    inlineSummary
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }

        private var inlineSummary: some View {
            HStack(alignment: .center, spacing: Spacing.xs) {
                Image(systemName: Self.conditionSymbol(day.weather.condition.value))
                    .font(.appCaption)
                    .foregroundStyle(AppColors.interactionPrimary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    if day.weather.condition.isUnavailable, day.weather.temperature.isUnavailable {
                        Text("该日天气暂不可用")
                            .font(.weatherConclusion)
                            .foregroundStyle(AppColors.textWeak)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        if let condition = tripNonEmpty(day.weather.condition.value) {
                            Text(condition)
                                .font(.weatherConclusion)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let temperature = tripNonEmpty(day.weather.temperature.value) {
                            Text(temperature)
                                .font(.weatherImpact)
                                .foregroundStyle(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                disclosure
            }
            .frame(minHeight: 44, alignment: .leading)
        }

        private var accessibilitySummary: String {
            [
                "第 \(day.dayNumber) 日",
                day.date,
                tripNonEmpty(day.primaryStage),
                tripNonEmpty(day.placeContext),
                "天气状况，\(day.weather.condition.displayText)",
                "温度，\(day.weather.temperature.displayText)",
            ].compactMap { $0 }.joined(separator: "，")
        }

        private var horizontalRow: some View {
            HStack(alignment: .center, spacing: Spacing.md) {
                dayBadge
                dateAndPlace
                weatherSummary(allowsWrapping: false)
                disclosure
            }
        }

        private var compactRow: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .center, spacing: Spacing.md) {
                    dayBadge
                    dateAndPlace
                }

                HStack(alignment: .center, spacing: Spacing.xs) {
                    weatherSummary(allowsWrapping: true)
                    Spacer(minLength: 0)
                    disclosure
                }
            }
        }

        private var dayBadge: some View {
            Text("D\(day.dayNumber)")
                .font(.sequenceCompact)
                .foregroundStyle(AppColors.interactionPrimary)
                .frame(width: 30, height: 30)
                .background(
                    AppColors.interactionBackground,
                    in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                )
        }

        private var dateAndPlace: some View {
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
        }

        @ViewBuilder
        private func weatherSummary(allowsWrapping: Bool) -> some View {
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
                            .lineLimit(allowsWrapping ? nil : 1)
                            .fixedSize(horizontal: false, vertical: allowsWrapping)
                    }

                    if let temperature = tripNonEmpty(day.weather.temperature.value) {
                        Text(temperature)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(allowsWrapping ? nil : 1)
                            .fixedSize(horizontal: false, vertical: allowsWrapping)
                    }
                }
            }
        }

        private var disclosure: some View {
            Image(systemName: "chevron.right")
                .font(.micro)
                .foregroundStyle(AppColors.textWeak)
                .accessibilityHidden(true)
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
            day: TripWeatherDayProjection.knownWithPlace
        )
    }
}

#Preview("DailyWeatherSummaryRow.unavailable") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.DailyWeatherSummaryRow(
            day: TripWeatherDayProjection.unavailable
        )
    }
}

#Preview("DailyWeatherSummaryRow.compact") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.DailyWeatherSummaryRow(
            day: TripWeatherDayProjection.knownWithPlace
        )
        .frame(width: 160)
    }
}

#Preview("DailyWeatherSummaryRow.compactUnavailable") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.DailyWeatherSummaryRow(
            day: TripWeatherDayProjection.unavailable
        )
        .frame(width: 160)
    }
}

#Preview("DailyWeatherSummaryRow.inline") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.DailyWeatherSummaryRow(
            day: TripWeatherDayProjection.knownWithPlace,
            presentation: .inline
        )
        .frame(width: 98)
    }
}

#Preview("DailyWeatherSummaryRow.inlineUnavailable") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.DailyWeatherSummaryRow(
            day: TripWeatherDayProjection.unavailable,
            presentation: .inline
        )
        .frame(width: 98)
    }
}
#endif
