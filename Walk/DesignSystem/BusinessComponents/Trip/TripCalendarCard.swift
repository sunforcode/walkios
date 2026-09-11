import SwiftUI

struct TripCalendarCardProjection: Equatable {
    let days: [TripHeatmapDayProjection]
    var emptyHint: String?
}

extension TripBusinessComponents {
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

                        Text("过去连续 365 个业务日期的行程分布")
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        TripBusinessComponents.HeatmapCalendar(days: projection.days)

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
#Preview("TripCalendarCard.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripCalendarCard(
            projection: BusinessComponentPreviewFixtures.tripCalendarDefault,
            onActivate: {}
        )
    }
}

#Preview("TripCalendarCard.empty") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripCalendarCard(
            projection: BusinessComponentPreviewFixtures.tripCalendarEmpty,
            onActivate: {}
        )
    }
}
#endif
