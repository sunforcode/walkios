import SwiftUI

struct TripWeatherSummaryProjection: Equatable {
    let days: [TripWeatherDayProjection]
    var notice: TripNoticeProjection?
}

extension TripBusinessComponents {
    struct TripWeatherSummaryCard: View {
        let projection: TripWeatherSummaryProjection
        let onActivate: () -> Void

        var body: some View {
            Button(action: onActivate) {
                WalkCard {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                            Text("行程天气")
                                .font(.sectionTitle)
                                .foregroundStyle(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            Text("\(projection.days.count) 个自然日")
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textWeak)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let notice = projection.notice {
                            NoticeView(
                                message: notice.message,
                                title: notice.title,
                                tone: notice.tone.noticeTone
                            )
                        }

                        VStack(spacing: 0) {
                            ForEach(projection.days) { day in
                                Rectangle()
                                    .fill(AppColors.surfaceDivider)
                                    .frame(height: 1)
                                    .accessibilityHidden(true)
                                dayRow(day)
                            }
                        }
                    }
                    .padding(.trailing, Spacing.xl)
                    .overlay(alignment: .trailing) {
                        Image(systemName: "chevron.right")
                            .font(.contextTitle)
                            .foregroundStyle(AppColors.textWeak)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("进入行程天气")
        }

        private func dayRow(_ day: TripWeatherDayProjection) -> some View {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Spacing.md) {
                    dayNumber(day)
                    conclusion(day)
                    date(day)
                }

                HStack(alignment: .top, spacing: Spacing.md) {
                    dayNumber(day)
                        .frame(width: 36, alignment: .leading)
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        conclusion(day)
                        date(day)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        }

        private func dayNumber(_ day: TripWeatherDayProjection) -> some View {
            Text("D\(day.dayNumber)")
                .font(.bodyEmphasis)
                .foregroundStyle(AppColors.interactionPrimary)
                .frame(width: 44, alignment: .leading)
        }

        private func conclusion(_ day: TripWeatherDayProjection) -> some View {
            Text(day.weather.conclusion)
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        private func date(_ day: TripWeatherDayProjection) -> some View {
            Text(day.date)
                .font(.appCaption)
                .foregroundStyle(AppColors.textWeak)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
#Preview("TripWeatherSummaryCard.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripWeatherSummaryCard(
            projection: BusinessComponentPreviewFixtures.tripWeatherDefault,
            onActivate: {}
        )
    }
}

#Preview("TripWeatherSummaryCard.partial") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripWeatherSummaryCard(
            projection: BusinessComponentPreviewFixtures.tripWeatherPartial,
            onActivate: {}
        )
    }
}

#Preview("TripWeatherSummaryCard.longContent") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripWeatherSummaryCard(
            projection: BusinessComponentPreviewFixtures.tripWeatherLongContent,
            onActivate: {}
        )
    }
    .frame(width: 350)
}
#endif
