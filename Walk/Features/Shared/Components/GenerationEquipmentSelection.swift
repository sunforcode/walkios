import SwiftUI
import WalkData
import WalkDesignSystem

struct GenerationEquipmentListOptionProjection: Equatable, Identifiable {
    let equipmentListID: String
    let name: String
    let itemCount: Int
    let knownTotalWeightGrams: Double
    let missingWeightItemCount: Int

    var id: String { equipmentListID }
}

struct GenerationEquipmentSelectionProjection: Equatable {
    let equipmentItemCount: Int
    let equipmentListCount: Int
    let knownTotalWeightGrams: Double
    let missingWeightItemCount: Int
    let equipmentLists: [GenerationEquipmentListOptionProjection]
    let selectedEquipmentListID: String?

    var hasPartialWeight: Bool { missingWeightItemCount > 0 }
}

extension SharedBusinessComponents {
    struct GenerationEquipmentSelection: View {
        let projection: GenerationEquipmentSelectionProjection
        let onManageEquipment: () -> Void
        let onSelectEquipmentList: (String?) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(title: "个人装备") {
                    SecondaryAction(
                        title: "管理我的装备",
                        variant: .inline,
                        action: onManageEquipment
                    )
                }

                Text(summaryText)
                    .font(.appBody)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !projection.equipmentLists.isEmpty {
                    FormField(label: "选择一份用户装备清单", requirement: .optional) {
                        Picker(
                            "选择一份用户装备清单",
                            selection: Binding(
                                get: { effectiveSelection },
                                set: { onSelectEquipmentList($0) }
                            )
                        ) {
                            Text("不选择").tag(String?.none)
                            ForEach(projection.equipmentLists) { option in
                                Text(optionSummary(option))
                                    .tag(Optional(option.equipmentListID))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(AppColors.textPrimary)
                    }
                }

                stateNote
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
        }

        private var effectiveSelection: String? {
            guard let id = projection.selectedEquipmentListID,
                  projection.equipmentLists.contains(where: { $0.equipmentListID == id }) else {
                return nil
            }
            return id
        }

        private var summaryText: String {
            var parts = [
                "个人装备 \(projection.equipmentItemCount) 类",
                "装备清单 \(projection.equipmentListCount) 份",
            ]
            if projection.hasPartialWeight {
                parts.append("已知重量 \(weightText(projection.knownTotalWeightGrams))")
                parts.append("\(projection.missingWeightItemCount) 类未计入重量")
            } else {
                parts.append("已知总重量 \(weightText(projection.knownTotalWeightGrams))")
            }
            return parts.joined(separator: " · ")
        }

        @ViewBuilder
        private var stateNote: some View {
            if projection.equipmentItemCount == 0 && projection.equipmentLists.isEmpty {
                Text("个人装备与装备清单均为空，仍可使用标准清单生成行程。")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
                    .fixedSize(horizontal: false, vertical: true)
            } else if projection.equipmentItemCount == 0 {
                Text("尚未维护个人装备，仍可选择装备清单或使用标准清单生成行程。")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
                    .fixedSize(horizontal: false, vertical: true)
            } else if projection.equipmentLists.isEmpty {
                Text("没有装备清单，将使用标准清单作为建议基础，不写入长期资产。")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private func optionSummary(_ option: GenerationEquipmentListOptionProjection) -> String {
            var parts = [option.name, "\(option.itemCount) 类"]
            parts.append("已知重量 \(weightText(option.knownTotalWeightGrams))")
            if option.missingWeightItemCount > 0 {
                parts.append("\(option.missingWeightItemCount) 类未计入")
            }
            return parts.joined(separator: " · ")
        }

        private func weightText(_ grams: Double) -> String {
            grams >= 1_000
                ? "\((Double(grams) / 1_000).formatted(.number.precision(.fractionLength(0...2)))) kg"
                : "\(AccountEquipmentFormatting.decimalText(grams)) g"
        }
    }
}

#if DEBUG
extension GenerationEquipmentSelectionProjection {
    private static let listA = GenerationEquipmentListOptionProjection(
        equipmentListID: "list-a",
        name: "贡嘎西南坡三日夏季清单",
        itemCount: 14,
        knownTotalWeightGrams: 9200,
        missingWeightItemCount: 0
    )

    private static let listB = GenerationEquipmentListOptionProjection(
        equipmentListID: "list-b",
        name: "高海拔垭口穿越轻量化清单",
        itemCount: 11,
        knownTotalWeightGrams: 7400,
        missingWeightItemCount: 2
    )

    private static let listLong = GenerationEquipmentListOptionProjection(
        equipmentListID: "list-long",
        name: "含备用保暖、防潮与应急通讯的长距离多日徒步综合装备清单",
        itemCount: 23,
        knownTotalWeightGrams: 12_600,
        missingWeightItemCount: 4
    )

    static let `default` = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 18,
        equipmentListCount: 2,
        knownTotalWeightGrams: 9800,
        missingWeightItemCount: 0,
        equipmentLists: [GenerationEquipmentSelectionProjection.listA, GenerationEquipmentSelectionProjection.listB],
        selectedEquipmentListID: nil
    )

    static let selected = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 18,
        equipmentListCount: 2,
        knownTotalWeightGrams: 9800,
        missingWeightItemCount: 0,
        equipmentLists: [GenerationEquipmentSelectionProjection.listA, GenerationEquipmentSelectionProjection.listB],
        selectedEquipmentListID: "list-b"
    )

