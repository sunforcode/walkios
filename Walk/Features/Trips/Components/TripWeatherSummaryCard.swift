import SwiftUI
import WalkData
import WalkDesignSystem

/// 业务组件 TripWeatherSummaryCard（L2b）：逐日气温降水趋势图 + 行程天气入口。
/// 合同见 docs/ui/components/business/components/trip-weather-summary-card/spec.md。
struct TripWeatherSummaryProjection: Equatable {
    let samples: [TripWeatherTrendSampleProjection]
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
                            Text("\(projection.samples.count) 日结果")
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

                        TripBusinessComponents.TripWeatherTrendChart(samples: projection.samples)
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
