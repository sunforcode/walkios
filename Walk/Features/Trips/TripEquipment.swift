import SwiftUI
import WalkData
import WalkDesignSystem

struct TripEquipmentView: View {
    @State private var viewModel: TripEquipmentViewModel
    private let onManagePersonalEquipment: () -> Void
    private let onRevisionChange: (String) -> Void

    init(
        tripID: String,
        service: any TripEquipmentPreparing,
        equipmentService: (any EquipmentServicing)? = nil,
        onManagePersonalEquipment: @escaping () -> Void = {},
        onRevisionChange: @escaping (String) -> Void = { _ in }
    ) {
        self.init(viewModel: TripEquipmentViewModel(
            tripID: tripID,
            service: service,
            equipmentService: equipmentService
        ), onManagePersonalEquipment: onManagePersonalEquipment, onRevisionChange: onRevisionChange)
    }

    init(
        viewModel: TripEquipmentViewModel,
        onManagePersonalEquipment: @escaping () -> Void = {},
        onRevisionChange: @escaping (String) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onManagePersonalEquipment = onManagePersonalEquipment
        self.onRevisionChange = onRevisionChange
    }

    var body: some View {
        UtilityPage(
            title: "行程装备",
            bottomFixed: {
                if viewModel.projection?.editable == true, viewModel.state.sourceMode == nil {
                    PrimaryAction(
                        title: viewModel.state.editor == nil ? "新增本次装备" : "保存本次装备",
                        isLoading: viewModel.isMutating && viewModel.state.editor != nil,
                        isDisabled: viewModel.isMutating || viewModel.state.requiresReload || (viewModel.state.editor != nil && !viewModel.editorInputIsValid),
                        fillsWidth: true,
                        action: {
                            if viewModel.state.editor == nil {
                                viewModel.beginAdding()
                            } else {
                                Task { await viewModel.saveEditor() }
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
            if viewModel.state.deletingItem != nil {
                ConfirmationDialog(
                    title: "删除这件本次装备？",
                    message: "仅从本次行程快照中删除，不会删除个人装备。",
                    confirmationTitle: "删除装备",
                    variant: .danger,
                    isLoading: viewModel.isMutating,
                    error: viewModel.state.deletionError,
                    onCancel: viewModel.cancelDeletion,
                    onConfirm: { Task { await viewModel.confirmDeletion() } }
                )
            }
        }
        .task { await viewModel.handleAppearance() }
        .onChange(of: viewModel.projection?.revision) { revision in
            if let revision { onRevisionChange(revision) }
        }
    }

    private func scrollContent(_ projection: TripEquipmentProjection) -> some View {
        // 分区只有概览、选择器和清单；无需延迟分区布局。
        // eager 容器避免滚动进入 ViewThatFits 操作区时反复估算分区高度。
        VStack(alignment: .leading, spacing: Spacing.xl) {
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

            if projection.editable, let sourceProjection = viewModel.sourcePickerProjection {
                TripBusinessComponents.TripEquipmentSourcePicker(
                    projection: sourceProjection,
                    onSelectSource: { mode in Task { await viewModel.beginSelectingSource(mode) } },
                    onSelectCandidate: viewModel.selectSourceCandidate,
                    onChangeQuantity: viewModel.updateSourceQuantity,
                    onConfirm: { Task { await viewModel.confirmSourceSelection() } },
                    onRetry: { Task { await viewModel.retrySource() } },
                    onReload: { Task { await viewModel.reloadAfterConflict() } },
                    onCancel: viewModel.cancelSourceSelection
                )
            }

            if projection.editable, viewModel.state.editor != nil {
                SharedBusinessComponents.InlineEquipmentEditor(
                    projection: InlineEquipmentEditorProjection(
                        title: viewModel.state.editor?.title ?? "本次装备",
                        name: viewModel.state.draft.name,
                        quantity: viewModel.state.draft.quantity,
                        unitWeight: viewModel.state.draft.unitWeight,
                        note: viewModel.state.draft.note,
                        nameError: viewModel.editorNameError,
                        unitWeightError: viewModel.editorUnitWeightError,
                        noteError: nil,
                        saveError: viewModel.errorMessage,
                        isLoading: viewModel.isMutating
                    ),
                    onChangeField: updateEditorField,
                    onChangeQuantity: viewModel.updateQuantity,
                    onCancel: viewModel.cancelEditing
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
                                projection: equipmentItemProjection(item, editable: projection.editable && viewModel.state.editor == nil && viewModel.state.sourceMode == nil && !viewModel.isMutating && !viewModel.state.requiresReload),
                                onRequestEdit: { _ in viewModel.beginEditing(item) },
                                onRequestDelete: { _ in viewModel.requestDelete(item) }
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

            if projection.editable, viewModel.state.editor == nil, viewModel.state.sourceMode == nil {
                secondaryActions
            }

            if let error = viewModel.errorMessage, viewModel.projection != nil, viewModel.state.editor == nil, viewModel.state.sourceMode == nil {
                ErrorView(
                    message: error,
                    title: "操作未完成",
                    variant: .section,
                    retry: nil
                )
            }

            if viewModel.state.offersReload, viewModel.state.sourceMode == nil {
                SecondaryAction(title: "重新加载当前清单", isDisabled: viewModel.isMutating,
                                action: { Task { await viewModel.reloadAfterConflict() } })
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
        VStack(spacing: Spacing.md) {
            if viewModel.canSelectSource {
                SecondaryAction(title: "从我的装备选入", isDisabled: viewModel.isMutating,
                                fillsWidth: true,
                                action: { Task { await viewModel.beginSelectingSource(.equipment) } })
                SecondaryAction(title: "追加常用清单", isDisabled: viewModel.isMutating,
                                fillsWidth: true,
                                action: { Task { await viewModel.beginSelectingSource(.list) } })
            }
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
    }

    private func managePersonalEquipment() {
        viewModel.prepareForPersonalEquipment()
        onManagePersonalEquipment()
    }

    private var independentCopyNote: some View {
        NoticeView(
            message: "增删改不会影响个人装备、用户装备清单或系统标准装备清单。",
            title: "本次清单是独立副本",
            icon: "backpack",
            tone: .info
        )
    }

    private func updateEditorField(_ field: InlineEquipmentEditorField, _ value: String) {
        switch field {
        case .name: viewModel.updateName(value)
        case .unitWeight: viewModel.updateUnitWeight(value)
        case .note: viewModel.updateNote(value)
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
        ownershipStatus: item.ownershipCheckApplicable == false
            ? .notApplicable
            : (TripEquipmentOwnershipStatusProjection(rawValue: item.ownershipStatus.rawValue) ?? .owned),
        editable: editable
    )
}
