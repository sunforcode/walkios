import SwiftUI

struct EquipmentDeletionImpact: View {
    let impact: PersonalEquipmentDeletionImpact

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            NoticeView(
                message: impactMessage,
                title: "删除影响",
                icon: "exclamationmark.triangle",
                tone: .danger
            )

            if impact.equipmentListReferenceCount > 0 {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(impact.affectedEquipmentLists.enumerated()), id: \.element.id) { index, list in
                        ListRow(showsDivider: index < impact.affectedEquipmentLists.count - 1) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(list.name)
                                    .font(.listTitle)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("将移除该清单中的装备引用")
                                    .font(.appCaption)
                                    .foregroundStyle(AppColors.textWeak)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
        }
    }

    private var impactMessage: String {
        if impact.equipmentListReferenceCount == 0 {
            return "没有清单引用这件装备；删除不会改变既有行程快照。"
        }
        return "当前有 \(impact.equipmentListReferenceCount) 份装备清单引用这件装备。确认删除后将移除这些清单关系；既有行程快照保留。"
    }
}

#if DEBUG
#Preview("EquipmentDeletionImpact.default") {
    BusinessComponentPreviewHost {
        EquipmentDeletionImpact(impact: BusinessComponentPreviewFixtures.deletionImpact)
    }
}

#Preview("EquipmentDeletionImpact.none") {
    BusinessComponentPreviewHost {
        EquipmentDeletionImpact(impact: BusinessComponentPreviewFixtures.deletionImpactNone)
    }
}
#endif
