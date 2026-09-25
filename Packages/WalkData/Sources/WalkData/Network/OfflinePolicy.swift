import Foundation

/// 明确断网 / 连接中断后的失败处理策略。
///
/// 依据 specs/README.md R-CACHE-POLICY：读取顺序为网络优先，失败处理独立建模。
/// 策略由数据层执行，App 注入默认策略，端点声明允许范围。
public enum OfflinePolicy: String, CaseIterable, Equatable, Sendable {
    /// 返回本次连接错误，不以缓存替代结果。未配置时的默认值。
    case fail
    /// 对允许离线读取的只读端点，尝试返回合格缓存；没有合格缓存时仍返回原始连接错误。
    case useCache

    public static let `default`: OfflinePolicy = .fail
}

/// 端点的离线读取资格登记。
///
/// 依据 R-CACHE-VALIDITY：允许保存与允许离线读取分别声明，现有 `.store` 只能证明保存资格。
/// 离线资格至少登记上游依据、有效期、失效事件及调用方如何处理缓存来源；
/// 缺少任何一项时默认不允许离线返回。
///
/// 构造本类型即表示已完成登记；未登记的端点返回 `nil`。
public struct OfflineEligibility: Equatable, Sendable {
    /// 允许离线返回的上游依据。不得凭实现便利自行授予。
    public let upstreamBasis: String
    /// 有效期。首版不返回过期缓存。
    public let maxAge: TimeInterval

    public init(upstreamBasis: String, maxAge: TimeInterval) {
        self.upstreamBasis = upstreamBasis
        self.maxAge = maxAge
    }

    /// 缓存是否仍在有效期内。首版不返回过期缓存。
    public func isFresh(savedAt: Date, now: Date) -> Bool {
        let age = now.timeIntervalSince(savedAt)
        return age >= 0 && age <= maxAge
    }
}
