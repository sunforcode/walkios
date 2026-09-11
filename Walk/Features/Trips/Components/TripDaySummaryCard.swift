import SwiftUI

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

                    Timeline(day.actions, optionalTime: \.time) { item in
                        actionContent(item)
                    }

                    if !day.points.isEmpty {
                        divider
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(day.points.enumerated()), id: \.element.id) { index, point in
                                pointRow(point)
                                if index < day.points.count - 1 { divider }
                            }
                        }
                    }

                    divider
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("天气")
                            .font(.listTitle)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(day.weather.conclusion)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                        .font(.micro)
                        .foregroundStyle(AppColors.textWeak)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        private func actionContent(_ item: TripTimelineItemProjection) -> some View {
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
                    Text(notice)
                        .foregroundStyle(AppColors.warning)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }

        private func pointRow(_ point: TripPointProjection) -> some View {
            ListRow(variant: .grouped) {
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
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
