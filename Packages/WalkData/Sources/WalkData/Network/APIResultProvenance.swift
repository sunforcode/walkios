import Foundation

/// 结果来源上下文。
///
/// 依据 specs/README.md R-RESULT：启用 `useCache` 的调用链必须携带结果来源与保存时间，
/// 必要时携带本次回退原因；Service 与页面能够区分本次远端结果和本地缓存结果。
///
/// 这是客户端结果上下文，不增加后端 DTO 字段；每次调用各自携带，
/// 不通过共享的「最后一次请求来源」记录并发请求信息。
public enum APIResultProvenance: Equatable, Sendable {
    /// 本次远端结果。
    case remote
    /// 本地缓存结果，携带保存时间与触发回退的断网原因。
    case cache(savedAt: Date, fallbackReason: APITransportFailure)

    public var isFromCache: Bool {
        if case .cache = self { return true }
        return false
    }

    public var savedAt: Date? {
        if case .cache(let savedAt, _) = self { return savedAt }
        return nil
    }

    public var fallbackReason: APITransportFailure? {
        if case .cache(_, let reason) = self { return reason }
        return nil
    }
}

/// 带来源上下文的结果。
public struct APIResult<Value>: Sendable where Value: Sendable {
    public let value: Value
    public let provenance: APIResultProvenance

    public init(value: Value, provenance: APIResultProvenance) {
        self.value = value
        self.provenance = provenance
    }
}
