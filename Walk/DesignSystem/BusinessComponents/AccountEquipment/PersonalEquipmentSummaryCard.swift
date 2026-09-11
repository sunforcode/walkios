import SwiftUI

struct PersonalEquipmentSummaryCard: View {
    let summary: PersonalEquipmentSummary
    let onActivate: () -> Void

    var body: some View {
        Button(action: onActivate) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                MetricGroup(items: metrics, variant: .grid)

                if summary.equipmentItemCount == 0 {
                    Text("尚未维护个人装备")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textWeak)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                LinearGradient(
                    colors: [AppColors.surfacePrimary, AppColors.sceneForestMiddle],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint("进入我的装备")
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "backpack")
                .font(.navTitle)
                .foregroundStyle(AppColors.interactionPrimary)
                .frame(width: 36, height: 36)
                .background(AppColors.interactionBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("我的装备")
                    .font(.listTitle)
                    .foregroundStyle(AppColors.textPrimary)
                Text("长期装备资产与自建清单")
                    .font(.metricCompactLabel)
                    .foregroundStyle(AppColors.textWeak)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.appCaption)
                .foregroundStyle(AppColors.textWeak)
                .accessibilityHidden(true)
        }
    }

    private var metrics: [MetricItemModel] {
        let weight = AccountEquipmentFormatting.weightParts(grams: summary.knownTotalWeight.grams)
        return [
            MetricItemModel(id: "equipment", value: "\(summary.equipmentItemCount)", unit: "项", label: "装备总数"),
            MetricItemModel(id: "lists", value: "\(summary.equipmentListCount)", unit: "份", label: "装备清单数"),
            MetricItemModel(id: "weight", value: weight.value, unit: weight.unit, label: "已知总重量"),
            MetricItemModel(id: "missing", value: "\(summary.missingWeightItemCount)", unit: "项", label: "未填写重量"),
        ]
    }

    private var accessibilitySummary: String {
        let weight = AccountEquipmentFormatting.weightText(grams: summary.knownTotalWeight.grams)
        return "我的装备，装备总数 \(summary.equipmentItemCount) 项，装备清单数 \(summary.equipmentListCount) 份，已知总重量 \(weight)，未填写重量 \(summary.missingWeightItemCount) 项"
    }
}

#if DEBUG
#Preview("PersonalEquipmentSummaryCard.default") {
    BusinessComponentPreviewHost {
        PersonalEquipmentSummaryCard(
            summary: BusinessComponentPreviewFixtures.personalEquipmentSummary,
            onActivate: {}
        )
    }
}

#Preview("PersonalEquipmentSummaryCard.empty") {
    BusinessComponentPreviewHost {
        PersonalEquipmentSummaryCard(
            summary: BusinessComponentPreviewFixtures.personalEquipmentSummaryEmpty,
            onActivate: {}
        )
    }
}
#endif
