import Foundation
import WalkData

/// 响应缓存的启动生命周期。
///
/// 依据 specs/README.md R-INVALIDATION：`remoteOnly` 请求不访问响应缓存，期间服务端的修改
/// 不会使本地缓存失效；因此再次以 `real` 启动时，先清理此前的响应缓存。
/// 只记录「自上次清理以来是否以 remoteOnly 启动过」，中间隔着 mock 启动也不会遗漏。
struct ResponseCacheLifecycle {
    static let key = "walk.response-cache.remote-only-since-clear"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 记录本次启动模式，返回是否需要在创建依赖前清理响应缓存。
    func recordLaunch(_ mode: WalkDataMode) -> Bool {
        switch mode {
        case .remoteOnly:
            defaults.set(true, forKey: Self.key)
            return false
        case .real:
            guard defaults.bool(forKey: Self.key) else { return false }
            defaults.removeObject(forKey: Self.key)
            return true
        case .mock:
            return false
        }
    }
}
