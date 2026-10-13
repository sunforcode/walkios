import Foundation
import WalkData

struct TripEquipmentState {
    enum Editor {
        case adding
        case editing(TripEquipmentItem)

        var title: String {
            switch self {
            case .adding: "新增本次装备"
            case .editing: "修改本次装备"
            }
        }
    }

    struct Draft {
        var name = ""
        var quantity = 1
        var unitWeight = ""
        var note = ""

        var nameError: String? {
            name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "请输入装备名称" : nil
        }
        var unitWeightError: String? {
            let text = unitWeight.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            guard let value = Double(text), value.isFinite, value > 0 else {
                return "请输入大于零的有限克重，可填写小数"
            }
            return nil
        }
        var isValid: Bool { nameError == nil && quantity > 0 && unitWeightError == nil }
    }

    enum Phase { case idle, loading, mutating }

    struct SourceCommand: Equatable {
        let mode: TripEquipmentSourceMode
        let identity: String
        let quantity: Int
        let revision: String
        let idempotencyKey: String
    }

    var projection: TripEquipmentProjection?
    var phase: Phase = .idle
    var errorMessage: String?
    var editor: Editor?
    var draft = Draft()
    var deletingItem: TripEquipmentItem?
    var deletionError: String?

    var sourceMode: TripEquipmentSourceMode?
    var personalCandidates: [PersonalEquipment] = []
    var listCandidates: [EquipmentListOverview] = []
    var selectedSourceID: String?
    var sourceQuantity = 1
    var isSourceLoading = false
    var sourceLoadError: String?
    var pendingSourceCommand: SourceCommand?
    var requiresReload = false
    var offersReload = false

    var isLoading: Bool { phase == .loading }
    var isMutating: Bool { phase == .mutating }
}
