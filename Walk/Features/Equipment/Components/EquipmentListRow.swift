import Foundation
import SwiftUI
import WalkData
import WalkDesignSystem

struct PersonalEquipmentRowProjection: Equatable {
    let identity: String
    let name: String
    let ownedQuantity: Int
    let unitWeightGrams: Double?
}

enum EquipmentListRowProjection: Equatable {
    case personalAsset(PersonalEquipmentRowProjection)
}

struct EquipmentListRow: View {
    let projection: EquipmentListRowProjection
    let onActivate: (String) -> Void
    let onEdit: (String) -> Void
    let onDelete: (String) -> Void

    var body: some View {
        switch projection {
        case .personalAsset(let item):
            personalAsset(item)
        }
    }

    private func personalAsset(_ item: PersonalEquipmentRowProjection) -> some View {
        Button {
            onActivate(item.identity)
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "backpack")
                    .font(.navTitle)
                    .foregroundStyle(AppColors.interactionPrimary)
                    .frame(width: 42, height: 42)
                    .background(AppColors.interactionBackground)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(item.name)
                        .font(.listTitle)
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("拥有 \(item.ownedQuantity) 件 · \(personalWeightText(item))")
                        .font(.micro)
                        .foregroundStyle(AppColors.textWeak)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("编辑")
                    .font(.label)
                    .foregroundStyle(AppColors.textWeak)
                    .accessibilityHidden(true)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("编辑个人装备")
    }

    private func personalWeightText(_ item: PersonalEquipmentRowProjection) -> String {
        item.unitWeightGrams.map { "单件 \(AccountEquipmentFormatting.weightText(grams: $0))" } ?? "单件重量未填写"
    }
}

#if DEBUG
#Preview("EquipmentListRow.personalAsset") {
    BusinessComponentPreviewHost {
        EquipmentListRow.preview(BusinessComponentPreviewFixtures.personalEquipmentRow)
    }
}

private extension EquipmentListRow {
    static func preview(_ projection: EquipmentListRowProjection) -> EquipmentListRow {
        EquipmentListRow(
            projection: projection,
            onActivate: { _ in },
            onEdit: { _ in },
            onDelete: { _ in }
        )
    }
}
#endif
