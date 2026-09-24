import Foundation

/// 目标服务的身份。
///
/// 依据 specs/README.md R-AUTH：服务地址的身份包括协议、主机、有效端口和 API 基路径，
/// 不能仅比较显示名称。环境标识相同但地址不同，或地址相同但环境标识不同，都是不同服务。
public struct APIServiceIdentity: Equatable, Hashable, Sendable {
    public let environmentName: String
    public let scheme: String
    public let host: String
    public let port: Int
    public let basePath: String

    public init(environmentName: String, baseURL: URL) {
        self.environmentName = environmentName
        let scheme = (baseURL.scheme ?? "https").lowercased()
        self.scheme = scheme
        self.host = (baseURL.host ?? "").lowercased()
        // 显式默认端口与省略端口指向同一服务。
        self.port = baseURL.port ?? Self.defaultPort(for: scheme)
        // 尾斜杠不构成不同的基路径。
        var path = baseURL.path
        while path.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        self.basePath = path
    }

    private static func defaultPort(for scheme: String) -> Int {
        switch scheme {
        case "http": return 80
        case "https": return 443
        default: return -1
        }
    }

    /// 缓存与认证命名空间使用的稳定表示。
    public var storageNamespace: String {
        "env=\(environmentName)|service=\(scheme)://\(host):\(port)\(basePath)"
    }
}

/// 响应的缓存控制指令。
///
/// 依据 R-STORAGE：`no-store` 不保存；`no-cache` 的复用需要成功验证，
/// 不能当作离线返回许可。本类型只解析指令，不做资格判定。
public struct APICacheControl: Equatable, Codable, Sendable {
    public let noStore: Bool
    public let noCache: Bool
    public let maxAge: TimeInterval?

    public init(noStore: Bool = false, noCache: Bool = false, maxAge: TimeInterval? = nil) {
        self.noStore = noStore
        self.noCache = noCache
        self.maxAge = maxAge
    }

    /// 按指令名解析，不解析文案。无法识别的指令被忽略而不是猜测。
    public init(headerValue: String?) {
        guard let headerValue else {
            self.init()
            return
        }
        var noStore = false
        var noCache = false
        var maxAge: TimeInterval?
        for rawDirective in headerValue.split(separator: ",") {
            let directive = rawDirective.trimmingCharacters(in: .whitespaces).lowercased()
            if directive == "no-store" {
                noStore = true
            } else if directive == "no-cache" {
                noCache = true
            } else if directive.hasPrefix("max-age") {
                let parts = directive.split(separator: "=", maxSplits: 1)
                if parts.count == 2 {
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    maxAge = TimeInterval(value)
                }
            }
        }
        self.init(noStore: noStore, noCache: noCache, maxAge: maxAge)
    }
}

/// 条件验证器。首版只记录，不假设后端已支持 304。
public struct APIResponseValidators: Equatable, Codable, Sendable {
    public let eTag: String?
    public let lastModified: String?

    public init(eTag: String? = nil, lastModified: String? = nil) {
        self.eTag = eTag
        self.lastModified = lastModified
    }

    public init(headers: [AnyHashable: Any]) {
        func header(_ name: String) -> String? {
            headers.first { ($0.key as? String)?.caseInsensitiveCompare(name) == .orderedSame }?
                .value as? String
        }
        self.init(eTag: header("ETag"), lastModified: header("Last-Modified"))
    }
}

public enum CachedResponseRecordError: Error, Equatable {
    /// 无法作为缓存记录读取；旧的纯 JSON 快照属于此类。
    case unreadable
    /// 记录版本高于当前支持范围。
    case unsupportedFormatVersion
}

/// 带元数据的缓存记录。
///
/// 依据 R-STORAGE：记录包含业务响应及必要的请求匹配、来源时间和缓存控制元数据。
/// 旧的纯 JSON 快照缺少这些元数据，读取时判定为不可用，不做隐式升级。
public struct CachedResponseRecord: Equatable, Codable, Sendable {
    public static let currentFormatVersion = 1

    public let formatVersion: Int
    public let payload: Data
    public let savedAt: Date
    public let requestIdentifier: String
    public let serviceNamespace: String
    public let userID: String
    public let cacheControl: APICacheControl
    public let validators: APIResponseValidators

    public init(
        payload: Data,
        savedAt: Date,
        requestIdentifier: String,
        serviceNamespace: String,
        userID: String,
        cacheControl: APICacheControl,
        validators: APIResponseValidators
    ) {
        self.formatVersion = Self.currentFormatVersion
        self.payload = payload
        self.savedAt = savedAt
        self.requestIdentifier = requestIdentifier
        self.serviceNamespace = serviceNamespace
        self.userID = userID
        self.cacheControl = cacheControl
        self.validators = validators
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(from data: Data) throws -> CachedResponseRecord {
        let record: CachedResponseRecord
        do {
            record = try JSONDecoder().decode(CachedResponseRecord.self, from: data)
        } catch {
            // 先检查是否为更高版本，避免把前向记录误报为旧快照。
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let version = object["formatVersion"] as? Int,
               version > currentFormatVersion {
                throw CachedResponseRecordError.unsupportedFormatVersion
            }
            throw CachedResponseRecordError.unreadable
        }
        guard record.formatVersion <= currentFormatVersion else {
            throw CachedResponseRecordError.unsupportedFormatVersion
        }
        return record
    }

    /// 记录自带身份，读取时必须与当前身份比对；不匹配视为缓存不可用。
    public func matches(
        requestIdentifier: String,
        serviceNamespace: String,
        userID: String
    ) -> Bool {
        self.requestIdentifier == requestIdentifier
            && self.serviceNamespace == serviceNamespace
            && self.userID == userID
    }

    /// 是否允许保存。`no-store` 是硬约束，端点资格不能覆盖。
    public static func isPersistable(
        cacheControl: APICacheControl,
        storagePolicy: APIStoragePolicy
    ) -> Bool {
        guard storagePolicy == .store else { return false }
        return !cacheControl.noStore
    }
}
