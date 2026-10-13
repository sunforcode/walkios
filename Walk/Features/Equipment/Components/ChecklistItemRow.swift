import SwiftUI
import WalkData
import WalkDesignSystem

struct ChecklistItemRowProjection: Identifiable, Equatable {
    let identity: String
    let listIdentity: String
    let listName: String
    let equipmentName: String
    let ownedQuantity: Int
    let quantity: Int
    let unitWeightGrams: Double?

    var id: String { identity }
}

struct ChecklistItemRow: View {
    let projection: ChecklistItemRowProjection
    var isLoading = false
    let onChangeQuantity: (String, Int) -> Void
    let onRemoveMember: (String) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
                .frame(minWidth: 420)
            compactLayout
        }
        .padding(.vertical, Spacing.md)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.surfaceDivider)
                .frame(height: 1)
        }
    }

    private var horizontalLayout: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            copy
                .frame(maxWidth: .infinity, alignment: .leading)
            controls
                .frame(alignment: .trailing)
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            copy
            controls
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(projection.equipmentName)
                .font(.listTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("拥有 \(projection.ownedQuantity) 件")
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(weightSummary)
                .font(.appCaption)
                .foregroundStyle(AppColors.textWeak)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controls: some View {
        VStack(alignment: .trailing, spacing: Spacing.xs) {
            QuantityStepper(
                value: Binding(
                    get: { projection.quantity },
                    set: { onChangeQuantity(projection.identity, $0) }
                ),
                minimum: 1,
                isEnabled: !isLoading,
                accessibilityLabel: "\(projection.listName)中\(projection.equipmentName)的数量"
            )

            Button {
                onRemoveMember(projection.identity)
            } label: {
                Text("移除")
                    .font(.label)
                    .foregroundStyle(AppColors.danger)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .opacity(isLoading ? 0.58 : 1)
            .accessibilityLabel("从\(projection.listName)移除\(projection.equipmentName)")
        }
    }

    private var weightSummary: String {
        guard let grams = projection.unitWeightGrams else {
            return "单件重量未填写 · 该项未计入总重量"
        }
        let unit = AccountEquipmentFormatting.weightText(grams: grams)
        let total = AccountEquipmentFormatting.weightText(grams: grams * Double(projection.quantity))
        return "单件 \(unit) · 行重量 \(total)"
    }
}

#if DEBUG
extension ChecklistItemRowProjection {
    static let knownWeight = ChecklistItemRowProjection(
        identity: "equipment-001",
        listIdentity: "list-001",
        listName: "周末轻装清单",
        equipmentName: "双人轻量帐篷",
        ownedQuantity: 1,
        quantity: 1,
        unitWeightGrams: 1_680
    )

    static let unknownWeight = ChecklistItemRowProjection(
        identity: "equipment-002",
        listIdentity: "list-001",
        listName: "周末轻装清单",
        equipmentName: "应急保温毯",
        ownedQuantity: 3,
        quantity: 2,
        unitWeightGrams: nil
    )

    static let samples = [ChecklistItemRowProjection.knownWeight, ChecklistItemRowProjection.unknownWeight]
}

#Preview("ChecklistItemRow.default") {
    BusinessComponentPreviewHost {
        ChecklistItemRow(
            projection: ChecklistItemRowProjection.knownWeight,
            onChangeQuantity: { _, _ in },
            onRemoveMember: { _ in }
        )
    }
}

#Preview("ChecklistItemRow.unknownWeight") {
    BusinessComponentPreviewHost {
        ChecklistItemRow(
            projection: ChecklistItemRowProjection.unknownWeight,
            onChangeQuantity: { _, _ in },
            onRemoveMember: { _ in }
        )
    }
}

#Preview("ChecklistItemRow.loading") {
    BusinessComponentPreviewHost {
        ChecklistItemRow(
            projection: ChecklistItemRowProjection.knownWeight,
            isLoading: true,
            onChangeQuantity: { _, _ in },
            onRemoveMember: { _ in }
        )
    }
}
#endif
