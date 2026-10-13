import SwiftUI
import WalkData
import WalkDesignSystem

enum TripEquipmentItemSourceProjection: String, Equatable {
    case systemSuggestion = "system_suggestion"
    case userAdjusted = "user_adjusted"
    case userAdded = "user_added"

    var label: String {
        switch self {
        case .systemSuggestion: "系统建议"
        case .userAdjusted: "已调整建议"
        case .userAdded: "用户添加"
        }
    }
}

enum TripEquipmentOwnershipStatusProjection: String, Equatable {
    case owned
    case unconfirmedOwned = "unconfirmed_owned"
    case notApplicable = "not_applicable"

    var label: String {
        switch self {
        case .owned: "已有"
        case .unconfirmedOwned: "未确认已有"
        case .notApplicable: "不适用"
        }
    }
}

struct TripEquipmentItemRowProjection: Equatable, Identifiable {
    let identity: String
    let name: String
    let quantity: Int
    let unitWeightGrams: Double?
    let note: String?
    let source: TripEquipmentItemSourceProjection
    let ownershipStatus: TripEquipmentOwnershipStatusProjection
    let editable: Bool

    var id: String { identity }

    var unitWeightText: String? {
        unitWeightGrams.map { AccountEquipmentFormatting.weightText(grams: $0) }
    }

    var totalWeightText: String? {
        guard let grams = unitWeightGrams else { return nil }
        return AccountEquipmentFormatting.weightText(grams: grams * Double(quantity))
    }
}

extension TripBusinessComponents {
    struct TripEquipmentItemRow: View {
        let projection: TripEquipmentItemRowProjection
        let onRequestEdit: (String) -> Void
        let onRequestDelete: (String) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header

                weightSummary

                if let note = projection.note, !note.isEmpty {
                    Text(note)
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(ownershipExplanation)
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
                    .fixedSize(horizontal: false, vertical: true)

                if projection.editable {
                    actions
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilityText)
        }

        private var header: some View {
            HStack(alignment: .top, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(projection.name)
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("数量 \(projection.quantity)")
                        .font(.appCaption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text(projection.source.label)
                        .font(.micro)
                        .foregroundStyle(AppColors.textWeak)
                    Text(projection.ownershipStatus.label)
                        .font(.micro)
                        .foregroundStyle(
                            projection.ownershipStatus == .unconfirmedOwned
                                ? AppColors.warning
                                : AppColors.textWeak
                        )
                }
            }
        }

        @ViewBuilder
        private var weightSummary: some View {
            if let unitWeightText = projection.unitWeightText,
               let totalWeightText = projection.totalWeightText {
                Text("单件 \(unitWeightText) · 合计 \(totalWeightText)")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("重量未填写 · 未计入总重量")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private var ownershipExplanation: String {
            switch projection.ownershipStatus {
            case .owned: "已在个人装备中确认拥有。"
            case .unconfirmedOwned: "尚未确认是否拥有，不代表缺少。"
            case .notApplicable: "本次补给不参与个人装备拥有状态核对。"
            }
        }

        private var actions: some View {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.sm) {
                    SecondaryAction(
                        title: "修改",
                        variant: .inline,
                        fillsWidth: true,
                        action: { onRequestEdit(projection.identity) }
                    )
                    .accessibilityLabel("修改\(projection.name)")

                    DangerAction(
                        title: "删除",
                        fillsWidth: true,
                        action: { onRequestDelete(projection.identity) }
                    )
                    .accessibilityLabel("删除\(projection.name)")
                }
                VStack(spacing: Spacing.sm) {
                    SecondaryAction(
                        title: "修改",
                        variant: .inline,
                        fillsWidth: true,
                        action: { onRequestEdit(projection.identity) }
                    )
                    .accessibilityLabel("修改\(projection.name)")

                    DangerAction(
                        title: "删除",
                        fillsWidth: true,
                        action: { onRequestDelete(projection.identity) }
                    )
                    .accessibilityLabel("删除\(projection.name)")
                }
            }
        }

        private var accessibilityText: String {
            var parts = [
                "\(projection.name)，本次数量 \(projection.quantity)",
                projection.ownershipStatus.label,
                projection.source.label,
            ]
            if let unitWeightText = projection.unitWeightText,
               let totalWeightText = projection.totalWeightText {
                parts.append("单件 \(unitWeightText)，该项合计 \(totalWeightText)")
            } else {
                parts.append("重量未填写，未计入总重量")
            }
            if let note = projection.note, !note.isEmpty {
                parts.append(note)
            }
            if projection.editable {
                parts.append("可修改或删除")
            }
            return parts.joined(separator: "，")
        }
    }
}

