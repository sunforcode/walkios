import SwiftUI
import WalkData
import WalkDesignSystem

final class TripEquipmentViewModel: ObservableObject {
    @Published var projection: TripEquipmentProjection?
    @Published var isLoading = false
    @Published var isMutating = false
    @Published var errorMessage: String?

    let tripID: String
    private let service: any TripEquipmentServicing
    private var hasLoaded = false
    private var shouldRecheckOnAppearance = false

    var isEditable: Bool { projection?.editable == true }

    init(tripID: String, service: any TripEquipmentServicing) {
        self.tripID = tripID
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            projection = try await service.getEquipment(tripID: tripID)
            hasLoaded = true
        } catch {
            errorMessage = message(for: error, operation: "加载")
        }
    }

    func prepareForPersonalEquipment() {
        shouldRecheckOnAppearance = true
    }

    func handleAppearance() async {
        guard hasLoaded else {
            await load()
            return
        }
        guard shouldRecheckOnAppearance else { return }
        shouldRecheckOnAppearance = false
        await recheckOwnership()
    }

    func addItem(name: String, quantity: Int, unitWeightGrams: Int?, note: String?) async {
        await mutate(operation: "添加") {
            try await service.addItem(
                tripID: tripID,
                name: name,
                quantity: quantity,
                unitWeightGrams: unitWeightGrams,
                note: note
            )
        }
    }

    func updateItem(itemID: String, update: TripEquipmentItemUpdate) async {
        await mutate(operation: "更新") {
            try await service.updateItem(tripID: tripID, itemID: itemID, update: update)
        }
    }

    func deleteItem(itemID: String) async {
        await mutate(operation: "删除") {
            try await service.deleteItem(tripID: tripID, itemID: itemID)
        }
    }

    func recheckOwnership() async {
        await mutate(operation: "重新核对") {
            try await service.recheckOwnership(tripID: tripID)
        }
    }

    private func mutate(
        operation: String,
        action: () async throws -> TripEquipmentProjection
    ) async {
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }
        do {
            projection = try await action()
        } catch {
            errorMessage = message(for: error, operation: operation)
        }
    }

    private func message(for error: Error, operation: String) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "\(operation)失败：\(error.localizedDescription)"
    }
}

struct TripEquipmentView: View {
    @StateObject private var viewModel: TripEquipmentViewModel
    @State private var editorMode: TripEquipmentEditorMode?
    @State private var editorName = ""
    @State private var editorQuantity = 1
    @State private var editorUnitWeight = ""
    @State private var editorNote = ""
    @State private var deletingItem: TripEquipmentItem?
    @State private var lastFailedDeletionItemID: String?
    private let onManagePersonalEquipment: () -> Void
    private let onRevisionChange: (String) -> Void

