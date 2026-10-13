import Foundation
import Observation
import WalkData

@MainActor
@Observable
final class EquipmentEditViewModel {
    private(set) var state: EquipmentEditState

    private let service: any PersonalEquipmentManaging
    @ObservationIgnored private var generation = 0

    init(service: any PersonalEquipmentManaging, equipmentID: String? = nil) {
        self.service = service
        state = EquipmentEditState(mode: EquipmentEditMode(equipmentID: equipmentID))
    }

    func load() async {
        guard case let .edit(equipmentID) = state.mode,
              state.loadState != .loaded, state.loadState != .loading,
              !Task.isCancelled else { return }
        generation += 1
        let request = generation
        state.loadState = .loading
        clearError()
        defer {
            if generation == request, state.loadState == .loading {
                state.loadState = .idle
            }
        }
        do {
            let equipment = try await service.getPersonalEquipment(id: equipmentID)
            guard generation == request, !Task.isCancelled else { return }
            accept(equipment)
            state.loadState = .loaded
        } catch {
            guard generation == request, !Task.isCancelled, !isCancellation(error) else { return }
            apply(error, operation: "加载")
            state.loadState = .failed
        }
    }

    func updateName(_ value: String) {
        guard state.isFormAvailable, !state.isMutating else { return }
        state.draft.name = value
        state.isNameFieldTouched = true
        state.operation = .idle
        if state.errorCode == "equipment_name_conflict" { clearError() }
    }

    func updateCategory(_ value: CatalogEquipmentCategory?) {
        guard state.isFormAvailable, !state.isMutating, state.draft.category != value else { return }
        state.draft.category = value
        if let type = state.draft.equipmentType,
           !EquipmentClassificationOptions.types(for: value).contains(type) {
            state.draft.equipmentType = nil
        }
        state.hasConfirmedWeightForClassification = false
        state.operation = .idle
    }

    func updateEquipmentType(_ value: CatalogEquipmentType?) {
        guard state.isFormAvailable, !state.isMutating, state.draft.equipmentType != value else { return }
        if let value, !EquipmentClassificationOptions.types(for: state.draft.category).contains(value) { return }
        state.draft.equipmentType = value
        state.hasConfirmedWeightForClassification = false
        state.operation = .idle
    }

    func updateQuantity(_ value: String) {
        guard state.isFormAvailable, !state.isMutating else { return }
        state.draft.quantityText = value
        state.isQuantityFieldTouched = true
        state.operation = .idle
    }

    func updateWeight(_ value: String) {
        guard state.isFormAvailable, !state.isMutating else { return }
        state.draft.unitWeightGrams = value
        state.isWeightFieldTouched = true
        state.hasConfirmedWeightForClassification = true
        state.operation = .idle
    }

    func save() async -> Bool {
        guard state.isInputValid, !Task.isCancelled, let quantity = state.draft.parsedQuantity else { return false }
        let draft = state.draft
        let loadedEquipment = state.loadedEquipment
        let mustWriteConfirmedReferenceWeight = loadedEquipment?.unitWeightSource == .catalogReference
            && state.hasClassificationChanges
        if case .edit = state.mode, loadedEquipment == nil { return false }
        state.deletionImpact = nil
        return await mutate(intent: .save, operation: state.mode == .create ? "添加" : "更新") {
            switch self.state.mode {
            case .create:
                return try await self.service.createPersonalEquipment(input: PersonalEquipmentCreateRequest(
                    name: draft.trimmedName,
                    ownedQuantity: quantity,
                    unitWeight: draft.parsedWeight.map { EquipmentWeight(grams: $0) },
                    category: draft.category,
                    equipmentType: draft.equipmentType
                ))
            case let .edit(equipmentID):
                let weight: PersonalEquipmentUpdateField<EquipmentWeight>
                if !mustWriteConfirmedReferenceWeight, draft.parsedWeight == loadedEquipment?.unitWeight?.grams {
                    weight = .unchanged
                } else if let grams = draft.parsedWeight {
                    weight = .value(EquipmentWeight(grams: grams))
                } else {
                    weight = .clear
                }
                return try await self.service.updatePersonalEquipment(
                    id: equipmentID,
                    update: PersonalEquipmentUpdate(
                        name: draft.trimmedName,
                        ownedQuantity: quantity,
                        unitWeight: weight,
                        category: self.changedField(draft.category, original: loadedEquipment?.category),
                        equipmentType: self.changedField(draft.equipmentType, original: loadedEquipment?.equipmentType)
                    )
                )
            }
        } applyResult: { result in
            self.state.savedMutation = result
            self.accept(result.item)
        }
    }

