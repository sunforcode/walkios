import Foundation
import Observation
import WalkData

@MainActor @Observable
final class TripEquipmentViewModel {
    private(set) var state = TripEquipmentState()
    let tripID: String
    private let service: any TripEquipmentPreparing
    private let equipmentService: (any EquipmentServicing)?
    private let makeIdempotencyKey: () -> String
    private let onRevisionChange: (String) -> Void
    @ObservationIgnored private var hasLoaded = false
    @ObservationIgnored private var shouldRecheckOnAppearance = false
    @ObservationIgnored private var loading: TripRequestLifetime?
    @ObservationIgnored private var sourceLoading: TripRequestLifetime?

    var projection: TripEquipmentProjection? { state.projection }
    var isLoading: Bool { state.isLoading }
    var isMutating: Bool { state.isMutating }
    var errorMessage: String? { state.errorMessage }
    var isEditable: Bool { projection?.editable == true }
    var editorNameError: String? { state.draft.nameError }
    var editorUnitWeightError: String? { state.draft.unitWeightError }
    var editorInputIsValid: Bool { state.draft.isValid }

    init(tripID: String, service: any TripEquipmentPreparing,
         equipmentService: (any EquipmentServicing)? = nil,
         makeIdempotencyKey: @escaping () -> String = { UUID().uuidString },
         onRevisionChange: @escaping (String) -> Void = { _ in }) {
        self.tripID = tripID
        self.service = service
        self.equipmentService = equipmentService
        self.makeIdempotencyKey = makeIdempotencyKey
        self.onRevisionChange = onRevisionChange
    }

    func load() async {
        guard !Task.isCancelled, !isMutating, state.pendingSourceCommand == nil,
              loading == nil || loading?.isCancelled == true else { return }
        let request = TripRequestLifetime()
        loading = request
        state.phase = .loading
        state.errorMessage = nil
        defer {
            if loading === request {
                loading = nil
                state.phase = .idle
            }
        }
        await withTaskCancellationHandler {
            do {
                let projection = try await service.getEquipment(tripID: tripID)
                guard loading === request, !request.isCancelled, !Task.isCancelled else { return }
                state.projection = projection
                state.requiresReload = false
                state.offersReload = false
                hasLoaded = true
                onRevisionChange(projection.revision)
            } catch {
                guard loading === request, !request.isCancelled, !Task.isCancelled,
                      !tripRequestWasCancelled(error) else { return }
                state.errorMessage = message(for: error, operation: "加载")
            }
        } onCancel: {
            request.cancel()
        }
    }

    func prepareForPersonalEquipment() { shouldRecheckOnAppearance = true }

    func handleAppearance() async {
        guard state.pendingSourceCommand == nil else { return }
        guard hasLoaded else { await load(); return }
        if shouldRecheckOnAppearance {
            if await recheckOwnership() { shouldRecheckOnAppearance = false }
            return
        }
        await load()
        if state.sourceMode != nil { await loadSourceCandidates() }
    }

    func beginAdding() {
        guard isEditable, !isMutating, state.sourceMode == nil, !state.requiresReload else { return }
        state.editor = .adding
        state.draft = .init()
        state.errorMessage = nil
    }

    func beginEditing(_ item: TripEquipmentItem) {
        guard isEditable, !isMutating, state.sourceMode == nil, !state.requiresReload else { return }
        state.editor = .editing(item)
        state.draft = .init(name: item.name, quantity: item.quantity,
                            unitWeight: item.unitWeight.map { AccountEquipmentFormatting.decimalText($0.grams) } ?? "", note: item.note ?? "")
        state.errorMessage = nil
    }

    func updateName(_ value: String) { guard !isMutating else { return }; state.draft.name = value }
    func updateQuantity(_ value: Int) { guard !isMutating else { return }; state.draft.quantity = value }
    func updateUnitWeight(_ value: String) { guard !isMutating else { return }; state.draft.unitWeight = value }
    func updateNote(_ value: String) { guard !isMutating else { return }; state.draft.note = value }

    func cancelEditing() {
        guard !isMutating else { return }
        state.editor = nil
        state.errorMessage = nil
    }

    func requestDelete(_ item: TripEquipmentItem) {
        guard isEditable, !isMutating, state.sourceMode == nil, !state.requiresReload else { return }
        state.deletingItem = item
        state.deletionError = nil
    }

