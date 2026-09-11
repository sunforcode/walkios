import SwiftUI
import WalkData
import WalkDesignSystem

enum InlineEquipmentEditorField: Hashable {
    case name
    case unitWeight
    case note
}

struct InlineEquipmentEditorProjection: Equatable {
    let title: String
    let name: String
    let quantity: Int
    let unitWeight: String
    let note: String
    var nameError: String? = nil
    var unitWeightError: String? = nil
    var noteError: String? = nil
    var saveError: String? = nil
    var isLoading = false
}

extension AccountEquipmentBusinessComponents {
    struct InlineEquipmentEditor: View {
        let projection: InlineEquipmentEditorProjection
        let onChangeField: (InlineEquipmentEditorField, String) -> Void
        let onChangeQuantity: (Int) -> Void
        let onCancel: () -> Void

        var body: some View {
            WalkCard {
                VStack(alignment: .leading, spacing: Spacing.md) {
                Text(projection.title)
                    .font(.sectionTitle)
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                FormField(label: "名称", requirement: .required, error: projection.nameError) {
                    editorTextInput(
                        text: Binding(get: { projection.name }, set: { onChangeField(.name, $0) }),
                        label: "名称",
                        placeholder: "装备名称"
                    )
                }

                FormField(label: "数量", requirement: .required) {
                    QuantityStepper(
                        value: Binding(get: { projection.quantity }, set: onChangeQuantity),
                        minimum: 1,
                        isEnabled: !projection.isLoading,
                        accessibilityLabel: "本次装备数量"
                    )
                }

                FormField(
                    label: "单件重量",
                    requirement: .optional,
                    assistiveText: "单位：克",
                    error: projection.unitWeightError
                ) {
                    editorTextInput(
                        text: Binding(get: { projection.unitWeight }, set: { onChangeField(.unitWeight, $0) }),
                        label: "单件重量",
                        placeholder: "可暂不填写"
                    )
                    .keyboardType(.numberPad)
                }

                FormField(label: "备注", requirement: .optional, error: projection.noteError) {
                    editorTextInput(
                        text: Binding(get: { projection.note }, set: { onChangeField(.note, $0) }),
                        label: "备注",
                        placeholder: "本次装备备注"
                    )
                }

                if let saveError = projection.saveError {
                    ErrorView(message: saveError, title: "保存失败", variant: .form)
                }

                    SecondaryAction(
                        title: "取消",
                        variant: .inline,
                        isDisabled: projection.isLoading,
                        action: onCancel
                    )
                }
            }
        }

        private func editorTextInput(
            text: Binding<String>,
            label: String,
            placeholder: String
        ) -> some View {
            TextInput(
                text: text,
                label: label,
                placeholder: placeholder,
                isDisabled: projection.isLoading,
                showsLabel: false,
                leading: { EmptyView() },
                trailing: { EmptyView() }
            )
        }
    }
}

#if DEBUG
#Preview("InlineEquipmentEditor.default") {
    BusinessComponentPreviewHost {
        AccountEquipmentBusinessComponents.InlineEquipmentEditor.preview(
            BusinessComponentPreviewFixtures.inlineEquipmentDefault
        )
    }
}

#Preview("InlineEquipmentEditor.validationError") {
    BusinessComponentPreviewHost {
        AccountEquipmentBusinessComponents.InlineEquipmentEditor.preview(
            BusinessComponentPreviewFixtures.inlineEquipmentValidationError
        )
    }
}

#Preview("InlineEquipmentEditor.saveFailed") {
    BusinessComponentPreviewHost {
        AccountEquipmentBusinessComponents.InlineEquipmentEditor.preview(
            BusinessComponentPreviewFixtures.inlineEquipmentSaveFailed
        )
    }
}

private extension AccountEquipmentBusinessComponents.InlineEquipmentEditor {
    static func preview(_ projection: InlineEquipmentEditorProjection) -> Self {
        Self(
            projection: projection,
            onChangeField: { _, _ in },
            onChangeQuantity: { _ in },
            onCancel: {}
        )
    }
}
#endif
