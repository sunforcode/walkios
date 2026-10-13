import SwiftUI
import WalkData
import WalkDesignSystem

extension TripBusinessComponents {
    struct DailyWeatherCard: View {
        let day: TripWeatherDayProjection

        var body: some View {
            WalkCard {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    HStack(alignment: .top, spacing: Spacing.md) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("D\(day.dayNumber) · \(day.primaryStage)")
                                .font(.cardTitle)
                                .foregroundStyle(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(day.date)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let place = tripNonEmpty(day.placeContext) {
                                HStack(alignment: .center, spacing: Spacing.xs) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .font(.micro)
                                    Text(place)
                                        .font(.micro)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .foregroundStyle(AppColors.textWeak)
                                .accessibilityElement(children: .combine)
                            }

                            if let hikingDayNumber = day.hikingDayNumber {
                                Text("徒步第 \(hikingDayNumber) 天")
                                    .font(.micro)
                                    .foregroundStyle(AppColors.textWeak)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "cloud.sun")
                            .font(.contextTitle)
                            .foregroundStyle(AppColors.interactionPrimary)
                            .accessibilityHidden(true)
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 2),
                        spacing: Spacing.md
                    ) {
                        ForEach(Array(day.weather.fields.enumerated()), id: \.offset) { _, field in
                            TripWeatherField(label: field.label, value: field.value)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#if DEBUG
#Preview("DailyWeatherCard.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.DailyWeatherCard(
            day: TripWeatherDayProjection.default
        )
    }
}

#Preview("DailyWeatherCard.unavailable") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.DailyWeatherCard(
            day: TripWeatherDayProjection.unavailable
        )
    }
}
#endif
