import SwiftUI
import WalkData
import WalkDesignSystem

enum PersonalEquipmentFormField: Hashable {
    case name
    case ownedQuantity
    case unitWeight
}

struct PersonalEquipmentFormProjection: Equatable {
    let name: String
    let ownedQuantity: String
    let unitWeight: String
    var nameError: String? = nil
    var ownedQuantityError: String? = nil
    var unitWeightError: String? = nil
    var saveError: String? = nil
    var isDisabled = false
}

struct PersonalEquipmentForm: View {
    let projection: PersonalEquipmentFormProjection
    let onChangeField: (PersonalEquipmentFormField, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            FormField(label: "装备名称", requirement: .required, error: projection.nameError) {
                formTextInput(
                    text: Binding(get: { projection.name }, set: { onChangeField(.name, $0) }),
                    label: "装备名称",
                    placeholder: "输入装备名称"
                )
            }

            FormField(
                label: "拥有数量",
                requirement: .required,
                assistiveText: "请输入正整数",
                error: projection.ownedQuantityError
            ) {
                formTextInput(
                    text: Binding(get: { projection.ownedQuantity }, set: { onChangeField(.ownedQuantity, $0) }),
                    label: "拥有数量",
                    placeholder: "1"
                )
                .keyboardType(.numberPad)
            }

            FormField(
                label: "单件重量",
                requirement: .optional,
                assistiveText: "单位：克；未填写的装备不计入已知总重量",
                error: projection.unitWeightError
            ) {
                formTextInput(
                    text: Binding(get: { projection.unitWeight }, set: { onChangeField(.unitWeight, $0) }),
                    label: "单件重量（克）",
                    placeholder: "例如 420"
                )
                .keyboardType(.numberPad)
            }

            if let saveError = projection.saveError {
                ErrorView(message: saveError, title: "保存失败", variant: .form)
            }
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private func formTextInput(
        text: Binding<String>,
        label: String,
        placeholder: String
    ) -> some View {
        TextInput(
            text: text,
            label: label,
            placeholder: placeholder,
            isDisabled: projection.isDisabled,
            showsLabel: false,
            leading: { EmptyView() },
            trailing: { EmptyView() }
        )
    }
}

#if DEBUG
#Preview("PersonalEquipmentForm.default") {
    BusinessComponentPreviewHost {
        PersonalEquipmentForm.preview(BusinessComponentPreviewFixtures.personalEquipmentFormDefault)
    }
}

#Preview("PersonalEquipmentForm.create") {
    BusinessComponentPreviewHost {
        PersonalEquipmentForm.preview(BusinessComponentPreviewFixtures.personalEquipmentFormCreate)
    }
}

#Preview("PersonalEquipmentForm.validationError") {
    BusinessComponentPreviewHost {
        PersonalEquipmentForm.preview(BusinessComponentPreviewFixtures.personalEquipmentFormValidationError)
    }
}

#Preview("PersonalEquipmentForm.saveFailed") {
    BusinessComponentPreviewHost {
        PersonalEquipmentForm.preview(BusinessComponentPreviewFixtures.personalEquipmentFormSaveFailed)
    }
}

private extension PersonalEquipmentForm {
    static func preview(_ projection: PersonalEquipmentFormProjection) -> PersonalEquipmentForm {
        PersonalEquipmentForm(projection: projection, onChangeField: { _, _ in })
    }
}
#endif
