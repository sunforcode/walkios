import Foundation
import SwiftUI

struct TripEquipmentTrip: Codable, Equatable {
    let identity: String
    let status: PersonalTripStatus
    let routeName: String
    let startDate: LocalDate
    let endDate: LocalDate
}

enum TripEquipmentItemSource: String, Codable, Equatable {
    case systemSuggestion = "system_suggestion"
    case userAdjusted = "user_adjusted"
    case userAdded = "user_added"
}

enum TripEquipmentOwnershipStatus: String, Codable, Equatable {
    case owned
    case unconfirmedOwned = "unconfirmed_owned"
}

struct TripEquipmentItem: Codable, Equatable, Identifiable {
    let identity: String
    let name: String
    let quantity: Int
    let unitWeight: EquipmentWeight?
    let note: String?
    let source: TripEquipmentItemSource
    let ownershipStatus: TripEquipmentOwnershipStatus

    var id: String { identity }
    var totalWeight: EquipmentWeight? {
        unitWeight.map { EquipmentWeight(grams: $0.grams * quantity) }
    }

    enum CodingKeys: String, CodingKey {
        case identity, name, quantity, unitWeight, note, source, ownershipStatus
    }
}

struct TripEquipmentSnapshot: Codable, Equatable {
    let identity: String
    let items: [TripEquipmentItem]
    let summary: PersonalTripEquipmentSummary
}

struct TripEquipmentProjection: Codable, Equatable {
    let trip: TripEquipmentTrip
    let revision: String
    let editable: Bool
    let snapshot: TripEquipmentSnapshot
}

enum TripEquipmentUpdateField<Value: Encodable & Equatable>: Encodable, Equatable {
    case unchanged
    case value(Value)
    case clear

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .unchanged, .clear:
            try container.encodeNil()
        case .value(let value):
            try container.encode(value)
        }
    }
}

struct TripEquipmentItemUpdate: Encodable, Equatable {
    let name: String?
    let quantity: Int?
    let unitWeight: TripEquipmentUpdateField<EquipmentWeight>
    let note: TripEquipmentUpdateField<String>

    init(
        name: String? = nil,
        quantity: Int? = nil,
        unitWeight: TripEquipmentUpdateField<EquipmentWeight> = .unchanged,
        note: TripEquipmentUpdateField<String> = .unchanged
    ) {
        self.name = name
        self.quantity = quantity
        self.unitWeight = unitWeight
        self.note = note
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let name { try container.encode(name, forKey: .name) }
        if let quantity { try container.encode(quantity, forKey: .quantity) }
        if unitWeight != .unchanged { try container.encode(unitWeight, forKey: .unitWeight) }
        if note != .unchanged { try container.encode(note, forKey: .note) }
    }

    private enum CodingKeys: String, CodingKey {
        case name, quantity, unitWeight, note
    }
}

private struct CreateTripEquipmentItemBody: Encodable {
    let name: String
    let quantity: Int
    let unitWeight: EquipmentWeight?
    let note: String?
}

enum TripEquipmentAPI {
    struct Current: APIRequest {
        typealias Response = TripEquipmentProjection
        let method: APIHTTPMethod = .get
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data
        let storagePolicy: APIStoragePolicy = .store

        init(tripID: String) {
            path = "/trips/\(tripID)/equipment"
        }
    }

    struct CreateItem: APIRequest {
        typealias Response = TripEquipmentProjection
        let method: APIHTTPMethod = .post
        let path: String
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(
            tripID: String,
            name: String,
            quantity: Int,
            unitWeightGrams: Int?,
            note: String?
        ) throws {
            path = "/trips/\(tripID)/equipment/items"
            body = try JSONEncoder().encode(CreateTripEquipmentItemBody(
                name: name,
                quantity: quantity,
                unitWeight: unitWeightGrams.map(EquipmentWeight.init(grams:)),
                note: note
            ))
        }
    }

    struct UpdateItem: APIRequest {
        typealias Response = TripEquipmentProjection
        let method: APIHTTPMethod = .patch
        let path: String
        let body: Data?
        let responseEnvelope: APIResponseEnvelope = .data

        init(tripID: String, itemID: String, update: TripEquipmentItemUpdate) throws {
            path = "/trips/\(tripID)/equipment/items/\(itemID)"
            body = try JSONEncoder().encode(update)
        }
    }

