import SwiftUI

struct EquipmentListView: View {
    @StateObject private var viewModel: EquipmentListViewModel
    @State private var newListName = ""
    @State private var showingCreateList = false

    private let service: any EquipmentServicing
    private let onEditEquipment: (String?) -> Void

    init(
        service: any EquipmentServicing,
        onEditEquipment: @escaping (String?) -> Void = { _ in }
    ) {
        self.service = service
        self.onEditEquipment = onEditEquipment
        _viewModel = StateObject(wrappedValue: EquipmentListViewModel(service: service))
    }

    var body: some View {
        UtilityPageContainer {
            Group {
                if viewModel.isLoading && viewModel.items.isEmpty && viewModel.equipmentLists.isEmpty {
                    LoadingView()
                } else if let error = viewModel.errorMessage,
                          viewModel.items.isEmpty,
                          viewModel.equipmentLists.isEmpty {
                    ErrorView(message: error) {
                        Task { await viewModel.load() }
                    }
                } else {
                    content
                }
            }
        }
        .navigationTitle("我的装备")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("添加装备", systemImage: "backpack") { onEditEquipment(nil) }
                    Button("新建清单", systemImage: "list.bullet") { showingCreateList = true }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: RootNavigation.toolButtonHitSize, height: RootNavigation.toolButtonHitSize)
                }
                .accessibilityLabel("添加装备或清单")
            }
        }
        .alert("新建装备清单", isPresented: $showingCreateList) {
            TextField("清单名称", text: $newListName)
            Button("取消", role: .cancel) { newListName = "" }
            Button("创建") { createList() }
                .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("清单用于安排已有个人装备的使用数量。")
        }
        .task { await viewModel.load() }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                if let summary = viewModel.summary {
                    summaryPanel(summary)
                }

                sectionHeader("个人装备", actionTitle: "添加") { onEditEquipment(nil) }
                if viewModel.items.isEmpty {
                    emptyPanel("暂无个人装备")
                } else {
                    ForEach(viewModel.items) { item in
                        Button {
                            onEditEquipment(item.identity)
                        } label: {
                            PersonalEquipmentRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }

                sectionHeader("装备清单", actionTitle: "新建") { showingCreateList = true }
                if viewModel.equipmentLists.isEmpty {
                    emptyPanel("暂无装备清单")
                } else {
                    ForEach(viewModel.equipmentLists) { list in
                        NavigationLink {
                            EquipmentListDetailView(
                                service: service,
                                equipmentListID: list.identity,
                                availableEquipment: viewModel.items
                            )
                        } label: {
                            EquipmentListOverviewRow(list: list)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.statusCancelled)
                }
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.vertical, Spacing.lg)
        }
        .refreshable { await viewModel.load() }
    }

    private func summaryPanel(_ summary: PersonalEquipmentSummary) -> some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("装备总览")
                    .font(.headline)
                HStack {
                    summaryValue("\(summary.equipmentItemCount)", label: "装备种类")
                    summaryValue("\(summary.equipmentListCount)", label: "清单")
                    summaryValue(equipmentWeightText(summary.knownTotalWeight.grams), label: "已知总重")
                }
                if summary.missingWeightItemCount > 0 {
                    Text("\(summary.missingWeightItemCount) 类装备尚未填写重量")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
    }

    private func summaryValue(_ value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ title: String, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.headline)
            Spacer()
            Button(actionTitle, action: action)
                .font(.caption)
                .foregroundStyle(AppColors.interactionPrimary)
        }
    }

    private func emptyPanel(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(AppColors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.lg)
            .background(AppColors.surfacePrimary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func createList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        newListName = ""
        Task { await viewModel.createEquipmentList(name: name) }
    }
}