    func cancelDeletion() {
        guard !isMutating else { return }
        state.deletingItem = nil
        state.deletionError = nil
        state.errorMessage = nil
    }

    @discardableResult
    func confirmDeletion() async -> Bool {
        guard !isMutating, let item = state.deletingItem else { return false }
        state.deletionError = nil
        let succeeded = await deleteItem(itemID: item.identity)
        if succeeded {
            state.deletingItem = nil
        } else {
            state.deletionError = state.errorMessage
        }
        return succeeded
    }

    @discardableResult
    func saveEditor() async -> Bool {
        guard !Task.isCancelled, isEditable, !isMutating, !state.requiresReload,
              let editor = state.editor, editorInputIsValid else { return false }
        let draft = state.draft
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let weightText = draft.unitWeight.trimmingCharacters(in: .whitespacesAndNewlines)
        let noteText = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let weight = weightText.isEmpty ? nil : Double(weightText)
        let note = noteText.isEmpty ? nil : noteText
        let succeeded: Bool
        switch editor {
        case .adding:
            succeeded = await addItem(input: TripEquipmentItemCreate(name: name, quantity: draft.quantity, unitWeight: weight.map { EquipmentWeight(grams: $0) }, note: note))
        case .editing(let item):
            let nameChanged = name != item.name
            let quantityChanged = draft.quantity != item.quantity
            let weightChanged = weight != item.unitWeight?.grams
            let noteChanged = note != item.note
            guard nameChanged || quantityChanged || weightChanged || noteChanged else {
                state.editor = nil
                state.errorMessage = nil
                return true
            }
            succeeded = await updateItem(itemID: item.identity, update: TripEquipmentItemUpdate(
                name: nameChanged ? name : nil,
                quantity: quantityChanged ? draft.quantity : nil,
                unitWeight: weightChanged ? (weight.map { .value(EquipmentWeight(grams: $0)) } ?? .clear) : .unchanged,
                note: noteChanged ? (note.map(TripEquipmentUpdateField.value) ?? .clear) : .unchanged
            ))
        }
        if succeeded { state.editor = nil }
        return succeeded
    }

    @discardableResult
    func addItem(name: String, quantity: Int, unitWeightGrams: Int?, note: String?) async -> Bool {
        await addItem(input: TripEquipmentItemCreate(name: name, quantity: quantity,
            unitWeight: unitWeightGrams.map { EquipmentWeight(grams: $0) }, note: note))
    }

    @discardableResult
    func addItem(input: TripEquipmentItemCreate) async -> Bool {
        await mutate(operation: "添加") { revision in
            try await service.addItem(tripID: tripID, input: input, revision: revision)
        }
    }

    @discardableResult
    func updateItem(itemID: String, update: TripEquipmentItemUpdate) async -> Bool {
        await mutate(operation: "更新") { revision in
            try await service.updateItem(tripID: tripID, itemID: itemID, update: update, revision: revision)
        }
    }

    @discardableResult
    func deleteItem(itemID: String) async -> Bool {
        await mutate(operation: "删除") { revision in
            try await service.deleteItem(tripID: tripID, itemID: itemID, revision: revision)
        }
    }

    @discardableResult
    func recheckOwnership() async -> Bool {
        await mutate(operation: "重新核对") { revision in
            try await service.recheckOwnership(tripID: tripID, revision: revision)
        }
    }

    private func mutate(operation: String, allowsPendingSource: Bool = false,
                        action: (String) async throws -> TripEquipmentProjection) async -> Bool {
        guard !Task.isCancelled, !isMutating, isEditable, !state.requiresReload,
              allowsPendingSource || state.pendingSourceCommand == nil,
              let revision = projection?.revision else { return false }
        // A read started before this write may never publish again, even if the write fails.
        loading?.cancel()
        loading = nil
        state.phase = .mutating
        state.errorMessage = nil
        defer { state.phase = .idle }
        do {
            let projection = try await action(revision)
            guard !Task.isCancelled else { return false }
            state.projection = projection
            state.requiresReload = false
            state.offersReload = false
            onRevisionChange(projection.revision)
            return true
        } catch {
            guard !Task.isCancelled, !tripRequestWasCancelled(error) else { return false }
            if case let APIClientError.api(code, _, _, _) = error {
                state.requiresReload = code == "concurrent_modification"
                state.offersReload = code == "concurrent_modification" || code == "equipment_name_conflict"
            }
            state.errorMessage = message(for: error, operation: operation)
            return false
        }
    }

