import SwiftUI

enum EquipmentEditMode: Equatable {
    case create
    case edit(equipmentID: String)

    init(equipmentID: String?) {
        if let equipmentID {
            self = .edit(equipmentID: equipmentID)
        } else {
            self = .create
        }
    }
}

struct EquipmentEditFormValues: Equatable {
    let name: String
    let ownedQuantity: Int
    let unitWeightGrams: String

    static let empty = EquipmentEditFormValues(name: "", ownedQuantity: 1, unitWeightGrams: "")
}

enum EquipmentEditPresentation {
    static func isDirty(current: EquipmentEditFormValues, initial: EquipmentEditFormValues) -> Bool {
        canonical(current) != canonical(initial)
    }

    private static func canonical(_ values: EquipmentEditFormValues) -> EquipmentEditFormValues {
        EquipmentEditFormValues(
            name: values.name.trimmingCharacters(in: .whitespacesAndNewlines),
            ownedQuantity: values.ownedQuantity,
            unitWeightGrams: values.unitWeightGrams.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}

private enum EquipmentEditMutationIntent {
    case save
    case loadDeletionImpact
    case delete
}

struct EquipmentEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EquipmentListViewModel
    @State private var name = ""
    @State private var quantityText = "1"
    @State private var unitWeightGrams = ""
    @State private var initialFormValues = EquipmentEditFormValues.empty
    @State private var isNameFieldTouched = false
    @State private var isQuantityFieldTouched = false
    @State private var isWeightFieldTouched = false
    @State private var showingDeletionConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var mutationIntent: EquipmentEditMutationIntent?
    @State private var failedMutationIntent: EquipmentEditMutationIntent?

    private let equipmentID: String?

    init(service: any EquipmentServicing, equipmentID: String? = nil) {
        self.equipmentID = equipmentID
        _viewModel = StateObject(wrappedValue: EquipmentListViewModel(service: service))
    }

    var body: some View {
        UtilityPageContainer {
            VStack(spacing: 0) {
                UtilityNavigationHeader(
                    title: mode == .create ? "新增个人装备" : "编辑个人装备",
                    leading: IconButtonConfiguration(
                        systemName: "chevron.left",
                        accessibilityLabel: "返回",
                        action: requestDismissal
                    )
                )
                pageContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if isFormAvailable {
                FixedActionArea {
                    PrimaryAction(
                        title: mutationIntent == .save && viewModel.isMutating ? "正在保存" : "保存",
                        isLoading: mutationIntent == .save && viewModel.isMutating,
                        isDisabled: !isInputValid,
                        fillsWidth: true,
                        action: save
                    )
                }
            }
        }
        .interactiveDismissDisabled(isDirty)
        .background(
            InteractiveDismissAttemptObserver(isDisabled: isDirty) {
                showingDiscardConfirmation = true
            }
        )
        .overlay {
            if showingDiscardConfirmation {
                ConfirmationDialog(
                    title: "放弃未保存的修改？",
                    message: "返回后本页修改不会保存。",
                    confirmationTitle: "放弃修改",
                    cancelTitle: "继续编辑",
                    variant: .discard,
                    onCancel: { showingDiscardConfirmation = false },
                    onConfirm: {
                        showingDiscardConfirmation = false
                        initialFormValues = currentFormValues
                        dismiss()
                    }
                )
            } else if showingDeletionConfirmation, let equipment = viewModel.editingEquipment {
                ConfirmationDialog(
                    title: "删除“\(equipment.name)”？",
                    message: deletionConfirmationMessage,
                    confirmationTitle: "确认删除",
                    variant: .danger,
                    isLoading: mutationIntent == .delete && viewModel.isMutating,
                    onCancel: {
                        guard !viewModel.isMutating else { return }
                        showingDeletionConfirmation = false
                    },
                    onConfirm: confirmDeletion
                )
            }
        }
        .task { await loadEquipmentIfNeeded() }
    }

    private var mode: EquipmentEditMode {
        EquipmentEditMode(equipmentID: equipmentID)
    }

    @ViewBuilder
    private var pageContent: some View {
        switch mode {
        case .create:
            formPage
        case .edit:
            switch viewModel.editLoadState {
            case .idle, .loading:
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        pageTitleBlock
                        LoadingView(message: "正在加载装备", variant: .section)
                            .frame(minHeight: 320)
                    }
                    .frame(maxWidth: 600, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, Spacing.pageHorizontal)
                    .padding(.top, Spacing.md)
                }
            case .failed:
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        pageTitleBlock
                        ErrorView(message: viewModel.errorMessage ?? "装备加载失败", variant: .section) {
                            Task { await loadEquipmentIfNeeded() }
                        }
                        .frame(minHeight: 320)
                    }
                    .frame(maxWidth: 600, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .padding(.horizontal, Spacing.pageHorizontal)
                    .padding(.top, Spacing.md)
                }
            case .loaded:
                formPage
            }
        }
    }

    private var formPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                pageTitleBlock
                PersonalEquipmentForm(
                    projection: PersonalEquipmentFormProjection(
                        name: name,
                        ownedQuantity: quantityText,
                        unitWeight: unitWeightGrams,
                        nameError: nameFieldError,
                        ownedQuantityError: quantityFieldError,
                        unitWeightError: weightFieldError,
                        saveError: saveErrorMessage,
                        isDisabled: viewModel.isMutating
                    ),
                    onChangeField: updateFormField
                )

                if mode != .create {
                    editOnlyDangerZone
                }
            }
            .frame(maxWidth: 600, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.top, Spacing.md)
            .padding(.bottom, 108)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var pageTitleBlock: some View {
        PageTitleBlock(
            title: mode == .create ? "新增一件装备" : "更新装备",
            kicker: "写入长期个人资产",
            description: "只维护装备名称、实际拥有数量和可选的单件重量。"
        )
    }

    private func updateFormField(_ field: PersonalEquipmentFormField, _ value: String) {
        failedMutationIntent = nil
        switch field {
        case .name:
            name = value
            isNameFieldTouched = true
            viewModel.clearNameError()
        case .ownedQuantity:
            quantityText = value
            isQuantityFieldTouched = true
        case .unitWeight:
            unitWeightGrams = value
            isWeightFieldTouched = true
        }
    }

    private var editOnlyDangerZone: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if let impact = viewModel.deletionImpact {
                EquipmentDeletionImpact(impact: impact)
            }

            if let errorMessage = deletionErrorMessage {
                ErrorView(message: errorMessage, title: "删除失败", variant: .form)
            }

            DangerAction(
                title: mutationIntent == .loadDeletionImpact && viewModel.isMutating ? "正在读取删除影响" : "删除这件装备",
                systemImage: "trash",
                isLoading: mutationIntent == .loadDeletionImpact && viewModel.isMutating,
                isDisabled: viewModel.isMutating,
                fillsWidth: true
            ) {
                prepareDeletion()
            }
        }
        .padding(.top, Spacing.lg)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.dangerBorder)
                .frame(height: 1)
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedQuantity: String {
        quantityText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedQuantity: Int? {
        Int(trimmedQuantity)
    }

    private var trimmedWeight: String {
        unitWeightGrams.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedWeight: Int? {
        trimmedWeight.isEmpty ? nil : Int(trimmedWeight)
    }

    private var nameFieldError: String? {
        if let conflict = viewModel.nameErrorMessage { return conflict }
        return isNameFieldTouched && trimmedName.isEmpty ? "请输入装备名称" : nil
    }

    private var quantityFieldError: String? {
        guard isQuantityFieldTouched else { return nil }
        return (parsedQuantity ?? 0) > 0 ? nil : "请输入大于零的正整数"
    }

    private var weightFieldError: String? {
        guard isWeightFieldTouched, !trimmedWeight.isEmpty else { return nil }
        return (parsedWeight ?? 0) > 0 ? nil : "请输入大于零的克重"
    }

    private var isInputValid: Bool {
        !trimmedName.isEmpty
            && parsedQuantity.map { $0 > 0 } == true
            && (trimmedWeight.isEmpty || parsedWeight.map { $0 > 0 } == true)
            && viewModel.nameErrorMessage == nil
            && !viewModel.isMutating
    }

    private var currentFormValues: EquipmentEditFormValues {
        EquipmentEditFormValues(
            name: name,
            ownedQuantity: parsedQuantity ?? 0,
            unitWeightGrams: unitWeightGrams
        )
    }

    private var isDirty: Bool {
        isFormAvailable
            && EquipmentEditPresentation.isDirty(current: currentFormValues, initial: initialFormValues)
    }

    private var isFormAvailable: Bool {
        switch mode {
        case .create:
            return true
        case .edit:
            return viewModel.editLoadState == .loaded
        }
    }

    private var saveErrorMessage: String? {
        guard failedMutationIntent == .save,
              viewModel.nameErrorMessage == nil else {
            return nil
        }
        return viewModel.errorMessage
    }

    private var deletionErrorMessage: String? {
        guard failedMutationIntent == .loadDeletionImpact || failedMutationIntent == .delete else { return nil }
        return viewModel.errorMessage
    }

    private var deletionConfirmationMessage: String {
        deletionMessage
    }

    private var deletionMessage: String {
        let prefix = "删除后会从用户装备清单移除，但不会修改已经生成的行程装备。"
        guard let impact = viewModel.deletionImpact,
              impact.equipmentListReferenceCount > 0 else {
            return prefix
        }
        let names = impact.affectedEquipmentLists.map(\.name).joined(separator: "、")
        return "\(prefix) 当前会影响 \(impact.equipmentListReferenceCount) 份用户清单：\(names)。"
    }

    private func loadEquipmentIfNeeded() async {
        guard let equipmentID else { return }
        await viewModel.loadEquipment(id: equipmentID)
        guard let equipment = viewModel.editingEquipment else { return }
        name = equipment.name
        quantityText = String(equipment.ownedQuantity)
        unitWeightGrams = equipment.unitWeight.map { String($0.grams) } ?? ""
        initialFormValues = EquipmentEditFormValues(
            name: equipment.name,
            ownedQuantity: equipment.ownedQuantity,
            unitWeightGrams: equipment.unitWeight.map { String($0.grams) } ?? ""
        )
        isNameFieldTouched = false
        isQuantityFieldTouched = false
        isWeightFieldTouched = false
    }

    private func requestDismissal() {
        if isDirty {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        guard isInputValid, let quantity = parsedQuantity else { return }
        viewModel.deletionImpact = nil
        failedMutationIntent = nil
        mutationIntent = .save
        Task {
            await viewModel.saveEquipment(
                equipmentID: equipmentID,
                name: trimmedName,
                ownedQuantity: quantity,
                unitWeightGrams: parsedWeight
            )
            mutationIntent = nil
            if viewModel.lastMutationSucceeded {
                initialFormValues = currentFormValues
                dismiss()
            } else {
                failedMutationIntent = .save
            }
        }
    }

    private func prepareDeletion() {
        guard !viewModel.isMutating, let equipment = viewModel.editingEquipment else { return }
        viewModel.deletionImpact = nil
        failedMutationIntent = nil
        mutationIntent = .loadDeletionImpact
        Task {
            await viewModel.loadDeletionImpact(id: equipment.identity)
            mutationIntent = nil
            if viewModel.lastMutationSucceeded {
                showingDeletionConfirmation = true
            } else {
                failedMutationIntent = .loadDeletionImpact
            }
        }
    }

    private func confirmDeletion() {
        guard !viewModel.isMutating, let equipment = viewModel.editingEquipment else { return }
        failedMutationIntent = nil
        mutationIntent = .delete
        Task {
            await viewModel.deleteEquipment(id: equipment.identity)
            mutationIntent = nil
            if viewModel.lastMutationSucceeded {
                showingDeletionConfirmation = false
                dismiss()
            } else {
                showingDeletionConfirmation = false
                failedMutationIntent = .delete
            }
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
