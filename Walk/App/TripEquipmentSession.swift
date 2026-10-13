import WalkData

/// 页面返回再进入时保留尚未确认的选入命令；只存于当前认证会话内。
/// 重新读取和版本裁决由同一生产 ViewModel 与服务端处理。
@MainActor
final class TripEquipmentSession {
    private struct Entry {
        let model: TripEquipmentViewModel
        var onRevisionChange: ((String) -> Void)?
    }

    private var models: [String: Entry] = [:]
    private var generation = 0

    func model(tripID: String, service: any TripEquipmentPreparing,
               equipmentService: any EquipmentServicing,
               onRevisionChange: ((String) -> Void)? = nil) -> TripEquipmentViewModel {
        if var entry = models[tripID] {
            if let onRevisionChange {
                entry.onRevisionChange = onRevisionChange
                models[tripID] = entry
            }
            return entry.model
        }
        let modelGeneration = generation
        let model = TripEquipmentViewModel(tripID: tripID, service: service, equipmentService: equipmentService,
            onRevisionChange: { [weak self] revision in
                guard let self, self.generation == modelGeneration else { return }
                self.models[tripID]?.onRevisionChange?(revision)
            })
        models[tripID] = Entry(model: model, onRevisionChange: onRevisionChange)
        return model
    }

    func clear() {
        generation += 1
        models.removeAll()
    }
}
