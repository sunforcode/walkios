import Foundation

/// 数据运行模式。
///
/// 依据 specs/README.md R-MODE：具体数据能力分为 Mock 与真实两类；
/// `real / remoteOnly` 使用同一类真实实现，通过策略装配区分。
///
/// 依据 R-MIGRATION：`local` 没有等价新模式，因此这里不提供该分支；
/// 缓存回放由测试直接注入存储完成，不映射为真实网络或 remoteOnly。
public enum WalkDataMode: String, CaseIterable, Sendable {
    /// 不调用真实业务网络，结果由模拟场景定义。
    case mock
    /// 网络优先，按端点资格与所选策略读写响应缓存。
    case real
    /// 发起真实请求，绕过应用响应缓存及 HTTP 客户端缓存。
    case remoteOnly

    /// 是否使用真实网络能力。`real` 与 `remoteOnly` 共用同一类实现。
    public var usesRealNetwork: Bool {
        switch self {
        case .mock: return false
        case .real, .remoteOnly: return true
        }
    }

    /// 模式对响应缓存的硬约束。
    public var responseCachePolicy: APIResponseCachePolicy {
        switch self {
        case .remoteOnly: return .disabled
        case .mock, .real: return .enabled
        }
    }

    /// 模式硬约束优先于所选策略。
    ///
    /// `remoteOnly` 下任何缓存策略都不得启用回退；这是 R-MODE 的硬约束，
    /// 不能被 App 注入的默认策略或 DebugTools 选择覆盖。
    public func effectiveOfflinePolicy(selected: OfflinePolicy) -> OfflinePolicy {
        switch self {
        case .remoteOnly, .mock: return .fail
        case .real: return selected
        }
    }
}
