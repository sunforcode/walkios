import SwiftUI

/// 装备清单页
struct EquipmentListView: View {
    @StateObject private var viewModel = EquipmentListViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let error = viewModel.errorMessage {
                ErrorView(message: error) {
                    Task { await viewModel.loadChecklist() }
                }
            } else if viewModel.checklist?.items.isEmpty ?? true {
                EmptyStateView(
                    title: "暂无装备",
                    message: "添加装备开始你的清单规划",
                    icon: "backpack",
                    actionTitle: "添加装备"
                ) {
                    // TODO: 跳转到添加装备页
                }
            } else {
                equipmentContent
            }
        }
        .navigationTitle("装备")
        .task {
            await viewModel.loadChecklist()
        }
    }

    private var equipmentContent: some View {
        VStack(spacing: 0) {
            // 进度条
            progressHeader

            ScrollView {
                LazyVStack(spacing: Spacing.legacyMd, pinnedViews: []) {
                    ForEach(viewModel.checklist?.groupedByCategory() ?? [], id: \.0.rawValue) { category, items in
                        EquipmentSectionView(
                            category: category,
                            items: items,
                            checkedItems: viewModel.checkedItems,
                            onToggle: { id in
                                Task { await viewModel.toggleCheck(equipmentId: id) }
                            },
                            onToggleAll: {
                                Task { await viewModel.toggleAll(in: category) }
                            }
                        )
                    }
                }
                .padding(.horizontal, Spacing.legacyMd)
                .padding(.vertical, Spacing.sm)
            }
            .background(Color.groupedBackground)
        }
    }

    private var progressHeader: some View {
        VStack(spacing: Spacing.sm) {
            HStack {
                Text("准备进度")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                Spacer()
                Text("\(viewModel.checkedCount)/\(viewModel.totalCount)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.textPrimary)
            }

            ProgressView(value: viewModel.progress)
                .tint(.primary)
        }
        .padding(Spacing.legacyMd)
        .background(Color.surfaceBackground)
    }
}

/// 装备分类分组视图
struct EquipmentSectionView: View {
    let category: EquipmentCategory
    let items: [Equipment]
    let checkedItems: Set<String>
    let onToggle: (String) -> Void
    let onToggleAll: () -> Void

    @State private var isExpanded = true

    private var allChecked: Bool {
        !items.isEmpty && items.allSatisfy { checkedItems.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // 分组头部
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(.accent)
                        .font(.caption)

                    Text(category.displayName)
                        .font(.headline)
                        .foregroundColor(.textPrimary)

                    Spacer()

                    Text("\(items.filter { checkedItems.contains($0.id) }.count)/\(items.count)")
                        .font(.caption)
                        .foregroundColor(.textSecondary)

                    Button(action: onToggleAll) {
                        Image(systemName: allChecked ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(allChecked ? .primary : .textSecondary)
                    }

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.textSecondary)
                        .font(.caption)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, Spacing.legacyMd)
            .padding(.vertical, Spacing.sm)
            .background(Color.cardBackground)
            .cornerRadius(8)

            // 装备列表
            if isExpanded {
                ForEach(items) { item in
                    EquipmentRowView(
                        item: item,
                        isChecked: checkedItems.contains(item.id),
                        onToggle: { onToggle(item.id) }
                    )
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

/// 装备行视图
struct EquipmentRowView: View {
    let item: Equipment
    let isChecked: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: Spacing.legacyMd) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isChecked ? .primary : .textSecondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name ?? "未命名装备")
                        .font(.body)
                        .foregroundColor(isChecked ? .textSecondary : .textPrimary)
                        .strikethrough(isChecked)

                    if !item.weightDescription.isEmpty || !item.quantityDescription.isEmpty {
                        HStack(spacing: Spacing.sm) {
                            if !item.weightDescription.isEmpty {
                                Text(item.weightDescription)
                                    .font(.caption)
                                    .foregroundColor(.textTertiary)
                            }
                            if !item.quantityDescription.isEmpty {
                                Text(item.quantityDescription)
                                    .font(.caption)
                                    .foregroundColor(.textTertiary)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.legacyMd)
            .padding(.vertical, Spacing.sm)
            .background(isChecked ? Color.background : Color.cardBackground)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#if DEBUG
#Preview("Equipment List") {
    EquipmentListView()
}

#Preview("Equipment Row") {
    VStack {
        EquipmentRowView(
            item: MockData.equipment[0],
            isChecked: true,
            onToggle: {}
        )
        EquipmentRowView(
            item: MockData.equipment[1],
            isChecked: false,
            onToggle: {}
        )
    }
    .padding()
    .background(Color.groupedBackground)
}
#endif