    init(
        tripID: String,
        service: any TripEquipmentServicing,
        onManagePersonalEquipment: @escaping () -> Void = {},
        onRevisionChange: @escaping (String) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: TripEquipmentViewModel(
            tripID: tripID,
            service: service
        ))
        self.onManagePersonalEquipment = onManagePersonalEquipment
        self.onRevisionChange = onRevisionChange
    }

    var body: some View {
        UtilityPage(
            title: "行程装备",
            bottomFixed: {
                if viewModel.projection?.editable == true {
                    PrimaryAction(
                        title: editorMode == nil ? "新增本次装备" : "保存本次装备",
                        isLoading: viewModel.isMutating && editorMode != nil,
                        isDisabled: viewModel.isMutating || (editorMode != nil && !editorInputIsValid),
                        fillsWidth: true,
                        action: {
                            if editorMode == nil {
                                beginAdding()
                            } else {
                                saveEditor()
                            }
                        }
                    )
                }
            }
        ) {
            Group {
                if viewModel.isLoading && viewModel.projection == nil {
                    LoadingView(message: "正在加载行程装备", variant: .page)
                } else if viewModel.errorMessage != nil, viewModel.projection == nil {
                    ErrorView(
                        message: "当前装备快照不可用或汇总不一致。",
                        title: "无法显示行程装备",
                        variant: .page,
                        retry: { Task { await viewModel.load() } }
                    )
                } else if let projection = viewModel.projection {
                    scrollContent(projection)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        }
        .overlay {
            if let item = deletingItem {
                ConfirmationDialog(
                    title: "删除这件本次装备？",
                    message: "仅从本次行程快照中删除，不会删除个人装备。",
                    confirmationTitle: "删除装备",
                    variant: .danger,
                    isLoading: viewModel.isMutating,
                    error: item.identity == lastFailedDeletionItemID ? viewModel.errorMessage : nil,
                    onCancel: {
                        guard !viewModel.isMutating else { return }
                        deletingItem = nil
                        lastFailedDeletionItemID = nil
                        viewModel.errorMessage = nil
                    },
                    onConfirm: { deleteItem(item) }
                )
            }
        }
        .onAppear { Task { await viewModel.handleAppearance() } }
        .onChange(of: viewModel.projection?.revision) { revision in
            if let revision { onRevisionChange(revision) }
        }
    }

    private func scrollContent(_ projection: TripEquipmentProjection) -> some View {
        LazyVStack(alignment: .leading, spacing: Spacing.xl) {
            contextRow(projection.trip)
            TripBusinessComponents.TripEquipmentOverview(
                projection: TripEquipmentOverviewProjection(
                    itemCount: projection.snapshot.summary.itemCount,
                    knownTotalWeightGrams: projection.snapshot.summary.knownTotalWeight.grams,
                    missingWeightItemCount: projection.snapshot.summary.missingWeightItemCount,
                    ownedItemCount: projection.snapshot.summary.ownedItemCount,
                    unconfirmedOwnedItemCount: projection.snapshot.summary.unconfirmedOwnedItemCount
                )
            )

            if !projection.editable {
                NoticeView(
                    message: "只有规划中的行程可以调整本次装备。",
                    title: "当前行程只读",
                    icon: "lock",
                    tone: .readonly
                )
            }

            if projection.editable, editorMode != nil {
                SharedBusinessComponents.InlineEquipmentEditor(
                    projection: InlineEquipmentEditorProjection(
                        title: editorMode?.title ?? "本次装备",
                        name: editorName,
                        quantity: editorQuantity,
                        unitWeight: editorUnitWeight,
                        note: editorNote,
                        nameError: editorNameError,
                        unitWeightError: editorUnitWeightError,
                        noteError: nil,
                        saveError: viewModel.errorMessage,
                        isLoading: viewModel.isMutating
                    ),
                    onChangeField: updateEditorField,
                    onChangeQuantity: { editorQuantity = $0 },
                    onCancel: cancelEditing
                )
            }

            ContentSection(title: "装备清单") {
                if projection.snapshot.items.isEmpty {
                    EmptyStateView(
                        title: "本次清单为空",
                        message: "预计总重量 0 kg。规划中的行程可以新增只属于当前行程的装备。",
                        icon: "backpack",
                        variant: .section
                    )
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(projection.snapshot.items.enumerated()), id: \.element.id) { index, item in
                            TripBusinessComponents.TripEquipmentItemRow(
                                projection: equipmentItemProjection(item, editable: projection.editable && editorMode == nil),
                                onRequestEdit: { _ in beginEditing(item) },
                                onRequestDelete: { _ in deletingItem = item }
                            )
                            if index < projection.snapshot.items.count - 1 {
                                Rectangle()
                                    .fill(AppColors.surfaceDivider)
                                    .frame(height: 1)
                                    .accessibilityHidden(true)
                            }
                        }
                    }
                }
            }

            if projection.editable, editorMode == nil {
                secondaryActions
            }

            if let error = viewModel.errorMessage, viewModel.projection != nil, editorMode == nil {
                ErrorView(
                    message: error,
                    title: "操作未完成",
                    variant: .section,
                    retry: nil
                )
            }

            independentCopyNote
        }
        .frame(maxWidth: 600, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private func contextRow(_ trip: TripEquipmentTrip) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(trip.routeName)
                .font(.pageTitle)
                .foregroundStyle(AppColors.textPrimary)
            Text(dateRange(trip))
                .font(.appCaption)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var secondaryActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.sm) {
                SecondaryAction(
                    title: "重新核对已有状态",
                    systemImage: "arrow.triangle.2.circlepath",
                    isLoading: viewModel.isMutating,
                    fillsWidth: true,
                    action: { Task { await viewModel.recheckOwnership() } }
                )
                SecondaryAction(
                    title: "管理我的装备",
                    isDisabled: viewModel.isMutating,
                    fillsWidth: true,
                    action: managePersonalEquipment
                )
            }
            VStack(spacing: Spacing.sm) {
                SecondaryAction(
                    title: "重新核对已有状态",
                    systemImage: "arrow.triangle.2.circlepath",
                    isLoading: viewModel.isMutating,
                    fillsWidth: true,
                    action: { Task { await viewModel.recheckOwnership() } }
                )
                SecondaryAction(
                    title: "管理我的装备",
                    isDisabled: viewModel.isMutating,
                    fillsWidth: true,
                    action: managePersonalEquipment
                )
            }
        }
    }

    private func managePersonalEquipment() {
        viewModel.prepareForPersonalEquipment()
        onManagePersonalEquipment()
    }

    /// 删除确认失败保留投影与 Dialog，错误就位显示；成功才关闭。
    private func deleteItem(_ item: TripEquipmentItem) {
        guard !viewModel.isMutating else { return }
        let itemID = item.identity
        Task {
            await viewModel.deleteItem(itemID: itemID)
            if viewModel.errorMessage != nil {
                lastFailedDeletionItemID = itemID
            } else {
                deletingItem = nil
                lastFailedDeletionItemID = nil
            }
        }
    }

    private var independentCopyNote: some View {
        NoticeView(
            message: "增删改不会影响个人装备、用户装备清单或系统标准装备清单。",
            title: "本次清单是独立副本",
            icon: "backpack",
            tone: .info
        )
    }

    private var editorNameError: String? {
        editorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "请输入装备名称"
            : nil
    }

    private var editorUnitWeightError: String? {
        let weight = editorUnitWeight.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !weight.isEmpty else { return nil }
        return (Int(weight) ?? 0) > 0 ? nil : "请输入大于零的克重"
    }

    private var editorInputIsValid: Bool {
        editorNameError == nil && editorQuantity > 0 && editorUnitWeightError == nil
    }

    private func updateEditorField(_ field: InlineEquipmentEditorField, _ value: String) {
        switch field {
        case .name:
            editorName = value
        case .unitWeight:
            editorUnitWeight = value
        case .note:
            editorNote = value
        }
    }

    private func beginAdding() {
        editorMode = .adding
        editorName = ""
        editorQuantity = 1
        editorUnitWeight = ""
        editorNote = ""
        viewModel.errorMessage = nil
    }

    private func beginEditing(_ item: TripEquipmentItem) {
        editorMode = .editing(item)
        editorName = item.name
        editorQuantity = item.quantity
        editorUnitWeight = item.unitWeight.map { String($0.grams) } ?? ""
        editorNote = item.note ?? ""
        viewModel.errorMessage = nil
    }

    private func cancelEditing() {
        editorMode = nil
        viewModel.errorMessage = nil
    }

    private func saveEditor() {
        guard let mode = editorMode, editorInputIsValid else { return }
        let name = editorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightText = editorUnitWeight.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteText = editorNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let weight = weightText.isEmpty ? nil : Int(weightText)
        let note = noteText.isEmpty ? nil : noteText

        Task {
            switch mode {
            case .adding:
                await viewModel.addItem(
                    name: name,
                    quantity: editorQuantity,
                    unitWeightGrams: weight,
                    note: note
                )
            case .editing(let item):
                await viewModel.updateItem(
                    itemID: item.identity,
                    update: TripEquipmentItemUpdate(
                        name: name,
                        quantity: editorQuantity,
                        unitWeight: weight.map { .value(EquipmentWeight(grams: $0)) } ?? .clear,
                        note: note.map(TripEquipmentUpdateField.value) ?? .clear
                    )
                )
            }
            if viewModel.errorMessage == nil { editorMode = nil }
        }
    }

    private func dateRange(_ trip: TripEquipmentTrip) -> String {
        DateCopy.dateRange(start: trip.startDate.description, end: trip.endDate.description)
    }
}

func equipmentItemProjection(
    _ item: TripEquipmentItem,
    editable: Bool
) -> TripEquipmentItemRowProjection {
    TripEquipmentItemRowProjection(
        identity: item.identity,
        name: item.name,
        quantity: item.quantity,
        unitWeightGrams: item.unitWeight?.grams,
        note: item.note,
        source: TripEquipmentItemSourceProjection(rawValue: item.source.rawValue) ?? .systemSuggestion,
        ownershipStatus: TripEquipmentOwnershipStatusProjection(rawValue: item.ownershipStatus.rawValue) ?? .owned,
        editable: editable
    )
}

private enum TripEquipmentEditorMode {
    case adding
    case editing(TripEquipmentItem)

    var title: String {
        switch self {
        case .adding: "新增本次装备"
        case .editing: "修改本次装备"
        }
    }
}
