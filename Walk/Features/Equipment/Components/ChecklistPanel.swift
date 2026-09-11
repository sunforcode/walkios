import SwiftUI
import WalkData
import WalkDesignSystem

struct EquipmentListSummaryProjection: Identifiable, Equatable {
    let identity: String
    let name: String
    let itemCount: Int
    let knownTotalWeightGrams: Int
    let missingWeightItemCount: Int

    var id: String { identity }
}

struct ChecklistPanel<CandidateContent: View>: View {
    let summary: EquipmentListSummaryProjection
    let isExpanded: Bool
    let members: [ChecklistItemRowProjection]
    var isLoading = false
    let onToggle: (String) -> Void
    let onRename: (String) -> Void
    let onRequestDelete: (String) -> Void
    let onChangeQuantity: (String, Int) -> Void
    let onRemoveMember: (String) -> Void
    private let candidateContent: CandidateContent

    init(
        summary: EquipmentListSummaryProjection,
        isExpanded: Bool,
        members: [ChecklistItemRowProjection],
        isLoading: Bool = false,
        onToggle: @escaping (String) -> Void,
        onRename: @escaping (String) -> Void,
        onRequestDelete: @escaping (String) -> Void,
        onChangeQuantity: @escaping (String, Int) -> Void,
        onRemoveMember: @escaping (String) -> Void,
        @ViewBuilder candidateContent: () -> CandidateContent
    ) {
        self.summary = summary
        self.isExpanded = isExpanded
        self.members = members
        self.isLoading = isLoading
        self.onToggle = onToggle
        self.onRename = onRename
        self.onRequestDelete = onRequestDelete
        self.onChangeQuantity = onChangeQuantity
        self.onRemoveMember = onRemoveMember
        self.candidateContent = candidateContent()
    }

    var body: some View {
        WalkPanel(variant: .default) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                MetricGroup(items: metrics, variant: .grid)
                actions

                if isExpanded {
                    expandedContent
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
            Text(summary.name)
                .font(.listTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(isExpanded ? "收起" : "展开") {
                onToggle(summary.identity)
            }
            .buttonStyle(.plain)
            .font(.label)
            .foregroundStyle(AppColors.interactionPrimary)
            .frame(minHeight: 44)
            .disabled(isLoading)
            .accessibilityValue(isExpanded ? "已展开" : "已折叠")
        }
    }

    private var metrics: [MetricItemModel] {
        let weight = AccountEquipmentFormatting.weightParts(grams: summary.knownTotalWeightGrams)
        return [
            MetricItemModel(id: "items", value: "\(summary.itemCount)", unit: "项", label: "装备条目"),
            MetricItemModel(id: "weight", value: weight.value, unit: weight.unit, label: "已知总重量"),
            MetricItemModel(id: "missing", value: "\(summary.missingWeightItemCount)", unit: "项", label: "未计入重量"),
        ]
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.sm) {
                SecondaryAction(
                    title: "重命名",
                    variant: .inline,
                    isDisabled: isLoading,
                    action: { onRename(summary.identity) }
                )
                DangerAction(
                    title: "删除清单",
                    isDisabled: isLoading,
                    action: { onRequestDelete(summary.identity) }
                )
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                SecondaryAction(
                    title: "重命名",
                    variant: .inline,
                    isDisabled: isLoading,
                    fillsWidth: true,
                    action: { onRename(summary.identity) }
                )
                DangerAction(
                    title: "删除清单",
                    isDisabled: isLoading,
                    fillsWidth: true,
                    action: { onRequestDelete(summary.identity) }
                )
            }
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Rectangle()
                .fill(AppColors.surfaceDivider)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(members) { member in
                    ChecklistItemRow(
                        projection: member,
                        isLoading: isLoading,
                        onChangeQuantity: onChangeQuantity,
                        onRemoveMember: onRemoveMember
                    )
                }
            }

            Text("可加入的个人装备")
                .font(.metricCompactLabel)
                .fontWeight(.bold)
                .tracking(0.9)
                .foregroundStyle(AppColors.textWeak)

            candidateContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

#if DEBUG
#Preview("ChecklistPanel.default") {
    BusinessComponentPreviewHost {
        ChecklistPanel<SecondaryAction>.preview(
            summary: BusinessComponentPreviewFixtures.checklistSummary,
            isExpanded: false,
            members: BusinessComponentPreviewFixtures.checklistMembers
        )
    }
}

#Preview("ChecklistPanel.expanded") {
    BusinessComponentPreviewHost {
        ChecklistPanel<SecondaryAction>.preview(
            summary: BusinessComponentPreviewFixtures.checklistSummary,
            isExpanded: true,
            members: BusinessComponentPreviewFixtures.checklistMembers
        )
    }
}

#Preview("ChecklistPanel.unknownWeight") {
    BusinessComponentPreviewHost {
        ChecklistPanel<SecondaryAction>.preview(
            summary: BusinessComponentPreviewFixtures.checklistUnknownWeightSummary,
            isExpanded: true,
            members: BusinessComponentPreviewFixtures.checklistMembers
        )
    }
}

private extension ChecklistPanel where CandidateContent == SecondaryAction {
    static func preview(
        summary: EquipmentListSummaryProjection,
        isExpanded: Bool,
        members: [ChecklistItemRowProjection]
    ) -> ChecklistPanel<SecondaryAction> {
        ChecklistPanel(
            summary: summary,
            isExpanded: isExpanded,
            members: members,
            onToggle: { _ in },
            onRename: { _ in },
            onRequestDelete: { _ in },
            onChangeQuantity: { _, _ in },
            onRemoveMember: { _ in }
        ) {
            SecondaryAction(title: "添加个人装备", variant: .inline, action: {})
        }
    }
}
#endif
