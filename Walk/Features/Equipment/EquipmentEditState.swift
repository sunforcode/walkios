import Foundation
import WalkData

enum EquipmentEditMode: Equatable {
    case create
    case edit(equipmentID: String)

    init(equipmentID: String?) {
        if let equipmentID {
            self = .edit(equipmentID: equipmentID)
        } else {
            self = .create
        }
    }
}

enum EquipmentEditLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed
}

struct EquipmentEditDraft: Equatable {
    var name = ""
    var category: CatalogEquipmentCategory?
    var equipmentType: CatalogEquipmentType?
    var quantityText = "1"
    var unitWeightGrams = ""

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var parsedQuantity: Int? { Int(quantityText.trimmingCharacters(in: .whitespacesAndNewlines)) }
    var trimmedWeight: String { unitWeightGrams.trimmingCharacters(in: .whitespacesAndNewlines) }
    var parsedWeight: Double? {
        guard !trimmedWeight.isEmpty, let weight = Double(trimmedWeight), weight.isFinite else { return nil }
        return weight
    }

    func matches(_ other: Self) -> Bool {
        trimmedName == other.trimmedName
            && category == other.category
            && equipmentType == other.equipmentType
            && (parsedQuantity ?? 0) == (other.parsedQuantity ?? 0)
            && trimmedWeight == other.trimmedWeight
    }

    init() {}

    init(equipment: PersonalEquipment) {
        name = equipment.name
        category = equipment.category
        equipmentType = equipment.equipmentType
        quantityText = String(equipment.ownedQuantity)
        unitWeightGrams = equipment.unitWeight.map { AccountEquipmentFormatting.decimalText($0.grams) } ?? ""
    }
}

struct EquipmentEditState {
    enum Intent: Equatable {
        case save
        case loadDeletionImpact
        case delete
    }

    enum Operation: Equatable {
        case idle
        case running(Intent)
        case failed(Intent)
    }

    enum Confirmation: Equatable {
        case none
        case discard
        case deletion
    }

    let mode: EquipmentEditMode
    var loadState: EquipmentEditLoadState = .idle
    var loadedEquipment: PersonalEquipment?
    var draft = EquipmentEditDraft()
    var initialDraft = EquipmentEditDraft()
    var isNameFieldTouched = false
    var isQuantityFieldTouched = false
    var isWeightFieldTouched = false
    var hasConfirmedWeightForClassification = false
    var operation: Operation = .idle
    var confirmation: Confirmation = .none
    var errorCode: String?
    var errorMessage: String?
    var deletionImpact: PersonalEquipmentDeletionImpact?
    var savedMutation: PersonalEquipmentMutation?
    var deletionResult: PersonalEquipmentDeletionResult?

    var isMutating: Bool {
        if case .running = operation { return true }
        return false
    }

    var isFormAvailable: Bool { mode == .create || loadState == .loaded }
    var isDirty: Bool { isFormAvailable && !draft.matches(initialDraft) }

    var nameFieldError: String? {
        if errorCode == "equipment_name_conflict" { return errorMessage }
        return isNameFieldTouched && draft.trimmedName.isEmpty ? "请输入装备名称" : nil
    }

    var quantityFieldError: String? {
        guard isQuantityFieldTouched else { return nil }
        return (draft.parsedQuantity ?? 0) > 0 ? nil : "请输入大于零的正整数"
    }

    var hasClassificationChanges: Bool {
        draft.category != initialDraft.category || draft.equipmentType != initialDraft.equipmentType
    }

    var needsReferenceWeightConfirmation: Bool {
        loadedEquipment?.unitWeightSource == .catalogReference
            && hasClassificationChanges
            && !hasConfirmedWeightForClassification
    }

    var isClassificationValid: Bool {
        guard let type = draft.equipmentType else { return true }
        return EquipmentClassificationOptions.types(for: draft.category).contains(type)
    }

    var weightFieldError: String? {
        if needsReferenceWeightConfirmation {
            return "更改分类或类型后，请重新输入或清空参考重量"
        }
        guard isWeightFieldTouched, !draft.trimmedWeight.isEmpty else { return nil }
        return (draft.parsedWeight ?? 0) > 0 ? nil : "请输入大于零的克重"
    }

    var isInputValid: Bool {
        isFormAvailable
            && !draft.trimmedName.isEmpty
            && draft.parsedQuantity.map { $0 > 0 } == true
            && (draft.trimmedWeight.isEmpty || draft.parsedWeight.map { $0 > 0 } == true)
            && isClassificationValid
            && !needsReferenceWeightConfirmation
            && errorCode != "equipment_name_conflict"
            && !isMutating
    }

    var saveErrorMessage: String? {
        guard operation == .failed(.save), errorCode != "equipment_name_conflict" else { return nil }
        return errorMessage
    }

    var deletionErrorMessage: String? {
        guard operation == .failed(.loadDeletionImpact) || operation == .failed(.delete) else { return nil }
        return errorMessage
    }

    var deletionMessage: String {
        let prefix = "删除后会从用户装备清单移除，但不会修改已经生成的行程装备。"
        guard let impact = deletionImpact, impact.equipmentListReferenceCount > 0 else { return prefix }
        let names = impact.affectedEquipmentLists.map(\.name).joined(separator: "、")
        return "\(prefix) 当前会影响 \(impact.equipmentListReferenceCount) 份用户清单：\(names)。"
    }
}
