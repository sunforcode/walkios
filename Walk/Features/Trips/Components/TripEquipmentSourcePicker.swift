import SwiftUI
import WalkDesignSystem

enum TripEquipmentSourceMode: String, Equatable, CaseIterable {
    case equipment
    case list

    var title: String {
        switch self {
        case .equipment: "个人装备"
        case .list: "常用清单"
        }
    }
}

struct TripEquipmentSourceCandidateProjection: Equatable, Identifiable {
    let identity: String
    let name: String
    let summary: String
    var unavailableReason: String? = nil
    var id: String { identity }
}

struct TripEquipmentSourcePickerProjection: Equatable {
    let mode: TripEquipmentSourceMode
    let candidates: [TripEquipmentSourceCandidateProjection]
    var selectedIdentity: String? = nil
    var quantity = 1
    var isLoading = false
    var loadError: String? = nil
    var operationError: String? = nil
    var isSubmitting = false
    var isPendingRetry = false
    var requiresReload = false
    var offersReload = false
    var canSubmit = false

    var inputsLocked: Bool { isSubmitting || isPendingRetry }
}

extension TripBusinessComponents {
    /// 只显示候选和上层给出的资格，不访问服务或创建命令身份。
    struct TripEquipmentSourcePicker: View {
        let projection: TripEquipmentSourcePickerProjection
        let onSelectSource: (TripEquipmentSourceMode) -> Void
        let onSelectCandidate: (String) -> Void
        let onChangeQuantity: (Int) -> Void
        let onConfirm: () -> Void
        let onRetry: () -> Void
        let onReload: () -> Void
        let onCancel: () -> Void

        var body: some View {
            WalkCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("从已有装备准备本次行程")
                        .font(.sectionTitle)
                        .foregroundStyle(AppColors.textPrimary)
                    Picker("装备来源", selection: Binding(get: { projection.mode }, set: onSelectSource)) {
                        ForEach(TripEquipmentSourceMode.allCases, id: \.self) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(projection.inputsLocked)

                    sourceContent

                    if projection.mode == .equipment, projection.selectedIdentity != nil {
                        FormField(label: "本次数量", requirement: .required) {
                            QuantityStepper(value: Binding(get: { projection.quantity }, set: onChangeQuantity),
                                            minimum: 1, isEnabled: !projection.inputsLocked,
                                            accessibilityLabel: "选入装备本次数量")
                        }
                    }

                    if let error = projection.operationError {
                        ErrorView(message: error, title: "操作未完成", variant: .form)
                    }
                    if projection.isPendingRetry && !projection.isSubmitting {
                        NoticeView(message: "上次操作的结果尚未确认。重试会继续同一次操作，不会重复选入。",
                                   title: "继续确认结果", icon: "arrow.clockwise", tone: .info)
                    }
                    if projection.offersReload {
                        SecondaryAction(title: "重新加载当前清单", isDisabled: projection.isSubmitting,
                                        action: onReload)
                    }
                    PrimaryAction(title: confirmTitle, isLoading: projection.isSubmitting,
                                  isDisabled: projection.isSubmitting || projection.requiresReload || (!projection.canSubmit && !projection.isPendingRetry),
                                  fillsWidth: true, action: projection.isPendingRetry ? onRetry : onConfirm)
                    SecondaryAction(title: "取消", variant: .inline,
                                    isDisabled: projection.inputsLocked, action: onCancel)
                }
            }
        }

        private var confirmTitle: String {
            if projection.isPendingRetry && !projection.isSubmitting { return "重试本次操作" }
            return projection.mode == .equipment ? "选入本次行程" : "追加整份清单"
        }

        @ViewBuilder
        private var sourceContent: some View {
            if projection.isLoading {
                LoadingView(message: "正在加载\(projection.mode.title)", variant: .section)
            } else if let error = projection.loadError {
                ErrorView(message: error, title: "候选加载失败", variant: .section, retry: onRetry)
            } else if projection.candidates.isEmpty {
                EmptyStateView(title: projection.mode == .equipment ? "还没有个人装备" : "还没有常用清单",
                               message: "可以取消选择后管理我的装备，也可以手动新增本次装备。",
                               icon: "backpack", variant: .section)
            } else {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    ForEach(projection.candidates) { candidate in
                        candidateRow(candidate)
                    }
                }
            }
        }

        private func candidateRow(_ candidate: TripEquipmentSourceCandidateProjection) -> some View {
            SelectableOptionCard(
                isSelected: projection.selectedIdentity == candidate.identity,
                isEnabled: !projection.inputsLocked && candidate.unavailableReason == nil,
                action: { onSelectCandidate(candidate.identity) }
            ) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    Image(systemName: projection.selectedIdentity == candidate.identity ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(AppColors.interactionPrimary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(candidate.name)
                            .font(.listTitle)
                            .foregroundStyle(AppColors.textPrimary)
                        Text(candidate.summary)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                        if let reason = candidate.unavailableReason {
                            Text(reason)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.textWeak)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: HitTarget.minimum, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(candidate.name)，\(candidate.summary)\(candidate.unavailableReason.map { "，不可选：\($0)" } ?? "")")
        }
    }
}

#if DEBUG
extension TripEquipmentSourcePickerProjection {
    static let equipment = Self(mode: .equipment, candidates: [
        .init(identity: "bag", name: "轻量背包", summary: "拥有数量 1 · 单件 650.5 g"),
        .init(identity: "water", name: "饮水参考份量", summary: "拥有数量 1 · 单件重量未填写", unavailableReason: "请在本次行程填写实际补给量。")
    ])
    static let list = Self(mode: .list, candidates: [
        .init(identity: "weekend", name: "周末露营清单", summary: "8 项 · 已知重量 4.25 kg · 1 项重量未填写")
    ], selectedIdentity: "weekend", canSubmit: true)
    static let pendingRetry = Self(mode: .equipment, candidates: equipment.candidates, selectedIdentity: "bag", quantity: 2, operationError: "连接中断", isPendingRetry: true, canSubmit: true)
}

#Preview("TripEquipmentSourcePicker.equipment") {
    BusinessComponentPreviewHost { TripBusinessComponents.TripEquipmentSourcePicker.preview(.equipment) }
}
#Preview("TripEquipmentSourcePicker.list") {
    BusinessComponentPreviewHost { TripBusinessComponents.TripEquipmentSourcePicker.preview(.list) }
}
#Preview("TripEquipmentSourcePicker.pendingRetry") {
    BusinessComponentPreviewHost { TripBusinessComponents.TripEquipmentSourcePicker.preview(.pendingRetry) }
}

extension TripBusinessComponents.TripEquipmentSourcePicker {
    static func preview(_ projection: TripEquipmentSourcePickerProjection) -> Self {
        Self(projection: projection, onSelectSource: { _ in }, onSelectCandidate: { _ in },
             onChangeQuantity: { _ in }, onConfirm: {}, onRetry: {}, onReload: {}, onCancel: {})
    }
}
#endif