    private func message(for error: Error, operation: String) -> String {
        if case let APIClientError.api(code, message, _, _) = error {
            if code == "concurrent_modification" {
                return "行程装备已变化。请重新加载后再提交，当前输入会保留。"
            }
            if code == "equipment_name_conflict" {
                return "已有同名装备，未自动合并。请调整名称或来源，也可重新加载查看当前清单。"
            }
            return message
        }
        return (error as? LocalizedError)?.errorDescription ?? "\(operation)失败：\(error.localizedDescription)"
    }
}

extension TripEquipmentViewModel {
    var canSelectSource: Bool { equipmentService != nil }

    var sourcePickerProjection: TripEquipmentSourcePickerProjection? {
        guard let mode = state.sourceMode else { return nil }
        let candidates: [TripEquipmentSourceCandidateProjection]
        switch mode {
        case .equipment:
            candidates = state.personalCandidates.map { item in
                let weight = item.unitWeight.map { "单件 \(AccountEquipmentFormatting.weightText(grams: $0.grams))" } ?? "单件重量未填写"
                return .init(identity: item.identity, name: item.name,
                             summary: "拥有数量 \(item.ownedQuantity) · \(weight)",
                             unavailableReason: Self.isSupply(item) ? "请在本次行程填写实际补给量，不能直接选入参考份量。" : nil)
            }
        case .list:
            candidates = state.listCandidates.map { list in
                var summary = "\(list.summary.itemCount) 项 · 已知重量 \(AccountEquipmentFormatting.weightText(grams: list.summary.knownTotalWeight.grams))"
                if list.summary.missingWeightItemCount > 0 { summary += " · \(list.summary.missingWeightItemCount) 项重量未填写" }
                return .init(identity: list.identity, name: list.name, summary: summary)
            }
        }
        return .init(mode: mode, candidates: candidates, selectedIdentity: state.selectedSourceID,
                     quantity: state.sourceQuantity, isLoading: state.isSourceLoading,
                     loadError: state.sourceLoadError, operationError: state.errorMessage,
                     isSubmitting: isMutating, isPendingRetry: state.pendingSourceCommand != nil,
                     requiresReload: state.requiresReload, offersReload: state.offersReload,
                     canSubmit: selectedSourceIsValid && !state.isSourceLoading && !state.requiresReload)
    }

    private var selectedSourceIsValid: Bool {
        guard let identity = state.selectedSourceID else { return false }
        switch state.sourceMode {
        case .equipment:
            return state.sourceQuantity > 0 && state.personalCandidates.contains { $0.identity == identity && !Self.isSupply($0) }
        case .list:
            return state.listCandidates.contains { $0.identity == identity }
        case nil:
            return false
        }
    }

    func beginSelectingSource(_ mode: TripEquipmentSourceMode) async {
        guard !Task.isCancelled, canSelectSource, isEditable, !isMutating,
              state.editor == nil, state.pendingSourceCommand == nil else { return }
        sourceLoading?.cancel()
        sourceLoading = nil
        state.sourceMode = mode
        state.selectedSourceID = nil
        state.sourceQuantity = 1
        state.personalCandidates = []
        state.listCandidates = []
        if !state.requiresReload { state.errorMessage = nil }
        await loadSourceCandidates()
    }

    func loadSourceCandidates() async {
        guard !Task.isCancelled, !isMutating, state.pendingSourceCommand == nil,
              let mode = state.sourceMode, let equipmentService,
              sourceLoading == nil || sourceLoading?.isCancelled == true else { return }
        let request = TripRequestLifetime()
        sourceLoading = request
        state.isSourceLoading = true
        state.sourceLoadError = nil
        defer {
            if sourceLoading === request {
                sourceLoading = nil
                state.isSourceLoading = false
            }
        }
        await withTaskCancellationHandler {
            do {
                switch mode {
                case .equipment:
                    let response = try await equipmentService.getPersonalEquipment()
                    guard sourceLoading === request, !request.isCancelled, !Task.isCancelled else { return }
                    state.personalCandidates = response.items
                case .list:
                    let response = try await equipmentService.getEquipmentLists()
                    guard sourceLoading === request, !request.isCancelled, !Task.isCancelled else { return }
                    state.listCandidates = response.items
                }
            } catch {
                guard sourceLoading === request, !request.isCancelled, !Task.isCancelled,
                      !tripRequestWasCancelled(error) else { return }
                state.sourceLoadError = message(for: error, operation: "加载候选")
            }
        } onCancel: {
            request.cancel()
        }
    }

