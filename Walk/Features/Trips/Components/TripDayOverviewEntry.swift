import SwiftUI
import WalkData
import WalkDesignSystem

/// 概览日入口投影：只消费冻结事实（日序、日期、徒步日序、当日行程起讫），
/// 不生成日程描述文字。
struct TripDayOverviewEntryProjection: Equatable, Identifiable {
    let tripDayID: String
    let dayNumber: Int
    let date: String
    var hikingDayNumber: Int?
    var totalTrekDays: Int = 0
    /// 冻结行程副标题：徒步日为起讫点名，交通日为接驳起讫链；缺失为 nil。
    var subtitle: String?

    var id: String { tripDayID }
}

/// 业务独立 TripDayOverviewEntry（L2b）：行程概览区的极简自然日安排入口。
/// 整行单一 activate，激活进入 PAGE-TRIP-BROWSE 该自然日的首个分页。
/// 合同见 docs/ui/components/business/components/trip-day-overview-entry/spec.md。
extension TripBusinessComponents {
    struct TripDayOverviewEntry: View {
        let projection: TripDayOverviewEntryProjection
        let onActivate: () -> Void

        var body: some View {
            Button(action: onActivate) {
                HStack(spacing: Spacing.md) {
                    Text("D\(projection.dayNumber)")
                        .font(.sequenceCompact)
                        .foregroundStyle(AppColors.interactionPrimary)
                        .frame(width: 34, height: 34)
                        .background(
                            AppColors.interactionBackground,
                            in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(projection.date)
                            .font(.listTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let subtitle = tripNonEmpty(projection.subtitle) {
                            Text(subtitle)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.ornament(14, weight: .semibold))
                        .foregroundStyle(AppColors.textWeak)
                        .frame(width: 18)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("进入逐日阅读")
        }
    }
}

#if DEBUG
extension TripDayOverviewEntryProjection {
    static let `default` = TripDayOverviewEntryProjection(
        tripDayID: "trip-day-2",
        dayNumber: 2,
        date: "9月8日",
        hikingDayNumber: 1,
        totalTrekDays: 2,
        subtitle: "老榆林 → 下日乌且营地"
    )
}

#Preview("TripDayOverviewEntry.trekDay") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayOverviewEntry(
            projection: TripDayOverviewEntryProjection(
                tripDayID: "day-2",
                dayNumber: 2,
                date: "10月2日",
                hikingDayNumber: 1,
                totalTrekDays: 2,
                subtitle: "老榆林 → 下日乌且营地"
            ),
            onActivate: {}
        )
    }
}

#Preview("TripDayOverviewEntry.transportDay") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripDayOverviewEntry(
            projection: TripDayOverviewEntryProjection(
                tripDayID: "day-1",
                dayNumber: 1,
                date: "10月1日",
                subtitle: "成都东站 → 康定客运站 → 老榆林"
            ),
            onActivate: {}
        )
    }
}
#endif
