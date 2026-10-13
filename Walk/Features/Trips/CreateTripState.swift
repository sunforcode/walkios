import Foundation
import WalkData

struct CreateTripState {
    struct Draft {
        var departureCity = ""
        var startDate = BusinessCalendar.startOfToday()
        var selectedEquipmentListID: String?
        var selectedTransportOptionID: String?
    }

    enum Phase: Equatable {
        case idle
        case loading(versionConflict: Bool)
        case ready
        case submitting
        case versionConflict
        case created(String)
    }

    var draft = Draft()
    var context: PersonalTripGenerationContext?
    var transportSelection: PersonalTripTransportSelection?
    var phase: Phase = .idle
    var errorMessage: String?

    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }
    var isVersionConflict: Bool {
        phase == .versionConflict || phase == .loading(versionConflict: true)
    }
    var departureCityError: String? {
        draft.departureCity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "请先填写城市，再生成个人行程。" : nil
    }
    var canSubmit: Bool {
        guard phase == .ready,
              context?.route.generationEligibility.eligible == true,
              departureCityError == nil else { return false }
        return transportSelection == nil || draft.selectedTransportOptionID != nil
    }
}