    func selectSourceCandidate(_ identity: String) {
        guard !isMutating, !state.isSourceLoading, state.pendingSourceCommand == nil else { return }
        switch state.sourceMode {
        case .equipment:
            guard state.personalCandidates.contains(where: { $0.identity == identity && !Self.isSupply($0) }) else { return }
        case .list:
            guard state.listCandidates.contains(where: { $0.identity == identity }) else { return }
        case nil:
            return
        }
        state.selectedSourceID = identity
        if !state.requiresReload { state.errorMessage = nil }
    }

    func updateSourceQuantity(_ quantity: Int) {
        guard !isMutating, state.pendingSourceCommand == nil, state.sourceMode == .equipment else { return }
        state.sourceQuantity = quantity
    }

    func cancelSourceSelection() {
        // 取消界面不代表服务器撤销。结果未知时保留原操作，先完成明确重试。
        guard !isMutating, state.pendingSourceCommand == nil else { return }
        sourceLoading?.cancel()
        sourceLoading = nil
        state.isSourceLoading = false
        state.sourceMode = nil
        state.selectedSourceID = nil
        state.sourceLoadError = nil
        if !state.requiresReload { state.errorMessage = nil }
    }

    @discardableResult
    func confirmSourceSelection() async -> Bool {
        guard !Task.isCancelled, isEditable, !isMutating, !state.requiresReload else { return false }
        let command: TripEquipmentState.SourceCommand
        if let pending = state.pendingSourceCommand {
            command = pending
        } else {
            guard selectedSourceIsValid, let mode = state.sourceMode,
                  let identity = state.selectedSourceID, let revision = projection?.revision else { return false }
            command = .init(mode: mode, identity: identity, quantity: state.sourceQuantity,
                            revision: revision, idempotencyKey: makeIdempotencyKey())
            state.pendingSourceCommand = command
        }
        let succeeded = await mutate(operation: "选入装备", allowsPendingSource: true) { _ in
            do {
                switch command.mode {
                case .equipment:
                    return try await service.addFromPersonal(tripID: tripID, personalEquipmentID: command.identity,
                        quantity: command.quantity, revision: command.revision, idempotencyKey: command.idempotencyKey)
                case .list:
                    return try await service.appendList(tripID: tripID, equipmentListID: command.identity,
                        revision: command.revision, idempotencyKey: command.idempotencyKey)
                }
            } catch {
                if Self.isDefiniteRejection(error) { state.pendingSourceCommand = nil }
                throw error
            }
        }
        if succeeded {
            state.pendingSourceCommand = nil
            state.sourceMode = nil
            state.selectedSourceID = nil
        }
        return succeeded
    }

    func retrySource() async {
        if state.pendingSourceCommand != nil {
            _ = await confirmSourceSelection()
        } else {
            await loadSourceCandidates()
        }
    }

    func reloadAfterConflict() async {
        // 保留编辑和来源草稿；只有取得新快照后解除版本冲突门控，不自动提交。
        await load()
    }

    private static func isSupply(_ item: PersonalEquipment) -> Bool {
        let categories: Set<CatalogEquipmentCategory> = [.food, .drinkingWater, .fuel]
        let types: Set<CatalogEquipmentType> = [.food, .drinkingWater, .fuel]
        return item.category.map(categories.contains) == true || item.equipmentType.map(types.contains) == true
    }

    private static func isDefiniteRejection(_ error: Error) -> Bool {
        switch error {
        case let APIClientError.api(code, _, _, _):
            // retryable 只说明稍后重试是否可能成功，不证明第一次命令未执行。
            // 仅权威合同中明确拒绝修改的错误，才允许结束首次命令身份。
            let rejectionCodes: Set<String> = [
                "invalid_request", "authentication_required", "resource_not_found",
                "concurrent_modification", "idempotency_conflict", "equipment_name_conflict",
                "trip_equipment_read_only", "relationship_inconsistent", "validation_failed"
            ]
            return rejectionCodes.contains(code)
        case let APIClientError.http(statusCode):
            // 超时（408）与未知状态不证明命令未提交；继续用首次内容和键确认结果。
            return [400, 401, 403, 404, 405, 409, 410, 413, 415, 422, 429].contains(statusCode)
        default: return false
        }
    }
}
