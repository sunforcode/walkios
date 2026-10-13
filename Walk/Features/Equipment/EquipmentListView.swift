import SwiftUI
import WalkData
import WalkDesignSystem

private enum EquipmentTab: Hashable {
    case equipment
    case lists
}

enum EquipmentListPresentation: Equatable {
    case root
    case stack
}

struct EquipmentListView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EquipmentListViewModel
    @State private var selectedTab: EquipmentTab = .equipment
    @State private var equipmentScrollAnchorID: String?
    @State private var listScrollAnchorID: String?
    @State private var expandedListID: String?
    @State private var isRestoringScrollAnchor = false

    private let onEditEquipment: (String?) -> Void
    private let presentation: EquipmentListPresentation

    init(
        service: any EquipmentServicing,
        presentation: EquipmentListPresentation = .stack,
        onEditEquipment: @escaping (String?) -> Void = { _ in }
    ) {
        self.presentation = presentation
        self.onEditEquipment = onEditEquipment
        _viewModel = State(initialValue: EquipmentListViewModel(service: service))
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            page(scrollProxy: scrollProxy)
            .allowsHitTesting(viewModel.state.deletingList == nil)
            .accessibilityHidden(viewModel.state.deletingList != nil)
            .onPreferenceChange(EquipmentScrollAnchorPreferenceKey.self) { offsets in
                guard !isRestoringScrollAnchor,
                      let visibleID = closestVisibleAnchor(in: offsets) else { return }
                if selectedTab == .equipment {
                    equipmentScrollAnchorID = visibleID
                } else {
                    listScrollAnchorID = visibleID
                }
            }
            .onChange(of: selectedTab) { tab in
                isRestoringScrollAnchor = true
                let targetID = tab == .equipment ? equipmentScrollAnchorID : listScrollAnchorID
                DispatchQueue.main.async {
                    guard selectedTab == tab else { return }
                    scrollProxy.scrollTo(targetID ?? "equipment-page-top", anchor: .top)
                    isRestoringScrollAnchor = false
                }
            }
        }
        .overlay {
            if let deletingList = viewModel.state.deletingList {
                ConfirmationDialog(
                    title: "删除“\(deletingList.name)”？",
                    message: viewModel.state.listDeletionMessage,
                    confirmationTitle: "确认删除",
                    variant: .danger,
                    isLoading: viewModel.isMutating,
                    onCancel: viewModel.cancelEditing,
                    onConfirm: { deleteEquipmentList(deletingList) }
                )
            }
        }
        .interactiveDismissDisabled(isEditingListName || viewModel.state.deletingList != nil)
        .task { await viewModel.load() }
        .onDisappear { viewModel.invalidatePendingOperations() }
    }

    @ViewBuilder
    private func page(scrollProxy: ScrollViewProxy) -> some View {
        switch presentation {
        case .root:
            PageShell(
                title: "装备",
                description: "管理个人装备与常用清单",
                background: { AppColors.pageBase }
            ) {
                ScrollView(showsIndicators: false) {
                    scrollContent(scrollProxy: scrollProxy)
                        .padding(.horizontal, Spacing.pageHorizontal)
                        .padding(.bottom, Spacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if showsFixedActionArea {
                        FixedActionArea { fixedAction }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        case .stack:
            UtilityPage(
                title: "装备",
                description: "管理个人装备与常用清单",
                onBack: requestDismissal,
                bottomFixed: { fixedAction }
            ) {
                scrollContent(scrollProxy: scrollProxy)
            }
        }
    }

    @ViewBuilder
    private var fixedAction: some View {
        if showsFixedActionArea {
            PrimaryAction(
                title: fixedActionTitle,
                isLoading: viewModel.state.operation == .running(.saveName),
                isDisabled: isFixedActionDisabled,
                fillsWidth: true,
                action: performFixedAction
            )
        }
    }

    private func activateEquipmentLibrary(using scrollProxy: ScrollViewProxy) {
        guard !isEditingListName, !viewModel.isMutating else { return }
        equipmentScrollAnchorID = "equipment-library-top"
        isRestoringScrollAnchor = true
        selectedTab = .equipment
        DispatchQueue.main.async {
            scrollProxy.scrollTo("equipment-library-top", anchor: .top)
            isRestoringScrollAnchor = false
        }
    }

    private func scrollContent(scrollProxy: ScrollViewProxy) -> some View {
        LazyVStack(alignment: .leading, spacing: Spacing.lg) {
            AppColors.surfacePrimary.opacity(0)
                .frame(height: 0)
                .id("equipment-page-top")

            if presentation == .root, let summary = viewModel.summary {
                PersonalEquipmentSummaryCard(summary: summary) {
                    activateEquipmentLibrary(using: scrollProxy)
                }
                .disabled(isEditingListName || viewModel.isMutating)
            }

            SegmentedControl(
                options: [
                    SegmentedControlOption(value: EquipmentTab.equipment, title: "装备"),
                    SegmentedControlOption(value: EquipmentTab.lists, title: "清单")
                ],
                selection: Binding(
                    get: { selectedTab },
                    set: { tab in
                        guard selectedTab != tab else { return }
                        isRestoringScrollAnchor = true
                        selectedTab = tab
                    }
                )
            )
            .disabled(isEditingListName || viewModel.isMutating)
            .id("equipment-library-top")

            tabContent
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if viewModel.isLoading && viewModel.items.isEmpty && viewModel.equipmentLists.isEmpty {
            LoadingView(message: selectedTab == .equipment ? "正在加载个人装备" : "正在加载装备清单", variant: .section)
                .frame(minHeight: 320)
        } else if let error = viewModel.loadErrorMessage,
                  viewModel.items.isEmpty,
                  viewModel.equipmentLists.isEmpty {
            ErrorView(message: error, variant: .section) {
                Task { await viewModel.load() }
            }
            .frame(minHeight: 320)
        } else if selectedTab == .equipment {
            equipmentPane
            if let error = viewModel.loadErrorMessage {
                ErrorView(message: error, title: "刷新失败", variant: .section) {
                    Task { await viewModel.load() }
                }
            }
        } else {
            listPane
            if let error = viewModel.loadErrorMessage {
                ErrorView(message: error, title: "刷新失败", variant: .section) {
                    Task { await viewModel.load() }
                }
            }
        }
    }

    private var equipmentPane: some View {
        Group {
            if viewModel.items.isEmpty {
                EmptyStateView(
                    title: "还没有个人装备",
                    message: "没有个人装备也不会阻断行程生成。",
                    icon: "backpack",
                    variant: .section
                )
            } else {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(viewModel.items) { item in
                        EquipmentListRow(
                            projection: .personalAsset(PersonalEquipmentRowProjection(
                                identity: item.identity,
                                name: item.name,
                                ownedQuantity: item.ownedQuantity,
                                unitWeightGrams: item.unitWeight?.grams
                            )),
                            onActivate: { onEditEquipment($0) },
                            onEdit: { _ in },
                            onDelete: { _ in }
                        )
                        .id("equipment-\(item.identity)")
                        .background(scrollAnchorReader(id: "equipment-\(item.identity)"))
                    }
                }
            }
        }
    }

    private var listPane: some View {
        LazyVStack(alignment: .leading, spacing: Spacing.md) {
            if isEditingListName {
                InlineListNameEditor(
                    projection: InlineListNameEditorProjection(
                        mode: viewModel.state.isRenamingList ? .rename : .create,
                        name: viewModel.state.activeListName,
                        fieldError: viewModel.state.listNameFieldError,
                        saveError: viewModel.state.listNameSaveError,
                        isLoading: viewModel.state.operation == .running(.saveName)
                    ),
                    onChangeName: viewModel.updateListName,
                    onCancel: viewModel.cancelEditing
                )
            }

            if viewModel.equipmentLists.isEmpty {
                EmptyStateView(
                    title: "还没有用户装备清单",
                    message: "可以按自己的习惯组织常用清单。",
                    icon: "list.bullet",
                    variant: .section
                )
            } else {
                ForEach(viewModel.equipmentLists) { list in
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        ChecklistPanel(
                            summary: equipmentListSummaryProjection(list),
                            isExpanded: expandedListID == list.identity,
                            members: checklistMembers(for: list),
                            isLoading: isEditingListName
                                || viewModel.isMutating
                                || (viewModel.selectedEquipmentListID == list.identity
                                    && viewModel.isLoadingEquipmentList),
                            onToggle: { _ in
                                setExpanded(expandedListID != list.identity, list: list)
                            },
                            onRename: { _ in viewModel.startRenamingList(list) },
                            onRequestDelete: { _ in viewModel.requestDeletion(list) },
                            onChangeQuantity: { memberID, quantity in
                                Task {
                                    _ = await viewModel.putMember(
                                        equipmentListID: list.identity,
                                        personalEquipmentID: memberID,
                                        quantity: quantity
                                    )
                                }
                            },
                            onRemoveMember: { memberID in
                                Task {
                                    _ = await viewModel.removeMember(
                                        equipmentListID: list.identity,
                                        personalEquipmentID: memberID
                                    )
                                }
                            }
                        ) {
                            checklistCandidateContent(for: list)
                        }
                        .id("list-\(list.identity)")
                        .background(scrollAnchorReader(id: "list-\(list.identity)"))

                        if viewModel.state.failedListID == list.identity,
                           let errorMessage = viewModel.state.errorMessage {
                            ErrorView(message: errorMessage, title: "清单更新失败", variant: .form)
                        }
                    }
                }
            }
        }
    }

    private var isEditingListName: Bool { viewModel.state.isEditingListName }

    private var showsFixedActionArea: Bool {
        viewModel.state.showsPrimaryAction(isEquipmentSection: selectedTab == .equipment)
    }

    private var fixedActionTitle: String {
        if isEditingListName { return "保存清单" }
        return selectedTab == .equipment ? "新增个人装备" : "创建装备清单"
    }

    private var isFixedActionDisabled: Bool {
        isEditingListName ? !viewModel.state.canSaveListName : viewModel.isMutating
    }

    private func performFixedAction() {
        if isEditingListName {
            Task { _ = await viewModel.saveListName() }
        } else if selectedTab == .equipment {
            onEditEquipment(nil)
        } else {
            viewModel.startCreatingList()
        }
    }

    private func requestDismissal() {
        guard !viewModel.isMutating else { return }
        if isEditingListName {
            viewModel.cancelEditing()
        } else {
            dismiss()
        }
    }

    private func equipmentListSummaryProjection(_ list: EquipmentListOverview) -> EquipmentListSummaryProjection {
        EquipmentListSummaryProjection(
            identity: list.identity,
            name: list.name,
            itemCount: list.summary.itemCount,
            knownTotalWeightGrams: list.summary.knownTotalWeight.grams,
            missingWeightItemCount: list.summary.missingWeightItemCount
        )
    }

    private func checklistMembers(for list: EquipmentListOverview) -> [ChecklistItemRowProjection] {
        guard let detail = viewModel.selectedEquipmentList,
              detail.identity == list.identity else { return [] }
        return detail.members.map { member in
            ChecklistItemRowProjection(
                identity: member.identity,
                listIdentity: detail.identity,
                listName: detail.name,
                equipmentName: member.name,
                ownedQuantity: member.ownedQuantity,
                quantity: member.quantity,
                unitWeightGrams: member.unitWeight?.grams
            )
        }
    }

    @ViewBuilder
    private func checklistCandidateContent(for list: EquipmentListOverview) -> some View {
        if viewModel.selectedEquipmentListID == list.identity,
           viewModel.isLoadingEquipmentList {
            LoadingView(message: "正在加载清单", variant: .section)
        } else if viewModel.selectedEquipmentListID == list.identity,
                  let error = viewModel.state.listLoadErrorMessage,
                  viewModel.selectedEquipmentList == nil {
            ErrorView(message: error, title: "清单加载失败", variant: .section) {
                Task { await viewModel.loadEquipmentList(id: list.identity) }
            }
        } else if let detail = viewModel.selectedEquipmentList,
                  detail.identity == list.identity {
            VStack(alignment: .leading, spacing: Spacing.md) {
                if detail.members.isEmpty {
                    EmptyStateView(
                        title: "清单暂无装备",
                        message: "从个人装备中选择条目加入这份清单。",
                        icon: "list.bullet",
                        variant: .section
                    )
                }
                addMemberEntry(detail)
            }
        }
    }

    private func addMemberEntry(_ detail: EquipmentListDetail) -> some View {
        let memberIDs = Set(detail.members.map(\.identity))
        let candidates = viewModel.items.filter { !memberIDs.contains($0.identity) }
        return Group {
            if candidates.isEmpty {
                Text("暂无未加入的个人装备")
                    .font(.appCaption)
                    .foregroundStyle(AppColors.textWeak)
            } else {
                Menu {
                    ForEach(candidates) { item in
                        Button(item.name) {
                            Task {
                                _ = await viewModel.putMember(
                                    equipmentListID: detail.identity,
                                    personalEquipmentID: item.identity,
                                    quantity: 1
                                )
                            }
                        }
                    }
                } label: {
                    Label("添加个人装备到清单", systemImage: "plus")
                        .font(.action)
                        .foregroundStyle(AppColors.interactionPrimary)
                        .frame(minHeight: 44)
                }
                .disabled(isEditingListName || viewModel.isMutating)
            }
        }
    }

    private func scrollAnchorReader(id: String) -> some View {
        GeometryReader { proxy in
            AppColors.surfacePrimary.opacity(0).preference(
                key: EquipmentScrollAnchorPreferenceKey.self,
                // 由当前承载的唯一纵向 ScrollView 提供视口坐标，而非随内容移动的坐标。
                value: [id: proxy.frame(in: .scrollView(axis: .vertical)).minY]
            )
        }
    }

    private func closestVisibleAnchor(in offsets: [String: CGFloat]) -> String? {
        let prefix = selectedTab == .equipment ? "equipment-" : "list-"
        let visibleAnchors = offsets.filter { $0.key.hasPrefix(prefix) && $0.value >= 0 }
        return visibleAnchors.min(by: { $0.value < $1.value })?.key
    }

    private func setExpanded(_ isExpanded: Bool, list: EquipmentListOverview) {
        guard !isEditingListName, !viewModel.isMutating else { return }
        if isExpanded {
            expandedListID = list.identity
            Task { await viewModel.loadEquipmentList(id: list.identity) }
        } else if expandedListID == list.identity {
            expandedListID = nil
            viewModel.clearSelectedEquipmentList()
        }
    }

    private func deleteEquipmentList(_ list: EquipmentListOverview) {
        Task {
            if await viewModel.deleteEquipmentList(id: list.identity), expandedListID == list.identity {
                expandedListID = nil
            }
        }
    }
}

private struct EquipmentScrollAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}