    struct DeleteItem: APIRequest {
        typealias Response = TripEquipmentProjection
        let method: APIHTTPMethod = .delete
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data

        init(tripID: String, itemID: String) {
            path = "/trips/\(tripID)/equipment/items/\(itemID)"
        }
    }

    struct RecheckOwnership: APIRequest {
        typealias Response = TripEquipmentProjection
        let method: APIHTTPMethod = .post
        let path: String
        let responseEnvelope: APIResponseEnvelope = .data

        init(tripID: String) {
            path = "/trips/\(tripID)/equipment:recheck-ownership"
        }
    }
}

protocol TripEquipmentServicing {
    func getEquipment(tripID: String) async throws -> TripEquipmentProjection
    func addItem(
        tripID: String,
        name: String,
        quantity: Int,
        unitWeightGrams: Int?,
        note: String?
    ) async throws -> TripEquipmentProjection
    func updateItem(
        tripID: String,
        itemID: String,
        update: TripEquipmentItemUpdate
    ) async throws -> TripEquipmentProjection
    func deleteItem(tripID: String, itemID: String) async throws -> TripEquipmentProjection
    func recheckOwnership(tripID: String) async throws -> TripEquipmentProjection
}

struct TripEquipmentService: TripEquipmentServicing {
    let apiClient: any APIClient

    func getEquipment(tripID: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.Current(tripID: tripID))
    }

    func addItem(
        tripID: String,
        name: String,
        quantity: Int,
        unitWeightGrams: Int?,
        note: String?
    ) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.CreateItem(
            tripID: tripID,
            name: name,
            quantity: quantity,
            unitWeightGrams: unitWeightGrams,
            note: note
        ))
    }

    func updateItem(
        tripID: String,
        itemID: String,
        update: TripEquipmentItemUpdate
    ) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.UpdateItem(
            tripID: tripID,
            itemID: itemID,
            update: update
        ))
    }

    func deleteItem(tripID: String, itemID: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.DeleteItem(tripID: tripID, itemID: itemID))
    }

    func recheckOwnership(tripID: String) async throws -> TripEquipmentProjection {
        try await apiClient.execute(TripEquipmentAPI.RecheckOwnership(tripID: tripID))
    }
}

@MainActor
final class TripEquipmentViewModel: ObservableObject {
    @Published var projection: TripEquipmentProjection?
    @Published var isLoading = false
    @Published var isMutating = false
    @Published var errorMessage: String?

    let tripID: String
    private let service: any TripEquipmentServicing
    private var hasLoaded = false
    private var shouldRecheckOnAppearance = false

    var isEditable: Bool { projection?.editable == true }

    init(tripID: String, service: any TripEquipmentServicing) {
        self.tripID = tripID
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            projection = try await service.getEquipment(tripID: tripID)
            hasLoaded = true
        } catch {
            errorMessage = message(for: error, operation: "加载")
        }
    }

    func prepareForPersonalEquipment() {
        shouldRecheckOnAppearance = true
    }

    func handleAppearance() async {
        guard hasLoaded else {
            await load()
            return
        }
        guard shouldRecheckOnAppearance else { return }
        shouldRecheckOnAppearance = false
        await recheckOwnership()
    }

    func addItem(name: String, quantity: Int, unitWeightGrams: Int?, note: String?) async {
        await mutate(operation: "添加") {
            try await service.addItem(
                tripID: tripID,
                name: name,
                quantity: quantity,
                unitWeightGrams: unitWeightGrams,
                note: note
            )
        }
    }

    func updateItem(itemID: String, update: TripEquipmentItemUpdate) async {
        await mutate(operation: "更新") {
            try await service.updateItem(tripID: tripID, itemID: itemID, update: update)
        }
    }

    func deleteItem(itemID: String) async {
        await mutate(operation: "删除") {
            try await service.deleteItem(tripID: tripID, itemID: itemID)
        }
    }

    func recheckOwnership() async {
        await mutate(operation: "重新核对") {
            try await service.recheckOwnership(tripID: tripID)
        }
    }

    private func mutate(
        operation: String,
        action: () async throws -> TripEquipmentProjection
    ) async {
        isMutating = true
        errorMessage = nil
        defer { isMutating = false }
        do {
            projection = try await action()
        } catch {
            errorMessage = message(for: error, operation: operation)
        }
    }

    private func message(for error: Error, operation: String) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription {
            return description
        }
        return "\(operation)失败：\(error.localizedDescription)"
    }
}

