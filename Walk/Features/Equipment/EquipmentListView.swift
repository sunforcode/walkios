import SwiftUI
import WalkData
import WalkDesignSystem

private enum EquipmentTab: Hashable {
    case equipment
    case lists
}

private enum EquipmentListMutationIntent: Equatable {
    case saveName
    case deleteList(id: String)
    case updateMember(listID: String)
}

struct EquipmentListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EquipmentListViewModel
    @State private var selectedTab: EquipmentTab = .equipment
    @State private var equipmentScrollAnchorID: String?
    @State private var listScrollAnchorID: String?
    @State private var newListName = ""
    @State private var showingCreateList = false
    @State private var expandedListID: String?
    @State private var renamingListID: String?
    @State private var renamingListName = ""
    @State private var deletingList: EquipmentListOverview?
    @State private var mutationIntent: EquipmentListMutationIntent?
    @State private var failedListID: String?

    private let scrollCoordinateSpace = "my-equipment-content"
    private let onEditEquipment: (String?) -> Void

    init(
        service: any EquipmentServicing,
        onEditEquipment: @escaping (String?) -> Void = { _ in }
    ) {
        self.onEditEquipment = onEditEquipment
        _viewModel = StateObject(wrappedValue: EquipmentListViewModel(service: service))
    }

    var body: some View {
        UtilityPage(
            title: "装备与清单",
            description: "个人装备记录实际拥有数量和可选单件重量；清单按清单内数量汇总预计总重量。",
            onBack: requestDismissal,
            bottomFixed: {
                if showsFixedActionArea {
                    PrimaryAction(
                        title: fixedActionTitle,
                        isLoading: isFixedActionLoading,
                        isDisabled: isFixedActionDisabled,
                        fillsWidth: true,
                        action: performFixedAction
                    )
                }
            }
        ) {
            scrollContent
        }
        .overlay {
            if let deletingList {
                ConfirmationDialog(
                    title: "删除“\(deletingList.name)”？",
                    message: listDeletionMessage,
                    confirmationTitle: "确认删除",
                    variant: .danger,
                    isLoading: viewModel.isMutating,
                    onCancel: {
                        guard !viewModel.isMutating else { return }
                        self.deletingList = nil
                        mutationIntent = nil
                        viewModel.clearMutationError()
                    },
                    onConfirm: { deleteEquipmentList(deletingList) }
                )
            }
        }
        .interactiveDismissDisabled(isEditingListName || deletingList != nil)
        .task { await viewModel.load() }
        .onAppear {
            guard viewModel.summary != nil else { return }
            Task { await viewModel.load() }
        }
    }

    private var scrollContent: some View {
        ScrollViewReader { scrollProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                    AppColors.surfacePrimary.opacity(0)
                        .frame(height: 0)
                        .id("equipment-page-top")

                    SegmentedControl(
                        options: [
                            SegmentedControlOption(value: EquipmentTab.equipment, title: "装备"),
                            SegmentedControlOption(value: EquipmentTab.lists, title: "清单")
                        ],
                        selection: $selectedTab
                    )
                    .disabled(isEditingListName || viewModel.isMutating)

                    tabContent
                }
                .frame(maxWidth: 600, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .coordinateSpace(name: scrollCoordinateSpace)
            .onPreferenceChange(EquipmentScrollAnchorPreferenceKey.self) { offsets in
                guard let visibleID = closestVisibleAnchor(in: offsets) else { return }
                if selectedTab == .equipment {
                    equipmentScrollAnchorID = visibleID
                } else {
                    listScrollAnchorID = visibleID
                }
            }
            .onChange(of: selectedTab) { tab in
                let targetID = tab == .equipment ? equipmentScrollAnchorID : listScrollAnchorID
                DispatchQueue.main.async {
                    scrollProxy.scrollTo(targetID ?? "equipment-page-top", anchor: .top)
                }
            }
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
                        mode: renamingListID == nil ? .create : .rename,
                        name: activeListName,
                        fieldError: listNameFieldError,
                        saveError: listNameSaveError,
                        isLoading: mutationIntent == .saveName && viewModel.isMutating
                    ),
                    onChangeName: updateActiveListName,
                    onCancel: cancelListNameEditor
                )
            }

            if viewModel.equipmentLists.isEmpty {
                EmptyStateView(
                    title: "还没有用户装备清单",
                    message: "可以按自己的习惯创建一日、三日或五日清单。",
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
                            onRename: { _ in startRename(list) },
                            onRequestDelete: { _ in requestDelete(list) },
                            onChangeQuantity: { memberID, quantity in
                                Task {
                                    _ = await updateMember(
                                        equipmentListID: list.identity,
                                        personalEquipmentID: memberID,
                                        quantity: quantity
                                    )
                                }
                            },
                            onRemoveMember: { memberID in
                                removeMember(
                                    equipmentListID: list.identity,
                                    personalEquipmentID: memberID
                                )
                            }
                        ) {
                            checklistCandidateContent(for: list)
                        }
                        .id("list-\(list.identity)")
                        .background(scrollAnchorReader(id: "list-\(list.identity)"))

                        if failedListID == list.identity,
                           let errorMessage = viewModel.errorMessage {
                            ErrorView(message: errorMessage, title: "清单更新失败", variant: .form)
                        }
                    }
                }
            }
        }
    }

    private var isEditingListName: Bool {
        showingCreateList || renamingListID != nil
    }

    private var showsFixedActionArea: Bool {
        let hasNoLoadedContent = viewModel.items.isEmpty && viewModel.equipmentLists.isEmpty
        return !(viewModel.isLoading && hasNoLoadedContent)
            && !(viewModel.loadErrorMessage != nil && hasNoLoadedContent)
    }

    private var fixedActionTitle: String {
        if isEditingListName { return "保存清单" }
        return selectedTab == .equipment ? "新增个人装备" : "创建装备清单"
    }

    private var isFixedActionLoading: Bool {
        isEditingListName && mutationIntent == .saveName && viewModel.isMutating
    }

    private var isFixedActionDisabled: Bool {
        if isEditingListName {
            return activeListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || viewModel.isMutating
        }
        return viewModel.isMutating
    }

    private var activeListName: String {
        renamingListID == nil ? newListName : renamingListName
    }

    private func performFixedAction() {
        if isEditingListName {
            saveListName()
            return
        }

        switch selectedTab {
        case .equipment:
            onEditEquipment(nil)
        case .lists:
            showingCreateList = true
            newListName = ""
            mutationIntent = nil
            failedListID = nil
            viewModel.clearMutationError()
        }
    }

    private func requestDismissal() {
        if isEditingListName {
            cancelListNameEditor()
        } else {
            dismiss()
        }
    }

    private var listNameFieldError: String? {
        guard !activeListName.isEmpty,
              activeListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return "请输入清单名称"
    }

    private var listNameSaveError: String? {
        guard mutationIntent == .saveName else { return nil }
        return viewModel.errorMessage
    }

    private func updateActiveListName(_ value: String) {
        if renamingListID == nil {
            newListName = value
        } else {
            renamingListName = value
        }
        if !viewModel.isMutating {
            mutationIntent = nil
            viewModel.clearMutationError()
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
              detail.identity == list.identity else {
            return []
        }
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
                  let error = viewModel.errorMessage,
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

    private func requestDelete(_ list: EquipmentListOverview) {
        viewModel.clearMutationError()
        mutationIntent = nil
        failedListID = nil
        deletingList = list
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
                                _ = await updateMember(
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
                value: [id: proxy.frame(in: .named(scrollCoordinateSpace)).minY]
            )
        }
    }

    private func closestVisibleAnchor(in offsets: [String: CGFloat]) -> String? {
        let visibleAnchors = offsets.filter { $0.value >= 0 }
        return visibleAnchors.min(by: { $0.value < $1.value })?.key
    }

    private func setExpanded(_ isExpanded: Bool, list: EquipmentListOverview) {
        guard !isEditingListName else { return }
        failedListID = nil
        mutationIntent = nil
        if isExpanded {
            expandedListID = list.identity
            Task {
                await viewModel.loadEquipmentList(id: list.identity)
                if viewModel.selectedEquipmentList == nil {
                    mutationIntent = nil
                }
            }
        } else if expandedListID == list.identity {
            expandedListID = nil
            viewModel.clearSelectedEquipmentList()
        }
    }

    private func startRename(_ list: EquipmentListOverview) {
        showingCreateList = false
        newListName = ""
        renamingListID = list.identity
        renamingListName = list.name
        mutationIntent = nil
        failedListID = nil
        viewModel.clearMutationError()
    }

    private func cancelListNameEditor() {
        showingCreateList = false
        newListName = ""
        renamingListID = nil
        renamingListName = ""
        mutationIntent = nil
        failedListID = nil
        viewModel.clearMutationError()
    }

    private func saveListName() {
        let name = activeListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !viewModel.isMutating else { return }
        mutationIntent = .saveName
        Task {
            if let renamingListID {
                await viewModel.renameEquipmentList(id: renamingListID, name: name)
            } else {
                await viewModel.createEquipmentList(name: name)
            }
            if viewModel.lastMutationSucceeded {
                cancelListNameEditor()
            }
        }
    }

    private func updateMember(
        equipmentListID: String,
        personalEquipmentID: String,
        quantity: Int
    ) async -> Bool {
        guard !viewModel.isMutating else { return false }
        mutationIntent = .updateMember(listID: equipmentListID)
        failedListID = nil
        await viewModel.putMember(
            equipmentListID: equipmentListID,
            personalEquipmentID: personalEquipmentID,
            quantity: quantity
        )
        if !viewModel.lastMutationSucceeded {
            failedListID = equipmentListID
        }
        return viewModel.lastMutationSucceeded
    }

    private func removeMember(equipmentListID: String, personalEquipmentID: String) {
        guard !viewModel.isMutating else { return }
        mutationIntent = .updateMember(listID: equipmentListID)
        failedListID = nil
        Task {
            await viewModel.removeMember(
                equipmentListID: equipmentListID,
                personalEquipmentID: personalEquipmentID
            )
            if !viewModel.lastMutationSucceeded {
                failedListID = equipmentListID
            }
        }
    }

    private var listDeletionMessage: String {
        let impact = "只会删除这份清单和成员关系，不会删除任何个人装备。"
        if mutationIntent == .deleteList(id: deletingList?.identity ?? ""),
           let errorMessage = viewModel.errorMessage {
            return "\(impact) 删除失败：\(errorMessage)"
        }
        return impact
    }

    private func deleteEquipmentList(_ list: EquipmentListOverview) {
        guard !viewModel.isMutating else { return }
        mutationIntent = .deleteList(id: list.identity)
        Task {
            await viewModel.deleteEquipmentList(id: list.identity)
            if viewModel.lastMutationSucceeded {
                deletingList = nil
                mutationIntent = nil
                failedListID = nil
                if expandedListID == list.identity {
                    expandedListID = nil
                }
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
