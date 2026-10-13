import SwiftUI
import WalkData
import WalkDesignSystem

struct TripCalendarCardProjection: Equatable {
    let days: [TripHeatmapDayProjection]
    var emptyHint: String?
}

extension SharedBusinessComponents {
    struct TripCalendarCard: View {
        let projection: TripCalendarCardProjection
        let onActivate: () -> Void

        var body: some View {
            Button(action: onActivate) {
                WalkCard {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                            Text("行程日历")
                                .font(.listTitle)
                                .foregroundStyle(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)

                            Text("查看全部")
                                .font(.microStrong)
                                .foregroundStyle(AppColors.interactionPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text("最近一年 · 热点仅展示日期分布")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        SharedBusinessComponents.HeatmapCalendar(days: projection.days)

                        if let emptyHint = tripNonEmpty(projection.emptyHint) {
                            Text(emptyHint)
                                .font(.micro)
                                .foregroundStyle(AppColors.textWeak)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("查看全部行程")
        }
    }
}

#if DEBUG
extension TripCalendarCardProjection {
    private static let sampleDays: [TripHeatmapDayProjection] = TripHeatmapDayProjection.sampleBusinessDates.enumerated().map { index, date in
        TripHeatmapDayProjection(
            businessDate: date,
            level: index.isMultiple(of: 53) ? (index.isMultiple(of: 106) ? .medium : .low) : .empty
        )
    }

    static let `default` = TripCalendarCardProjection(
        days: TripCalendarCardProjection.sampleDays,
        emptyHint: nil
    )

    static let empty = TripCalendarCardProjection(
        days: TripHeatmapDayProjection.emptyYear,
        emptyHint: "过去 365 天还没有个人行程"
    )
}

#Preview("TripCalendarCard.default") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.TripCalendarCard(
            projection: TripCalendarCardProjection.default,
            onActivate: {}
        )
    }
}

#Preview("TripCalendarCard.empty") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.TripCalendarCard(
            projection: TripCalendarCardProjection.empty,
            onActivate: {}
        )
    }
}
#endif