struct TripEquipmentView: View {
    @StateObject private var viewModel: TripEquipmentViewModel
    @State private var isAddingItem = false
    @State private var editingItem: TripEquipmentItem?
    @State private var deletingItem: TripEquipmentItem?
    private let onManagePersonalEquipment: () -> Void
    private let onRevisionChange: (String) -> Void

    init(
        tripID: String,
        service: any TripEquipmentServicing,
        onManagePersonalEquipment: @escaping () -> Void = {},
        onRevisionChange: @escaping (String) -> Void = { _ in }
    ) {
        _viewModel = StateObject(wrappedValue: TripEquipmentViewModel(
            tripID: tripID,
            service: service
        ))
        self.onManagePersonalEquipment = onManagePersonalEquipment
        self.onRevisionChange = onRevisionChange
    }

    var body: some View {
        UtilityPageContainer {
            Group {
                if viewModel.isLoading && viewModel.projection == nil {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.projection == nil {
                    ErrorView(message: error) {
                        Task { await viewModel.load() }
                    }
                } else if let projection = viewModel.projection {
                    content(projection)
                }
            }
        }
        .navigationTitle("本次装备")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if viewModel.isEditable {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("添加装备", systemImage: "plus") {
                            isAddingItem = true
                        }
                        Button("重新核对拥有状态", systemImage: "arrow.triangle.2.circlepath") {
                            Task { await viewModel.recheckOwnership() }
                        }
                        Button("管理我的装备", systemImage: "backpack") {
                            viewModel.prepareForPersonalEquipment()
                            onManagePersonalEquipment()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(
                                width: RootNavigation.toolButtonHitSize,
                                height: RootNavigation.toolButtonHitSize
                            )
                    }
                    .disabled(viewModel.isMutating)
                    .accessibilityLabel("管理本次装备")
                }
            }
        }
        .sheet(isPresented: $isAddingItem) {
            TripEquipmentEditor(title: "添加本次装备") { input in
                await viewModel.addItem(
                    name: input.name,
                    quantity: input.quantity,
                    unitWeightGrams: input.unitWeightGrams,
                    note: input.note
                )
                return viewModel.errorMessage == nil
            }
        }
        .sheet(item: $editingItem) { item in
            TripEquipmentEditor(title: "编辑本次装备", item: item) { input in
                await viewModel.updateItem(
                    itemID: item.identity,
                    update: TripEquipmentItemUpdate(
                        name: input.name,
                        quantity: input.quantity,
                        unitWeight: input.unitWeightGrams.map {
                            .value(EquipmentWeight(grams: $0))
                        } ?? .clear,
                        note: input.note.map(TripEquipmentUpdateField.value) ?? .clear
                    )
                )
                return viewModel.errorMessage == nil
            }
        }
        .confirmationDialog(
            "删除这件本次装备？",
            isPresented: Binding(
                get: { deletingItem != nil },
                set: { if !$0 { deletingItem = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let deletingItem {
                Button("删除装备", role: .destructive) {
                    let itemID = deletingItem.identity
                    self.deletingItem = nil
                    Task { await viewModel.deleteItem(itemID: itemID) }
                }
            }
        } message: {
            Text("仅从本次行程快照中删除，不会删除个人装备。")
        }
        .onAppear { Task { await viewModel.handleAppearance() } }
        .onChange(of: viewModel.projection?.revision) { revision in
            if let revision { onRevisionChange(revision) }
        }
    }

    private func content(_ projection: TripEquipmentProjection) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.lg) {
                summaryPanel(projection.snapshot.summary)

                if !projection.editable {
                    Label("该行程已进入\(projection.trip.status.title)，装备快照仅供查看。", systemImage: "lock")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.surfacePrimary, in: RoundedRectangle(cornerRadius: Radius.md))
                }

                if projection.snapshot.items.isEmpty {
                    Text("暂无本次装备")
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Spacing.lg)
                        .background(AppColors.surfacePrimary, in: RoundedRectangle(cornerRadius: Radius.md))
                } else {
                    ForEach(projection.snapshot.items) { item in
                        itemRow(item, editable: projection.editable)
                    }
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.statusCancelled)
                }
            }
            .padding(.horizontal, Spacing.pageHorizontal)
            .padding(.vertical, Spacing.lg)
        }
        .refreshable { await viewModel.load() }
    }

    private func summaryPanel(_ summary: PersonalTripEquipmentSummary) -> some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("装备总览")
                    .font(.headline)
                Text("\(summary.itemCount) 类 · 已知总重量 \(tripEquipmentWeightText(summary.knownTotalWeight.grams))")
                    .foregroundStyle(AppColors.textSecondary)
                Text("已有 \(summary.ownedItemCount) 类 · 未确认已有 \(summary.unconfirmedOwnedItemCount) 类 · \(summary.missingWeightItemCount) 类重量未知")
                    .font(.caption)
                    .foregroundStyle(AppColors.textWeak)
            }
        }
    }

    private func itemRow(_ item: TripEquipmentItem, editable: Bool) -> some View {
        WalkPanel {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name)
                        .font(.headline)
                    Spacer()
                    Text("× \(item.quantity)")
                        .foregroundStyle(AppColors.textSecondary)
                }
                Text(item.unitWeight.map { unitWeight in
                    let totalWeight = item.totalWeight ?? unitWeight
                    return "单件 \(tripEquipmentWeightText(unitWeight.grams)) · 合计 \(tripEquipmentWeightText(totalWeight.grams))"
                } ?? "单件重量未知")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                HStack {
                    Text(item.source.title)
                    Text(item.ownershipStatus.title)
                }
                .font(.caption)
                .foregroundStyle(AppColors.textWeak)
                if let note = item.note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
                if editable {
                    HStack {
                        Button("编辑") { editingItem = item }
                            .buttonStyle(.bordered)
                        Button("删除", role: .destructive) { deletingItem = item }
                            .buttonStyle(.bordered)
                    }
                    .disabled(viewModel.isMutating)
                }
            }
        }
    }
}

