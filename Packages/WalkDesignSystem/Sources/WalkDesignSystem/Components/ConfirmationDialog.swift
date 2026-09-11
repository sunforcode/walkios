import SwiftUI

public enum ConfirmationDialogVariant {
    case normal
    case discard
    case danger
}

public struct ConfirmationDialog: View {
     public let title: String
     public let message: String
     public let confirmationTitle: String
     public var cancelTitle: String = "取消"
     public var variant: ConfirmationDialogVariant = .normal
     public var isLoading = false
     public var error: String? = nil
     public let onCancel: () -> Void
     public let onConfirm: () -> Void

    @FocusState private var safeActionIsFocused: Bool

     public var body: some View {
        ZStack {
            AppColors.surfaceModalScrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !isLoading else { return }
                    onCancel()
                }

            WalkPanel(variant: .glass) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text(title)
                            .font(.stateTitle)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        Text(message)
                            .font(.appCaption)
                            .foregroundStyle(AppColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let error {
                            Text(error)
                                .font(.appCaption)
                                .foregroundStyle(AppColors.danger)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("错误：\(error)")
                        }
                    }

                    HStack(alignment: .top, spacing: Spacing.md) {
                        SecondaryAction(
                            title: cancelTitle,
                            isDisabled: isLoading,
                            fillsWidth: true,
                            action: onCancel
                        )
                        .focused($safeActionIsFocused)
                        .keyboardShortcut(.cancelAction)

                        confirmationAction
                    }
                }
            }
            .frame(maxWidth: 320)
            .padding(Spacing.xl)
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            if !isLoading {
                safeActionIsFocused = true
            }
        }
    }

    @ViewBuilder
    private var confirmationAction: some View {
        switch variant {
        case .normal:
            PrimaryAction(
                title: confirmationTitle,
                isLoading: isLoading,
                fillsWidth: true,
                action: onConfirm
            )
        case .discard, .danger:
            DangerAction(
                title: confirmationTitle,
                isLoading: isLoading,
                fillsWidth: true,
                action: onConfirm
            )
        }
    }

    public init(
        title: String,
        message: String,
        confirmationTitle: String,
        cancelTitle: String = "取消",
        variant: ConfirmationDialogVariant = .normal,
        isLoading: Bool = false,
        error: String? = nil,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.confirmationTitle = confirmationTitle
        self.cancelTitle = cancelTitle
        self.variant = variant
        self.isLoading = isLoading
        self.error = error
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }
}

#if DEBUG
#Preview("ConfirmationDialog.normal.idle") {
    ConfirmationDialog(
        title: ComponentPreviewFixtures.confirmationTitle,
        message: ComponentPreviewFixtures.confirmationMessage,
        confirmationTitle: "确认",
        onCancel: {},
        onConfirm: {}
    )
    .background(AppColors.pageBase)
}

#Preview("ConfirmationDialog.danger.idle") {
    ConfirmationDialog(
        title: "删除这项内容？",
        message: ComponentPreviewFixtures.confirmationMessage,
        confirmationTitle: "确认删除",
        variant: .danger,
        onCancel: {},
        onConfirm: {}
    )
    .background(AppColors.pageBase)
}

#Preview("ConfirmationDialog.discard.idle") {
    ConfirmationDialog(
        title: "放弃未保存的修改？",
        message: ComponentPreviewFixtures.confirmationMessage,
        confirmationTitle: "放弃修改",
        cancelTitle: "继续编辑",
        variant: .discard,
        onCancel: {},
        onConfirm: {}
    )
    .background(AppColors.pageBase)
}

#Preview("ConfirmationDialog.normal.loading") {
    ConfirmationDialog(
        title: ComponentPreviewFixtures.confirmationTitle,
        message: ComponentPreviewFixtures.confirmationMessage,
        confirmationTitle: "确认",
        isLoading: true,
        onCancel: {},
        onConfirm: {}
    )
    .background(AppColors.pageBase)
}

#Preview("ConfirmationDialog.normal.error") {
    ConfirmationDialog(
        title: ComponentPreviewFixtures.confirmationTitle,
        message: ComponentPreviewFixtures.confirmationMessage,
        confirmationTitle: "重新确认",
        error: ComponentPreviewFixtures.confirmationError,
        onCancel: {},
        onConfirm: {}
    )
    .background(AppColors.pageBase)
}

#Preview("ConfirmationDialog.danger.loading") {
    ConfirmationDialog(
        title: "删除这项内容？",
        message: ComponentPreviewFixtures.confirmationMessage,
        confirmationTitle: "确认删除",
        variant: .danger,
        isLoading: true,
        onCancel: {},
        onConfirm: {}
    )
    .background(AppColors.pageBase)
}

#Preview("ConfirmationDialog.danger.error") {
    ConfirmationDialog(
        title: "删除这项内容？",
        message: ComponentPreviewFixtures.confirmationMessage,
        confirmationTitle: "重新删除",
        variant: .danger,
        error: ComponentPreviewFixtures.confirmationError,
        onCancel: {},
        onConfirm: {}
    )
    .background(AppColors.pageBase)
}

#Preview("ConfirmationDialog.discard.loading") {
    ConfirmationDialog(
        title: "放弃未保存的修改？",
        message: ComponentPreviewFixtures.confirmationMessage,
        confirmationTitle: "放弃修改",
        cancelTitle: "继续编辑",
        variant: .discard,
        isLoading: true,
        onCancel: {},
        onConfirm: {}
    )
    .background(AppColors.pageBase)
}

#Preview("ConfirmationDialog.discard.error") {
    ConfirmationDialog(
        title: "放弃未保存的修改？",
        message: ComponentPreviewFixtures.confirmationMessage,
        confirmationTitle: "重新放弃",
        cancelTitle: "继续编辑",
        variant: .discard,
        error: ComponentPreviewFixtures.confirmationError,
        onCancel: {},
        onConfirm: {}
    )
    .background(AppColors.pageBase)
}
#endif
