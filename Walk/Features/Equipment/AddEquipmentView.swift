import SwiftUI
import WalkData
import WalkDesignSystem

struct EquipmentEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EquipmentEditViewModel

    init(service: any PersonalEquipmentManaging, equipmentID: String? = nil) {
        _viewModel = State(initialValue: EquipmentEditViewModel(service: service, equipmentID: equipmentID))
    }

    var body: some View {
        UtilityPage(
            title: viewModel.state.mode == .create ? "新增一件装备" : "更新装备",
            description: "填写装备名称、分类、类型、拥有数量和可选的单件重量。",
            onBack: requestDismissal,
            bottomFixed: {
                if viewModel.state.isFormAvailable {
                    PrimaryAction(
                        title: viewModel.state.operation == .running(.save) ? "正在保存" : "保存",
                        isLoading: viewModel.state.operation == .running(.save),
                        isDisabled: !viewModel.state.isInputValid,
                        fillsWidth: true,
                        action: save
                    )
                }
            }
        ) {
            pageContent
        }
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(viewModel.state.isDirty)
        .background(
            InteractiveDismissAttemptObserver(isDisabled: viewModel.state.isDirty) {
                _ = viewModel.requestDismissal()
            }
        )
        .overlay {
            if viewModel.state.confirmation == .discard {
                ConfirmationDialog(
                    title: "放弃未保存的修改？",
                    message: "返回后本页修改不会保存。",
                    confirmationTitle: "放弃修改",
                    cancelTitle: "继续编辑",
                    variant: .discard,
                    onCancel: viewModel.cancelConfirmation,
                    onConfirm: {
                        viewModel.discardChanges()
                        dismiss()
                    }
                )
            } else if viewModel.state.confirmation == .deletion,
                      let equipment = viewModel.state.loadedEquipment {
                ConfirmationDialog(
                    title: "删除“\(equipment.name)”？",
                    message: viewModel.state.deletionMessage,
                    confirmationTitle: "确认删除",
                    variant: .danger,
                    isLoading: viewModel.state.operation == .running(.delete),
                    onCancel: viewModel.cancelConfirmation,
                    onConfirm: confirmDeletion
                )
            }
        }
        .task { await viewModel.load() }
        .onDisappear { viewModel.invalidatePendingOperations() }
    }

    @ViewBuilder
    private var pageContent: some View {
        switch viewModel.state.mode {
        case .create:
            formPage
        case .edit:
            switch viewModel.state.loadState {
            case .idle, .loading:
                LoadingView(message: "正在加载装备", variant: .section)
                    .frame(minHeight: 320)
            case .failed:
                ErrorView(message: viewModel.state.errorMessage ?? "装备加载失败", variant: .section) {
                    Task { await viewModel.load() }
                }
                .frame(minHeight: 320)
            case .loaded:
                formPage
            }
        }
    }

    private var formPage: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            PersonalEquipmentForm(
                projection: PersonalEquipmentFormProjection(
                    name: viewModel.state.draft.name,
                    ownedQuantity: viewModel.state.draft.quantityText,
                    unitWeight: viewModel.state.draft.unitWeightGrams,
                    category: viewModel.state.draft.category,
                    equipmentType: viewModel.state.draft.equipmentType,
                    equipmentTypes: EquipmentClassificationOptions.types(for: viewModel.state.draft.category),
                    nameError: viewModel.state.nameFieldError,
                    ownedQuantityError: viewModel.state.quantityFieldError,
                    unitWeightError: viewModel.state.weightFieldError,
                    saveError: viewModel.state.saveErrorMessage,
                    isDisabled: viewModel.state.isMutating
                ),
                onChangeField: updateFormField
            )

            if viewModel.state.mode != .create {
                editOnlyDangerZone
            }
        }
    }

    private func updateFormField(_ field: PersonalEquipmentFormField, _ value: String) {
        switch field {
        case .name: viewModel.updateName(value)
        case .category: viewModel.updateCategory(CatalogEquipmentCategory(rawValue: value))
        case .equipmentType: viewModel.updateEquipmentType(CatalogEquipmentType(rawValue: value))
        case .ownedQuantity: viewModel.updateQuantity(value)
        case .unitWeight: viewModel.updateWeight(value)
        }
    }

    private var editOnlyDangerZone: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let impact = viewModel.state.deletionImpact {
                EquipmentDeletionImpact(impact: impact)
            }

            if let errorMessage = viewModel.state.deletionErrorMessage {
                ErrorView(message: errorMessage, title: "删除失败", variant: .form)
            }

            DangerAction(
                title: viewModel.state.operation == .running(.loadDeletionImpact) ? "正在读取删除影响" : "删除这件装备",
                systemImage: "trash",
                isLoading: viewModel.state.operation == .running(.loadDeletionImpact),
                isDisabled: viewModel.state.isMutating,
                fillsWidth: true
            ) {
                Task { _ = await viewModel.prepareDeletion() }
            }
        }
        .padding(.top, Spacing.lg)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.dangerBorder)
                .frame(height: 1)
        }
    }

    private func requestDismissal() {
        if viewModel.requestDismissal() { dismiss() }
    }

    private func save() {
        Task {
            if await viewModel.save() { dismiss() }
        }
    }

    private func confirmDeletion() {
        Task {
            if await viewModel.deleteEquipment() { dismiss() }
        }
    }
}

private struct InteractiveDismissAttemptObserver: UIViewControllerRepresentable {
    let isDisabled: Bool
    let onAttempt: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isDisabled: isDisabled, onAttempt: onAttempt)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.isDisabled = isDisabled
        context.coordinator.onAttempt = onAttempt
        DispatchQueue.main.async {
            uiViewController.parent?.presentationController?.delegate = context.coordinator
        }
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var isDisabled: Bool
        var onAttempt: () -> Void

        init(isDisabled: Bool, onAttempt: @escaping () -> Void) {
            self.isDisabled = isDisabled
            self.onAttempt = onAttempt
        }

        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool {
            !isDisabled
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            if isDisabled { onAttempt() }
        }
    }
}