    func prepareDeletion() async -> Bool {
        guard !state.isMutating, !Task.isCancelled, let equipment = state.loadedEquipment,
              case .edit = state.mode, state.loadState == .loaded else { return false }
        state.deletionImpact = nil
        state.confirmation = .none
        return await mutate(intent: .loadDeletionImpact, operation: "读取删除影响") {
            try await self.service.getDeletionImpact(id: equipment.identity)
        } applyResult: { impact in
            self.state.deletionImpact = impact
            self.state.confirmation = .deletion
        }
    }

    func deleteEquipment() async -> Bool {
        guard !state.isMutating, !Task.isCancelled, state.confirmation == .deletion,
              let equipment = state.loadedEquipment,
              state.deletionImpact?.personalEquipmentId == equipment.identity else { return false }
        let requestGeneration = generation + 1
        let deleted = await mutate(intent: .delete, operation: "删除") {
            try await self.service.deletePersonalEquipment(id: equipment.identity)
        } applyResult: { result in
            self.state.deletionResult = result
            self.state.deletionImpact = nil
            self.state.loadedEquipment = nil
            self.state.initialDraft = self.state.draft
        }
        // 失败回到表单展示删除错误；旧请求不得关闭新一轮流程的确认层。
        if generation == requestGeneration, !Task.isCancelled { state.confirmation = .none }
        return deleted
    }

    func requestDismissal() -> Bool {
        guard !state.isMutating else { return false }
        if state.isDirty {
            state.confirmation = .discard
            return false
        }
        return true
    }

    func cancelConfirmation() {
        guard !state.isMutating else { return }
        state.confirmation = .none
    }

    func discardChanges() {
        guard !state.isMutating else { return }
        invalidatePendingOperations()
        state.draft = state.initialDraft
        state.hasConfirmedWeightForClassification = false
        state.confirmation = .none
        clearError()
    }

    func invalidatePendingOperations() {
        generation += 1
        if state.loadState == .loading { state.loadState = .idle }
        // 只淘汰响应，保持写入互斥直到 Service 调用实际返回。
    }

    private func mutate<Result>(
        intent: EquipmentEditState.Intent,
        operation: String,
        request: () async throws -> Result,
        applyResult: (Result) -> Void
    ) async -> Bool {
        guard !state.isMutating, !Task.isCancelled else { return false }
        generation += 1
        let requestGeneration = generation
        state.operation = .running(intent)
        clearError()
        defer {
            if state.operation == .running(intent) {
                state.operation = .idle
            }
        }
        do {
            let result = try await request()
            guard generation == requestGeneration, !Task.isCancelled else { return false }
            applyResult(result)
            return true
        } catch {
            guard generation == requestGeneration, !Task.isCancelled, !isCancellation(error) else { return false }
            apply(error, operation: operation)
            state.operation = .failed(intent)
            return false
        }
    }

    private func accept(_ equipment: PersonalEquipment) {
        state.loadedEquipment = equipment
        state.draft = EquipmentEditDraft(equipment: equipment)
        state.initialDraft = state.draft
        state.isNameFieldTouched = false
        state.isQuantityFieldTouched = false
        state.isWeightFieldTouched = false
        state.hasConfirmedWeightForClassification = false
    }

    private func changedField<Value: Encodable & Equatable>(
        _ value: Value?, original: Value?
    ) -> PersonalEquipmentUpdateField<Value> {
        guard value != original else { return .unchanged }
        return value.map { .value($0) } ?? .clear
    }

    private func clearError() {
        state.errorCode = nil
        state.errorMessage = nil
    }

    private func isCancellation(_ error: Error) -> Bool {
        error is CancellationError || (error as? APIClientError) == .transport(.cancelled)
    }

    private func apply(_ error: Error, operation: String) {
        if case let APIClientError.api(code, _, _, _) = error {
            state.errorCode = code
        } else {
            state.errorCode = nil
        }
        state.errorMessage = (error as? LocalizedError)?.errorDescription
            ?? "\(operation)失败：\(error.localizedDescription)"
    }
}