private struct PersonalEquipmentRow: View {
    let item: PersonalEquipment

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "backpack")
                .foregroundStyle(AppColors.interactionPrimary)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.name)
                    .font(.body)
                    .foregroundStyle(AppColors.textPrimary)
                HStack(spacing: Spacing.sm) {
                    Text("拥有 \(item.ownedQuantity) 件")
                    if let unitWeight = item.unitWeight {
                        Text("单件 \(equipmentWeightText(unitWeight.grams))")
                    } else {
                        Text("重量未知")
                    }
                }
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.textWeak)
        }
        .padding(Spacing.md)
        .background(AppColors.surfacePrimary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct EquipmentListOverviewRow: View {
    let list: EquipmentListOverview

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "list.bullet")
                .foregroundStyle(AppColors.interactionPrimary)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(list.name)
                    .font(.body)
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(list.summary.itemCount) 类 · \(equipmentWeightText(list.summary.knownTotalWeight.grams))")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColors.textWeak)
        }
        .padding(Spacing.md)
        .background(AppColors.surfacePrimary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct EquipmentListDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: EquipmentListViewModel
    @State private var listName = ""
    @State private var showingRename = false
    @State private var showingDelete = false

    private let equipmentListID: String
    private let availableEquipment: [PersonalEquipment]

    init(
        service: any EquipmentServicing,
        equipmentListID: String,
        availableEquipment: [PersonalEquipment]
    ) {
        self.equipmentListID = equipmentListID
        self.availableEquipment = availableEquipment
        _viewModel = StateObject(wrappedValue: EquipmentListViewModel(service: service))
    }

    var body: some View {
        UtilityPageContainer {
            Group {
                if viewModel.isMutating && viewModel.selectedEquipmentList == nil {
                    LoadingView()
                } else if let detail = viewModel.selectedEquipmentList {
                    detailContent(detail)
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadEquipmentList(id: equipmentListID) }
                    }
                }
            }
        }
        .navigationTitle(viewModel.selectedEquipmentList?.name ?? "装备清单")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    addMemberMenu
                    Button("重命名", systemImage: "pencil") {
                        listName = viewModel.selectedEquipmentList?.name ?? ""
                        showingRename = true
                    }
                    Button("删除清单", systemImage: "trash", role: .destructive) {
                        showingDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: RootNavigation.toolButtonHitSize, height: RootNavigation.toolButtonHitSize)
                }
            }
        }
        .alert("重命名清单", isPresented: $showingRename) {
            TextField("清单名称", text: $listName)
            Button("取消", role: .cancel) {}
            Button("保存") {
                let name = listName.trimmingCharacters(in: .whitespacesAndNewlines)
                Task { await viewModel.renameEquipmentList(id: equipmentListID, name: name) }
            }
        }
        .confirmationDialog("删除这份清单？", isPresented: $showingDelete, titleVisibility: .visible) {
            Button("删除清单", role: .destructive) {
                Task {
                    await viewModel.deleteEquipmentList(id: equipmentListID)
                    if viewModel.lastMutationSucceeded { dismiss() }
                }
            }
        } message: {
            Text("只会删除清单及成员关系，不会删除个人装备。")
        }
        .task { await viewModel.loadEquipmentList(id: equipmentListID) }
    }

    @ViewBuilder
    private var addMemberMenu: some View {
        let memberIDs = Set(viewModel.selectedEquipmentList?.members.map(\.identity) ?? [])
        let candidates = availableEquipment.filter { !memberIDs.contains($0.identity) }
        if candidates.isEmpty {
            Button("没有可添加的装备", systemImage: "plus") {}
                .disabled(true)
        } else {
            Menu("添加成员", systemImage: "plus") {
                ForEach(candidates) { item in
                    Button(item.name) {
                        Task {
                            await viewModel.putMember(
                                equipmentListID: equipmentListID,
                                personalEquipmentID: item.identity,
                                quantity: 1
                            )
                        }
                    }
                }
            }
        }
    }

    private func detailContent(_ detail: EquipmentListDetail) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                WalkPanel {
                    HStack {
                        Text("\(detail.summary.itemCount) 类装备")
                        Spacer()
                        Text(equipmentWeightText(detail.summary.knownTotalWeight.grams))
                    }
                    .font(.body)
                }

                if detail.members.isEmpty {
                    Text("清单暂无成员，可从右上角添加已有装备。")
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(Spacing.lg)
                } else {
                    ForEach(detail.members) { member in
                        EquipmentListMemberRow(
                            member: member,
                            onQuantityChange: { quantity in
                                Task {
                                    await viewModel.putMember(
                                        equipmentListID: equipmentListID,
                                        personalEquipmentID: member.identity,
                                        quantity: quantity
                                    )
                                }
                            },
                            onDelete: {
                                Task {
                                    await viewModel.removeMember(
                                        equipmentListID: equipmentListID,
                                        personalEquipmentID: member.identity
                                    )
                                }
                            }
                        )
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.statusCancelled)
                }
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.vertical, Spacing.lg)
        }
    }
}

private struct EquipmentListMemberRow: View {
    let member: EquipmentListMember
    let onQuantityChange: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(member.name)
                Text("拥有 \(member.ownedQuantity) 件" + member.unitWeight.map { " · 单件 \(equipmentWeightText($0.grams))" }!)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            Button {
                if member.quantity > 1 { onQuantityChange(member.quantity - 1) }
            } label: {
                Image(systemName: "minus.circle")
            }
            .disabled(member.quantity <= 1)
            Text("\(member.quantity)")
                .frame(minWidth: 24)
            Button { onQuantityChange(member.quantity + 1) } label: {
                Image(systemName: "plus.circle")
            }
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
        }
        .padding(Spacing.md)
        .background(AppColors.surfacePrimary, in: RoundedRectangle(cornerRadius: 12))
    }
}

private func equipmentWeightText(_ grams: Int) -> String {
    if grams >= 1_000 {
        return String(format: "%.1f kg", Double(grams) / 1_000)
    }
    return "\(grams) g"
}
