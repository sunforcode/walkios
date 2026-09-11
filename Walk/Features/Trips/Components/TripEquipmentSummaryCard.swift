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
        let projection: TripEquipmentSummaryProjection
        let onActivate: () -> Void

        var body: some View {
            Button(action: onActivate) {
                WalkCard {
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
                            Text(projection.knownTotalWeight)
                                .font(.displayTitle)
                                .foregroundStyle(AppColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(weightDescription)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("数量基于本次行程清单，未确认不等于缺少")
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textWeak)
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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("进入行程装备")
        }

        private var weightDescription: String {
            projection.missingWeightItemCount == 0
                ? "预计总重量"
                : "已知重量 · \(projection.missingWeightItemCount) 项未计入"
        }
    }
}

#if DEBUG
#Preview("TripEquipmentSummaryCard.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: BusinessComponentPreviewFixtures.tripEquipmentDefault,
            onActivate: {}
        )
    }
}

#Preview("TripEquipmentSummaryCard.partialWeight") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: BusinessComponentPreviewFixtures.tripEquipmentPartialWeight,
            onActivate: {}
        )
    }
}

#Preview("TripEquipmentSummaryCard.readonly") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentSummaryCard(
            projection: BusinessComponentPreviewFixtures.tripEquipmentSummaryReadonly,
            onActivate: {}
        )
    }
}
#endif
