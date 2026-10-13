import SwiftUI
import WalkData
import WalkDesignSystem

enum PersonalEquipmentFormField: Hashable {
    case name
    case category
    case equipmentType
    case ownedQuantity
    case unitWeight
}

struct PersonalEquipmentFormProjection: Equatable {
    let name: String
    let ownedQuantity: String
    let unitWeight: String
    var category: CatalogEquipmentCategory? = nil
    var equipmentType: CatalogEquipmentType? = nil
    var categories: [CatalogEquipmentCategory] = EquipmentClassificationOptions.categories
    var equipmentTypes: [CatalogEquipmentType] = []
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

            SelectInput(
                selection: Binding(
                    get: { projection.category },
                    set: { onChangeField(.category, $0?.rawValue ?? "") }
                ),
                label: "装备分类（可选）",
                placeholder: "请选择分类",
                options: projection.categories.map {
                    SelectInputOption(value: $0, label: EquipmentClassificationOptions.label(for: $0))
                },
                isDisabled: projection.isDisabled
            )

            SelectInput(
                selection: Binding(
                    get: { projection.equipmentType },
                    set: { onChangeField(.equipmentType, $0?.rawValue ?? "") }
                ),
                label: "装备类型（可选）",
                placeholder: "请选择类型",
                options: projection.equipmentTypes.map {
                    SelectInputOption(value: $0, label: EquipmentClassificationOptions.label(for: $0))
                },
                isDisabled: projection.isDisabled || projection.category == nil
            )

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
                .keyboardType(.decimalPad)
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
extension PersonalEquipmentFormProjection {
    static let `default` = PersonalEquipmentFormProjection(
        name: "双人轻量帐篷",
        ownedQuantity: "1",
        unitWeight: "1680",
        category: .tent,
        equipmentType: .tent,
        equipmentTypes: EquipmentClassificationOptions.types(for: .tent)
    )

    static let create = PersonalEquipmentFormProjection(
        name: "",
        ownedQuantity: "1",
        unitWeight: ""
    )

    static let categorySelected = PersonalEquipmentFormProjection(
        name: "冬季睡袋", ownedQuantity: "1", unitWeight: "",
        category: .sleeping,
        equipmentTypes: EquipmentClassificationOptions.types(for: .sleeping)
    )

    static let typeSelected = PersonalEquipmentFormProjection(
        name: "冬季睡袋", ownedQuantity: "1", unitWeight: "1200",
        category: .sleeping, equipmentType: .sleepingBag,
        equipmentTypes: EquipmentClassificationOptions.types(for: .sleeping)
    )

    static let edit = typeSelected

    static let referenceWeightConfirmation = PersonalEquipmentFormProjection(
        name: "冬季睡袋", ownedQuantity: "1", unitWeight: "1200",
        category: .sleeping, equipmentType: .sleepingQuilt,
        equipmentTypes: EquipmentClassificationOptions.types(for: .sleeping),
        unitWeightError: "更改分类或类型后，请重新输入或清空参考重量"
    )

    static let validationError = PersonalEquipmentFormProjection(
        name: " ",
        ownedQuantity: "0",
        unitWeight: "-20",
        nameError: "请输入装备名称",
        ownedQuantityError: "请输入大于零的正整数",
        unitWeightError: "请输入大于零的克重"
    )

    static let saveFailed = PersonalEquipmentFormProjection(
        name: "双人轻量帐篷",
        ownedQuantity: "1",
        unitWeight: "1680",
        category: .tent,
        equipmentType: .tent,
        equipmentTypes: EquipmentClassificationOptions.types(for: .tent),
        saveError: "网络连接中断，当前操作没有完成，请稍后重试。"
    )

    static let previewStates: [(String, Self)] = [
        ("default", .default), ("create", .create),
        ("categorySelected", .categorySelected), ("typeSelected", .typeSelected),
        ("edit", .edit), ("referenceWeightConfirmation", .referenceWeightConfirmation),
        ("validationError", .validationError), ("saveFailed", .saveFailed),
    ]
}

#Preview("PersonalEquipmentForm.default") {
    BusinessComponentPreviewHost {
        PersonalEquipmentForm.preview(PersonalEquipmentFormProjection.default)
    }
}

#Preview("PersonalEquipmentForm.create") {
    BusinessComponentPreviewHost {
        PersonalEquipmentForm.preview(PersonalEquipmentFormProjection.create)
    }
}

#Preview("PersonalEquipmentForm.validationError") {
    BusinessComponentPreviewHost {
        PersonalEquipmentForm.preview(PersonalEquipmentFormProjection.validationError)
    }
}

#Preview("PersonalEquipmentForm.categorySelected") {
    BusinessComponentPreviewHost { PersonalEquipmentForm.preview(.categorySelected) }
}

#Preview("PersonalEquipmentForm.typeSelected") {
    BusinessComponentPreviewHost { PersonalEquipmentForm.preview(.typeSelected) }
}

#Preview("PersonalEquipmentForm.edit") {
    BusinessComponentPreviewHost { PersonalEquipmentForm.preview(.edit) }
}

#Preview("PersonalEquipmentForm.referenceWeightConfirmation") {
    BusinessComponentPreviewHost { PersonalEquipmentForm.preview(.referenceWeightConfirmation) }
}

#Preview("PersonalEquipmentForm.saveFailed") {
    BusinessComponentPreviewHost {
        PersonalEquipmentForm.preview(PersonalEquipmentFormProjection.saveFailed)
    }
}

private extension PersonalEquipmentForm {
    static func preview(_ projection: PersonalEquipmentFormProjection) -> PersonalEquipmentForm {
        PersonalEquipmentForm(projection: projection, onChangeField: { _, _ in })
    }
}
#endif