private extension TripEquipmentItemSource {
    var title: String {
        switch self {
        case .systemSuggestion: "系统建议"
        case .userAdjusted: "已调整建议"
        case .userAdded: "用户添加"
        }
    }
}

private extension TripEquipmentOwnershipStatus {
    var title: String {
        switch self {
        case .owned: "已有"
        case .unconfirmedOwned: "未确认已有"
        }
    }
}

private struct TripEquipmentEditorInput {
    let name: String
    let quantity: Int
    let unitWeightGrams: Int?
    let note: String?
}

private struct TripEquipmentEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var quantity: Int
    @State private var unitWeightText: String
    @State private var note: String
    @State private var isSaving = false

    let title: String
    let onSave: (TripEquipmentEditorInput) async -> Bool

    init(
        title: String,
        item: TripEquipmentItem? = nil,
        onSave: @escaping (TripEquipmentEditorInput) async -> Bool
    ) {
        self.title = title
        self.onSave = onSave
        _name = State(initialValue: item?.name ?? "")
        _quantity = State(initialValue: item?.quantity ?? 1)
        _unitWeightText = State(initialValue: item?.unitWeight.map { String($0.grams) } ?? "")
        _note = State(initialValue: item?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("装备名称", text: $name)
                Stepper("数量：\(quantity)", value: $quantity, in: 1...999)
                TextField("单件克重（可选）", text: $unitWeightText)
                    .keyboardType(.numberPad)
                TextField("备注（可选）", text: $note, axis: .vertical)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!isValid || isSaving)
                }
            }
        }
    }

    private var isValid: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWeight = unitWeightText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty
            && quantity > 0
            && (trimmedWeight.isEmpty || (Int(trimmedWeight) ?? 0) > 0)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedWeight = unitWeightText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let input = TripEquipmentEditorInput(
            name: trimmedName,
            quantity: quantity,
            unitWeightGrams: trimmedWeight.isEmpty ? nil : Int(trimmedWeight),
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )
        isSaving = true
        Task {
            let succeeded = await onSave(input)
            isSaving = false
            if succeeded { dismiss() }
        }
    }
}

private func tripEquipmentWeightText(_ grams: Int) -> String {
    grams >= 1_000
        ? "\((Double(grams) / 1_000).formatted(.number.precision(.fractionLength(0...2)))) kg"
        : "\(grams) g"
}
