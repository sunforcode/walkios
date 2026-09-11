import SwiftUI
import WalkData
import WalkDesignSystem

enum InlineListNameEditorMode: Equatable {
    case create
    case rename
}

struct InlineListNameEditorProjection: Equatable {
    let mode: InlineListNameEditorMode
    let name: String
    var fieldError: String? = nil
    var saveError: String? = nil
    var isLoading = false
}

struct InlineListNameEditor: View {
    let projection: InlineListNameEditorProjection
    let onChangeName: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(projection.mode == .create ? "创建装备清单" : "重命名装备清单")
                .font(.listTitle)
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            FormField(
                label: projection.mode == .create ? "清单名称" : "新的清单名称",
                requirement: .required,
                error: projection.fieldError
            ) {
                TextInput(
                    text: Binding(get: { projection.name }, set: onChangeName),
                    label: "清单名称",
                    placeholder: "输入清单名称",
                    isDisabled: projection.isLoading,
                    showsLabel: false,
                    leading: { EmptyView() },
                    trailing: { EmptyView() }
                )
            }

            if let saveError = projection.saveError {
                ErrorView(message: saveError, title: "保存清单失败", variant: .form)
            }

            SecondaryAction(
                title: "取消",
                variant: .inline,
                isDisabled: projection.isLoading,
                action: onCancel
            )
        }
        .padding(Spacing.md)
        .background(AppColors.interactionBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .stroke(AppColors.interactionPrimary.opacity(0.25), lineWidth: 1)
        }
    }
}

#if DEBUG
#Preview("InlineListNameEditor.default") {
    BusinessComponentPreviewHost {
        InlineListNameEditor.preview(BusinessComponentPreviewFixtures.inlineListDefault)
    }
}

#Preview("InlineListNameEditor.validationError") {
    BusinessComponentPreviewHost {
        InlineListNameEditor.preview(BusinessComponentPreviewFixtures.inlineListValidationError)
    }
}

#Preview("InlineListNameEditor.saveFailed") {
    BusinessComponentPreviewHost {
        InlineListNameEditor.preview(BusinessComponentPreviewFixtures.inlineListSaveFailed)
    }
}

private extension InlineListNameEditor {
    static func preview(_ projection: InlineListNameEditorProjection) -> InlineListNameEditor {
        InlineListNameEditor(projection: projection, onChangeName: { _ in }, onCancel: {})
    }
}
#endif