    static let noPersonalEquipment = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 0,
        equipmentListCount: 2,
        knownTotalWeightGrams: 0,
        missingWeightItemCount: 0,
        equipmentLists: [GenerationEquipmentSelectionProjection.listA, GenerationEquipmentSelectionProjection.listB],
        selectedEquipmentListID: nil
    )

    static let noLists = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 18,
        equipmentListCount: 0,
        knownTotalWeightGrams: 9800,
        missingWeightItemCount: 0,
        equipmentLists: [],
        selectedEquipmentListID: nil
    )

    static let empty = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 0,
        equipmentListCount: 0,
        knownTotalWeightGrams: 0,
        missingWeightItemCount: 0,
        equipmentLists: [],
        selectedEquipmentListID: nil
    )

    static let partialWeight = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 18,
        equipmentListCount: 2,
        knownTotalWeightGrams: 7600,
        missingWeightItemCount: 3,
        equipmentLists: [GenerationEquipmentSelectionProjection.listA, GenerationEquipmentSelectionProjection.listB],
        selectedEquipmentListID: nil
    )

    static let long = GenerationEquipmentSelectionProjection(
        equipmentItemCount: 26,
        equipmentListCount: 3,
        knownTotalWeightGrams: 14_200,
        missingWeightItemCount: 5,
        equipmentLists: [GenerationEquipmentSelectionProjection.listLong, GenerationEquipmentSelectionProjection.listA, GenerationEquipmentSelectionProjection.listB],
        selectedEquipmentListID: "list-long"
    )
}

#Preview("GenerationEquipmentSelection.default") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationEquipmentSelection(
            projection: GenerationEquipmentSelectionProjection.default,
            onManageEquipment: {},
            onSelectEquipmentList: { _ in }
        )
    }
}

#Preview("GenerationEquipmentSelection.selected") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationEquipmentSelection(
            projection: GenerationEquipmentSelectionProjection.selected,
            onManageEquipment: {},
            onSelectEquipmentList: { _ in }
        )
    }
}

#Preview("GenerationEquipmentSelection.noPersonalEquipment") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationEquipmentSelection(
            projection: GenerationEquipmentSelectionProjection.noPersonalEquipment,
            onManageEquipment: {},
            onSelectEquipmentList: { _ in }
        )
    }
}

#Preview("GenerationEquipmentSelection.noEquipmentLists") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationEquipmentSelection(
            projection: GenerationEquipmentSelectionProjection.noLists,
            onManageEquipment: {},
            onSelectEquipmentList: { _ in }
        )
    }
}

#Preview("GenerationEquipmentSelection.empty") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationEquipmentSelection(
            projection: GenerationEquipmentSelectionProjection.empty,
            onManageEquipment: {},
            onSelectEquipmentList: { _ in }
        )
    }
}

#Preview("GenerationEquipmentSelection.partialWeight") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationEquipmentSelection(
            projection: GenerationEquipmentSelectionProjection.partialWeight,
            onManageEquipment: {},
            onSelectEquipmentList: { _ in }
        )
    }
}

#Preview("GenerationEquipmentSelection.longContent") {
    BusinessComponentPreviewHost {
        SharedBusinessComponents.GenerationEquipmentSelection(
            projection: GenerationEquipmentSelectionProjection.long,
            onManageEquipment: {},
            onSelectEquipmentList: { _ in }
        )
    }
}
#endif
