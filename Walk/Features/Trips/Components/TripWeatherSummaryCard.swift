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
extension TripWeatherSummaryProjection {
    static let `default` = TripWeatherSummaryProjection(
        samples: [
            TripWeatherTrendSampleProjection(id: "d1", date: "09-08", low: 8, high: 16, rain: 0.2),
            TripWeatherTrendSampleProjection(id: "d2", date: "09-09", low: 6, high: 14, rain: 0.45),
        ],
        notice: nil
    )

    static let partial = TripWeatherSummaryProjection(
        samples: [
            TripWeatherTrendSampleProjection(id: "d1", date: "09-08", low: 8, high: 16, rain: 0.2),
        ],
        notice: TripNoticeProjection(
            id: "weather-partial",
            title: "部分天气待确认",
            message: "缺失日期不在趋势图中，其他日期与已知字段不变。",
            tone: .warning
        )
    )

    static let longContent = TripWeatherSummaryProjection(
        samples: [
            TripWeatherTrendSampleProjection(id: "d1", date: "09-08", low: -3, high: 21, rain: 0.65),
            TripWeatherTrendSampleProjection(id: "d2", date: "09-09", low: 2, high: 18, rain: 0.3),
            TripWeatherTrendSampleProjection(id: "d3", date: "09-10", low: 0, high: 12, rain: 0.8),
            TripWeatherTrendSampleProjection(id: "d4", date: "09-11", low: 5, high: 19, rain: 0.1),
            TripWeatherTrendSampleProjection(id: "d5", date: "09-12", low: 7, high: 17, rain: 0.55),
            TripWeatherTrendSampleProjection(id: "d6", date: "09-13", low: 4, high: 15, rain: 0.25),
        ],
        notice: TripNoticeProjection(
            id: "weather-long",
            title: "部分天气可能过期",
            message: "长天气结论完整展示，不以截断或缩小字号隐藏字段状态。",
            tone: .stale
        )
    )
}

#Preview("TripWeatherSummaryCard.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripWeatherSummaryCard(
            projection: TripWeatherSummaryProjection.default,
            onActivate: {}
        )
    }
}

#Preview("TripWeatherSummaryCard.partial") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripWeatherSummaryCard(
            projection: TripWeatherSummaryProjection.partial,
            onActivate: {}
        )
    }
}

#Preview("TripWeatherSummaryCard.longContent") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripWeatherSummaryCard(
            projection: TripWeatherSummaryProjection.longContent,
            onActivate: {}
        )
    }
    .frame(width: 350)
}
#endif
