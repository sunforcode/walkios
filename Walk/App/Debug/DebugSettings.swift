import Foundation
import WalkData

/// 已保存的 Debug 设置。
///
/// 依据 specs/README.md R-CONFIG：数据模式与服务器身份是独立维度，未设置的维度回落到下一级来源。
/// 依据 R-SWITCH：保存只影响下一次启动，不热替换当前实例。
/// 本类型只是解析器的一个输入来源；Release 构建不读取它。
struct DebugSettings: Equatable, Codable {
    static let currentVersion = 1

    struct Server: Equatable, Codable {
        let environmentName: String
        let baseURL: URL
    }

    let version: Int
    let dataMode: WalkDataMode?
    let server: Server?
    /// 断网策略。缺失时回落到下一级来源；未含该字段的记录仍可读取。
    let offlinePolicy: OfflinePolicy?

    init(dataMode: WalkDataMode?, server: Server?, offlinePolicy: OfflinePolicy? = nil) {
        self.version = Self.currentVersion
        self.dataMode = dataMode
        self.server = server
        self.offlinePolicy = offlinePolicy
    }
}

extension WalkDataMode: Codable {}
extension OfflinePolicy: Codable {}

/// Debug 设置的单一持久化记录。
///
/// 旧 `walk.debug.environment` 预设属于临时状态，不迁移；无法读取或版本更高的记录被忽略，不猜测。
struct DebugSettingsStore {
    static let key = "walk.debug.settings"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> DebugSettings? {
        guard let data = defaults.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(DebugSettings.self, from: data),
              settings.version == DebugSettings.currentVersion else {
            return nil
        }
        return settings
    }

    func save(_ settings: DebugSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
