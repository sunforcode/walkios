import SwiftUI

struct EquipmentEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EquipmentListViewModel
    @State private var name = ""
    @State private var quantity = 1
    @State private var unitWeightGrams = ""
    @State private var showingDeletionConfirmation = false

    private let equipmentID: String?

    init(service: any EquipmentServicing, equipmentID: String? = nil) {
        self.equipmentID = equipmentID
        _viewModel = StateObject(wrappedValue: EquipmentListViewModel(service: service))
    }

    var body: some View {
        EntryFormPage(
            title: equipmentID == nil ? "添加装备" : "编辑装备",
            notice: "名称和拥有数量必填；单件克重可以留空。"
        ) {
            EntryTextField(title: "名称", text: $name)

            Stepper(value: $quantity, in: 1...999) {
                Text("拥有数量：\(quantity)")
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(minHeight: RootNavigation.toolButtonHitSize)
            .accessibilityLabel("拥有数量")
            .accessibilityValue("\(quantity)")

            EntryTextField(title: "单件克重（可选）", text: $unitWeightGrams, keyboardType: .numberPad)

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AppColors.statusCancelled)
            }

            Button(action: save) {
                HStack {
                    if viewModel.isMutating { ProgressView() }
                    Text(equipmentID == nil ? "添加装备" : "保存修改")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: RootNavigation.toolButtonHitSize)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.interactionPrimary)
            .disabled(!isInputValid || viewModel.isMutating)

            if let equipment = viewModel.editingEquipment {
                Button(role: .destructive) {
                    Task {
                        await viewModel.loadDeletionImpact(id: equipment.identity)
                        if viewModel.errorMessage == nil {
                            showingDeletionConfirmation = true
                        }
                    }
                } label: {
                    Text("删除装备")
                        .frame(maxWidth: .infinity, minHeight: RootNavigation.toolButtonHitSize)
                }
                .disabled(viewModel.isMutating)
            }
        }
        .task { await loadEquipmentIfNeeded() }
        .alert("确认删除装备？", isPresented: $showingDeletionConfirmation) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { confirmDeletion() }
        } message: {
            Text(deletionMessage)
        }
    }

    private var parsedWeight: Int? {
        let trimmed = unitWeightGrams.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private var isInputValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && quantity > 0
            && (unitWeightGrams.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (parsedWeight ?? 0) > 0)
    }

    private var deletionMessage: String {
        guard let impact = viewModel.deletionImpact else {
            return "删除后无法恢复。"
        }
        if impact.equipmentListReferenceCount == 0 {
            return "该装备未被清单引用，删除后无法恢复。"
        }
        let names = impact.affectedEquipmentLists.map(\.name).joined(separator: "、")
        return "该装备将从 \(impact.equipmentListReferenceCount) 份清单中移除：\(names)。"
    }

    private func loadEquipmentIfNeeded() async {
        guard let equipmentID else { return }
        await viewModel.loadEquipment(id: equipmentID)
        guard let equipment = viewModel.editingEquipment else { return }
        name = equipment.name
        quantity = equipment.ownedQuantity
        unitWeightGrams = equipment.unitWeight.map { String($0.grams) } ?? ""
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            if let equipment = viewModel.editingEquipment {
                let weightUpdate: PersonalEquipmentUpdateField<EquipmentWeight>
                if let parsedWeight {
                    weightUpdate = .value(EquipmentWeight(grams: parsedWeight))
                } else if equipment.unitWeight != nil {
                    weightUpdate = .clear
                } else {
                    weightUpdate = .unchanged
                }
                await viewModel.updateEquipment(
                    id: equipment.identity,
                    update: PersonalEquipmentUpdate(
                        name: trimmedName,
                        ownedQuantity: quantity,
                        unitWeight: weightUpdate
                    )
                )
            } else {
                await viewModel.createEquipment(
                    name: trimmedName,
                    ownedQuantity: quantity,
                    unitWeightGrams: parsedWeight
                )
            }
            if viewModel.lastMutationSucceeded { dismiss() }
        }
    }

    private func confirmDeletion() {
        guard let equipment = viewModel.editingEquipment else { return }
        Task {
            await viewModel.deleteEquipment(id: equipment.identity)
            if viewModel.lastMutationSucceeded { dismiss() }
        }
    }
}