#if DEBUG
extension TripEquipmentItemRowProjection {
    static let `default` = TripEquipmentItemRowProjection(
        identity: "trip-equipment-default",
        name: "双人帐篷",
        quantity: 1,
        unitWeightGrams: 1800,
        note: nil,
        source: .systemSuggestion,
        ownershipStatus: .owned,
        editable: true
    )

    static let userAdjusted = TripEquipmentItemRowProjection(
        identity: "trip-equipment-adjusted",
        name: "饮水与水袋",
        quantity: 2,
        unitWeightGrams: 1250,
        note: nil,
        source: .userAdjusted,
        ownershipStatus: .owned,
        editable: true
    )

    static let userAdded = TripEquipmentItemRowProjection(
        identity: "trip-equipment-added",
        name: "个人急救包",
        quantity: 1,
        unitWeightGrams: nil,
        note: nil,
        source: .userAdded,
        ownershipStatus: .unconfirmedOwned,
        editable: true
    )

    static let unknownWeight = TripEquipmentItemRowProjection(
        identity: "trip-equipment-unknown",
        name: "备用保温毯",
        quantity: 1,
        unitWeightGrams: nil,
        note: nil,
        source: .systemSuggestion,
        ownershipStatus: .unconfirmedOwned,
        editable: true
    )

    static let withNote = TripEquipmentItemRowProjection(
        identity: "trip-equipment-note",
        name: "零度睡袋",
        quantity: 1,
        unitWeightGrams: 1200,
        note: "舒适温标 0℃，垭口日搭配羽绒内胆使用。",
        source: .systemSuggestion,
        ownershipStatus: .owned,
        editable: true
    )

    static let readonly = TripEquipmentItemRowProjection(
        identity: "trip-equipment-readonly",
        name: "充气防潮垫",
        quantity: 1,
        unitWeightGrams: 500,
        note: nil,
        source: .userAdjusted,
        ownershipStatus: .owned,
        editable: false
    )

    static let long = TripEquipmentItemRowProjection(
        identity: "trip-equipment-long",
        name: "含备用保暖、防潮与应急通讯的长距离多日徒步综合装备组合",
        quantity: 3,
        unitWeightGrams: 2400,
        note: "含羽绒内胆、防潮坐垫与卫星通讯模块；出发前确认电池与备用充电方案。",
        source: .userAdjusted,
        ownershipStatus: .unconfirmedOwned,
        editable: true
    )
}

#Preview("TripEquipmentItemRow.default") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentItemRow(
            projection: TripEquipmentItemRowProjection.default,
            onRequestEdit: { _ in },
            onRequestDelete: { _ in }
        )
    }
}

#Preview("TripEquipmentItemRow.userAdjusted") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentItemRow(
            projection: TripEquipmentItemRowProjection.userAdjusted,
            onRequestEdit: { _ in },
            onRequestDelete: { _ in }
        )
    }
}

#Preview("TripEquipmentItemRow.userAdded") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentItemRow(
            projection: TripEquipmentItemRowProjection.userAdded,
            onRequestEdit: { _ in },
            onRequestDelete: { _ in }
        )
    }
}

#Preview("TripEquipmentItemRow.unknownWeight") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentItemRow(
            projection: TripEquipmentItemRowProjection.unknownWeight,
            onRequestEdit: { _ in },
            onRequestDelete: { _ in }
        )
    }
}

#Preview("TripEquipmentItemRow.withNote") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentItemRow(
            projection: TripEquipmentItemRowProjection.withNote,
            onRequestEdit: { _ in },
            onRequestDelete: { _ in }
        )
    }
}

#Preview("TripEquipmentItemRow.readonly") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentItemRow(
            projection: TripEquipmentItemRowProjection.readonly,
            onRequestEdit: { _ in },
            onRequestDelete: { _ in }
        )
    }
}

#Preview("TripEquipmentItemRow.longContent") {
    BusinessComponentPreviewHost {
        TripBusinessComponents.TripEquipmentItemRow(
            projection: TripEquipmentItemRowProjection.long,
            onRequestEdit: { _ in },
            onRequestDelete: { _ in }
        )
    }
}
#endif
