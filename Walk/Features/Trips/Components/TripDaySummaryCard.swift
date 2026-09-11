import SwiftUI
import WalkData
import WalkDesignSystem

/// 业务组合 TripDaySummaryCard（L2c）：冻结自然日摘要（徽章、接驳、徒步与天气块）。
/// 合同见 docs/ui/components/business/composites/trip-day-summary-card/spec.md。
extension TripBusinessComponents {
    struct TripDaySummaryCard: View {
        let day: TripDayProjection
        let onActivate: (Int) -> Void

        var body: some View {
            Button {
                onActivate(day.dayNumber)
            } label: {
                card
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("进入第 \(day.dayNumber) 天详情")
        }

        private var card: some View {
            WalkCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    dayIdentity

                    if day.hikingDayNumber != nil {
                        TripBusinessComponents.TrekDayBadge(
                            projection: TrekDayBadgeProjection(
                                trekDayNumber: day.hikingDayNumber,
                                totalTrekDays: day.totalTrekDays
                            )
                        )
                    }

                    if let outbound = day.outboundTransport {
                        TripBusinessComponents.TripDayTransportSummary(projection: outbound)
                    }

                    if let hike = day.hikeSummary {
                        TripBusinessComponents.TripDayHikeSummary(projection: hike)
                    }

                    if let returnTransport = day.returnTransport {
                        TripBusinessComponents.TripDayTransportSummary(projection: returnTransport)
                    }

                    weatherBlock
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .appShadow(AppShadow.card)
        }

        private var dayIdentity: some View {
            HStack(alignment: .top, spacing: Spacing.md) {
                Text("D\(day.dayNumber)")
                    .font(.sequenceCompact)
                    .foregroundStyle(AppColors.interactionPrimary)
                    .frame(width: 34, height: 34)
                    .background(
                        AppColors.interactionBackground,
                        in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(day.date)
                        .font(.dateTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(day.primaryStage)
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        /// 天气块：借用本卡投影的非组件块；整体不可用时保留块并显示「暂不可用」。
        private var weatherBlock: some View {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text("天气")
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(weatherStateLabel)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textWeak)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(day.weather.fields.map { $0.value.displayText }.joined(separator: " · "))
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColors.surfaceSoft,
                in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
            )
        }

        private var weatherStateLabel: String {
            if day.weather.fields.allSatisfy({ $0.value.isUnavailable }) {
                return "暂不可用"
            }
            if day.weather.hasStaleField {
                return "信息已过期"
            }
            return "当日摘要"
        }
    }
}

#if DEBUG
#Preview("TripDaySummaryCard.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDaySummaryCard(
            day: BusinessComponentPreviewFixtures.tripDayDefault,
            onActivate: { _ in }
        )
    }
}

#Preview("TripDaySummaryCard.partial") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDaySummaryCard(
            day: BusinessComponentPreviewFixtures.tripDayPartial,
            onActivate: { _ in }
        )
    }
}
#endif
