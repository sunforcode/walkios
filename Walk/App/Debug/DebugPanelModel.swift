#if DEBUG
import Foundation
import WalkData
import WalkDebugTools

/// 调试面板的信息与动作。
///
/// 依据 specs/README.md R-DEBUG：App 向 DebugTools 注入只读配置快照与动作回调，
/// 配置写入仍经 `DebugSettingsStore`，清缓存由数据层执行；本类型不持有第二份有效配置。
/// 依据 R-SWITCH：动作只写保存值，影响下一次启动，不改变本次的有效配置。
@MainActor
final class DebugPanelModel {
    let effective: AppConfiguration
    private let store: DebugSettingsStore
    private let clearResponseCache: () -> Void

    init(
        effective: AppConfiguration,
        store: DebugSettingsStore,
        clearResponseCache: @escaping () -> Void
    ) {
        self.effective = effective
        self.store = store
        self.clearResponseCache = clearResponseCache
    }

    /// 可选服务器。后端目前只有 vialu.cn 一个部署；测试服与线上地址相同、环境标识不同，
    /// 按服务身份规则是不同服务，缓存与会话分别隔离。
    static let servers: [(title: String, server: DebugSettings.Server)] = {
        let vialu = URL(string: "https://vialu.cn/walkbg/api/v1")!
        return [
            ("测试服 development", .init(environmentName: "development", baseURL: vialu)),
            ("线上 production", .init(environmentName: "production", baseURL: vialu)),
        ]
    }()

    // MARK: - 信息

    func infoSections() -> [DebugInfoSection] {
        var sections = [
            DebugInfoSection(title: "当前生效", rows: [
                .init(title: "数据模式", value: effective.dataMode.rawValue),
                .init(title: "服务器", value: Self.describe(effective.environmentName, effective.baseURL)),
                .init(title: "断网策略", value: Self.describe(effective.offlinePolicy)),
            ]),
        ]
        if let pending = pendingRows() {
            sections.append(DebugInfoSection(title: "重启后生效", rows: pending))
        }
        return sections
    }

    /// 只列出与当前生效值不同的维度；全部相同则没有待生效内容。
    private func pendingRows() -> [DebugInfoSection.Row]? {
        guard let saved = store.load() else { return nil }
        var rows: [DebugInfoSection.Row] = []
        if let mode = saved.dataMode, mode != effective.dataMode {
            rows.append(.init(title: "数据模式", value: mode.rawValue))
        }
        if let server = saved.server,
           server.environmentName != effective.environmentName || server.baseURL != effective.baseURL {
            rows.append(.init(title: "服务器", value: Self.describe(server.environmentName, server.baseURL)))
        }
        if let policy = saved.offlinePolicy, policy != effective.offlinePolicy {
            rows.append(.init(title: "断网策略", value: Self.describe(policy)))
        }
        return rows.isEmpty ? nil : rows
    }

    private static func describe(_ environmentName: String, _ baseURL: URL) -> String {
        "\(environmentName) · \(baseURL.absoluteString)"
    }

    private static func describe(_ policy: OfflinePolicy) -> String {
        switch policy {
        case .fail: "fail"
        case .useCache: "useCache（当前无端点登记离线资格，行为同 fail）"
        }
    }

    // MARK: - 动作

    func actionSections() -> [DebugActionSection] {
        [
            DebugActionSection(title: "数据模式", actions: WalkDataMode.allCases.map { mode in
                .init(title: mode.rawValue) { [store] in
                    Self.update(store) { .init(dataMode: mode, server: $0?.server, offlinePolicy: $0?.offlinePolicy) }
                }
            }),
            DebugActionSection(title: "服务器", actions: Self.servers.map { entry in
                .init(title: entry.title) { [store, effective] in
                    Self.update(store) { saved in
                        // 线上服务不接受 Mock（R-CONFIG）；选择线上时数据模式随之切到真实网络。
                        let mode = saved?.dataMode ?? effective.dataMode
                        let requiresRealNetwork = entry.server.environmentName.caseInsensitiveCompare("production") == .orderedSame
                        return .init(
                            dataMode: requiresRealNetwork && !mode.usesRealNetwork ? .real : saved?.dataMode,
                            server: entry.server,
                            offlinePolicy: saved?.offlinePolicy
                        )
                    }
                }
            }),
            DebugActionSection(title: "断网策略", actions: OfflinePolicy.allCases.map { policy in
                .init(title: policy.rawValue) { [store] in
                    Self.update(store) { .init(dataMode: $0?.dataMode, server: $0?.server, offlinePolicy: policy) }
                }
            }),
            DebugActionSection(title: "维护", actions: [
                .init(title: "清除响应缓存", perform: clearResponseCache),
                .init(title: "恢复构建默认值") { [store] in store.clear() },
            ]),
        ]
    }

    /// 只替换被选中的维度，其余维度保持已保存的值。
    private static func update(
        _ store: DebugSettingsStore,
        _ transform: (DebugSettings?) -> DebugSettings
    ) {
        store.save(transform(store.load()))
    }
}
#endif
