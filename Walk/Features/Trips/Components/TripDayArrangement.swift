import SwiftUI
import WalkData
import WalkDesignSystem

struct TripDayArrangementProjection: Equatable {
    let day: TripDayProjection
    let boundaryCue: String
}

extension TripBusinessComponents {
    struct TripDayArrangement: View {
        let projection: TripDayArrangementProjection

        var body: some View {
            WalkPanel(variant: .default) {
                VStack(spacing: 0) {
                    if let routeSummary = projection.day.dailyRouteSummary {
                        dailyRouteSummary(routeSummary)
                        divider.padding(.vertical, Spacing.md)
                    }

                    ScrollView {
                        VStack(alignment: .leading, spacing: Spacing.xl) {
                            actionSection
                            if !projection.day.points.isEmpty { pointSection }
                            weatherSection
                            Text(projection.boundaryCue)
                                .font(.micro)
                                .foregroundStyle(AppColors.textWeak)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .top)
        }

        private func dailyRouteSummary(_ summary: TripDailyRouteSummaryProjection) -> some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("每日路程")
                    .font(.microStrong)
                    .foregroundStyle(AppColors.textWeak)
                Text(summary.title)
                    .font(.action)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let endpoints = tripNonEmpty(summary.endpoints) {
                    Text(endpoints)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !summary.metrics.isEmpty {
                    MetricGroup(items: summary.metrics, variant: .grid)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var actionSection: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("当天行动")
                    .font(.action)
                    .foregroundStyle(AppColors.textPrimary)
                Timeline(projection.day.actions, optionalTime: \.time) { item in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(item.title)
                            .font(.listTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(Array(item.details.enumerated()), id: \.offset) { _, detail in
                            Text(detail)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(Array(item.notices.enumerated()), id: \.offset) { _, notice in
                            NoticeView(message: notice, tone: .warning)
                        }
                    }
                }
            }
        }

        private var pointSection: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("沿途点位")
                    .font(.action)
                    .foregroundStyle(AppColors.textPrimary)
                VStack(spacing: 0) {
                    ForEach(Array(projection.day.points.enumerated()), id: \.element.id) { index, point in
                        ListRow(
                            variant: .grouped,
                            showsDivider: index < projection.day.points.count - 1
                        ) {
                            HStack(alignment: .top, spacing: Spacing.md) {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(point.title)
                                        .font(.listTitle)
                                        .foregroundStyle(AppColors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    ForEach(Array(point.details.enumerated()), id: \.offset) { _, detail in
                                        Text(detail)
                                            .font(.appCaption)
                                            .foregroundStyle(AppColors.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                if let trailing = tripNonEmpty(point.trailing) {
                                    Text(trailing)
                                        .font(.appCaption)
                                        .foregroundStyle(AppColors.textWeak)
                                }
                            }
                        }
                    }
                }
            }
        }

        private var weatherSection: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("当天行程天气")
                    .font(.action)
                    .foregroundStyle(AppColors.textPrimary)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: 2),
                    spacing: Spacing.md
                ) {
                    ForEach(Array(projection.day.weather.fields.enumerated()), id: \.offset) { _, field in
                        TripWeatherField(label: field.label, value: field.value)
                    }
                }

                if projection.day.weather.hasStaleField {
                    NoticeView(
                        message: "过期状态只作用于对应天气字段，其他内容仍按原值展示。",
                        title: "部分天气可能过期",
                        tone: .stale
                    )
                }
            }
        }

        private var divider: some View {
            Rectangle()
                .fill(AppColors.surfaceDivider)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview("TripDayArrangement.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayArrangement(
            projection: BusinessComponentPreviewFixtures.tripArrangementDefault
        )
        .frame(height: 700)
    }
}

#Preview("TripDayArrangement.transportOnly") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayArrangement(
            projection: BusinessComponentPreviewFixtures.tripArrangementTransportOnly
        )
        .frame(height: 620)
    }
}

#Preview("TripDayArrangement.weatherUnavailable") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayArrangement(
            projection: BusinessComponentPreviewFixtures.tripArrangementWeatherUnavailable
        )
        .frame(height: 700)
    }
}
#endif
