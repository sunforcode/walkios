import SwiftUI
import WalkData
import WalkDesignSystem

struct TripEquipmentSummaryProjection: Equatable {
    let knownTotalWeight: String
    let itemCount: Int
    let ownedItemCount: Int
    let unconfirmedOwnedItemCount: Int
    let missingWeightItemCount: Int
    let editable: Bool

    var gearRings: TripEquipmentGearRingsProjection {
        TripEquipmentGearRingsProjection(
            itemCount: itemCount,
            ownedItemCount: ownedItemCount,
            unconfirmedOwnedItemCount: unconfirmedOwnedItemCount
        )
    }
}

extension TripBusinessComponents {
    struct TripEquipmentSummaryCard: View {
        enum Presentation {
            case standard
            case compact
            case dashboard
            case icon
        }

        let projection: TripEquipmentSummaryProjection
        var presentation: Presentation = .standard
        let onActivate: () -> Void

        var body: some View {
            Button(action: onActivate) {
                cardContent
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("进入行程装备")
            .accessibilityIdentifier("trip-equipment-summary")
        }

        @ViewBuilder
        private var cardContent: some View {
            switch presentation {
            case .standard:
                WalkCard { standardContent }
            case .compact:
                WalkCard { compactContent }
            case .dashboard:
                dashboardContent
            case .icon:
                Image(systemName: "backpack")
                    .font(.contextTitle)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: Spacing.navBarHeight, height: Spacing.navBarHeight)
                    .accessibilityHidden(true)
            }
        }

        private var dashboardContent: some View {
            HStack(alignment: .center, spacing: Spacing.sm) {
                Image(systemName: "backpack")
                    .font(.action)
                    .foregroundStyle(AppColors.interactionPrimary)
                    .frame(width: Spacing.lg)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(projection.knownTotalWeight + (projection.missingWeightItemCount > 0 ? "*" : ""))
                        .font(.metricCompactValue)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(projection.itemCount) 件" + (projection.editable ? "" : " · 只读"))
                        .font(.micro)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.sm)
            .frame(minWidth: 108, minHeight: 48, alignment: .leading)
            .background(AppColors.surfaceControlOverlay, in: RoundedRectangle(cornerRadius: Radius.md))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(AppColors.borderOverlay, lineWidth: 1)
            }
        }

        private var standardContent: some View {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                HStack(alignment: .top, spacing: Spacing.md) {
                    Text("行程装备")
                        .font(.sectionTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    InfoTag(
                        title: projection.editable ? "可编辑" : "只读",
                        tone: projection.editable ? .info : .neutral
                    )
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(weightSummaryLine)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TripBusinessComponents.TripEquipmentGearRings(
                    projection: projection.gearRings
                )
            }
            .padding(.trailing, Spacing.xl)
            .overlay(alignment: .trailing) {
                Image(systemName: "chevron.right")
                    .font(.contextTitle)
                    .foregroundStyle(AppColors.textWeak)
                    .accessibilityHidden(true)
            }
        }

        private var compactContent: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text("行程装备")
                            .font(.listTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.micro)
                            .foregroundStyle(AppColors.textWeak)
                            .accessibilityHidden(true)
                    }
                    Text(projection.editable ? "可编辑" : "只读")
                        .font(.micro)
                        .foregroundStyle(AppColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(projection.missingWeightItemCount == 0 ? "预计总重量" : "已知重量")
                        .font(.micro)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(projection.knownTotalWeight)
                        .font(.metricValue)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if projection.missingWeightItemCount > 0 {
                        Text("\(projection.missingWeightItemCount) 项未计入")
                            .font(.micro)
                            .foregroundStyle(AppColors.textWeak)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    compactCount("清单", value: projection.itemCount)
                    compactCount("已有", value: projection.ownedItemCount)
                    compactCount("未确认", value: projection.unconfirmedOwnedItemCount)
                }

                Text("数量基于本次行程清单，未确认不等于缺少")
                    .font(.micro)
                    .foregroundStyle(AppColors.textWeak)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private func compactCount(_ title: String, value: Int) -> some View {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(title)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text("\(value)")
                    .font(.metricCompactValue)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        /// 重量语义与同段范围说明合并为单行说明。
        private var weightSummaryLine: String {
            let weightPart = projection.missingWeightItemCount == 0
                ? "预计总重量 \(projection.knownTotalWeight)"
                : "已知重量 \(projection.knownTotalWeight) · \(projection.missingWeightItemCount) 项未计入"
            return "\(weightPart) · 数量基于本次行程清单，未确认不等于缺少"
        }

        private var accessibilitySummary: String {
            "行程装备，\(projection.editable ? "可编辑" : "只读")，\(weightSummaryLine)，清单 \(projection.itemCount) 项，已有 \(projection.ownedItemCount) 项，未确认 \(projection.unconfirmedOwnedItemCount) 项"
        }
    }
}

#if DEBUG
extension TripEquipmentSummaryProjection {
    static let `default` = TripEquipmentSummaryProjection(
        knownTotalWeight: "8.42 kg",
        itemCount: 12,
        ownedItemCount: 10,
        unconfirmedOwnedItemCount: 2,
        missingWeightItemCount: 0,
        editable: true
    )

    static let partialWeight = TripEquipmentSummaryProjection(
        knownTotalWeight: "7.96 kg",
        itemCount: 12,
        ownedItemCount: 9,
        unconfirmedOwnedItemCount: 3,
        missingWeightItemCount: 2,
        editable: true
    )

    static let readonly = TripEquipmentSummaryProjection(
        knownTotalWeight: "8.42 kg",
        itemCount: 12,
        ownedItemCount: 10,
        unconfirmedOwnedItemCount: 2,
        missingWeightItemCount: 0,
        editable: false
    )
}

#Preview("TripEquipmentSummaryCard.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.default,
            onActivate: {}
        )
    }
}

#Preview("TripEquipmentSummaryCard.partialWeight") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.partialWeight,
            onActivate: {}
        )
    }
}

#Preview("TripEquipmentSummaryCard.readonly") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.readonly,
            onActivate: {}
        )
    }
}

#Preview("TripEquipmentSummaryCard.compact") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.default,
            presentation: .compact,
            onActivate: {}
        )
        .frame(width: 140)
    }
}

#Preview("TripEquipmentSummaryCard.compactPartialWeight") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.partialWeight,
            presentation: .compact,
            onActivate: {}
        )
        .frame(width: 140)
    }
}

#Preview("TripEquipmentSummaryCard.compactReadonly") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.readonly,
            presentation: .compact,
            onActivate: {}
        )
        .frame(width: 140)
    }
}

#Preview("TripEquipmentSummaryCard.dashboard") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.default,
            presentation: .dashboard,
            onActivate: {}
        )
        .frame(width: 108)
    }
}

#Preview("TripEquipmentSummaryCard.dashboardPartialWeight") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.partialWeight,
            presentation: .dashboard,
            onActivate: {}
        )
        .frame(width: 108)
    }
}

#Preview("TripEquipmentSummaryCard.dashboardReadonly") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.readonly,
            presentation: .dashboard,
            onActivate: {}
        )
        .frame(width: 108)
    }
}

#Preview("TripEquipmentSummaryCard.icon") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.default,
            presentation: .icon,
            onActivate: {}
        )
    }
}

#Preview("TripEquipmentSummaryCard.iconPartialWeight") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.partialWeight,
            presentation: .icon,
            onActivate: {}
        )
    }
}

#Preview("TripEquipmentSummaryCard.iconReadonly") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: TripEquipmentSummaryProjection.readonly,
            presentation: .icon,
            onActivate: {}
        )
    }
}
#endif
