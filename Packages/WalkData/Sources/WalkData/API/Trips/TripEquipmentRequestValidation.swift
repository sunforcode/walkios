import Foundation

public enum EquipmentRequestValidationError: Error, Equatable {
    case missingRevision
    case invalidRevision
    case emptyIdempotencyKey
}

public enum EquipmentRequestHeaders {
    /// 键是调用方一次业务操作的身份，重试时原样复用，不重新生成或清理。
    public static func idempotency(key: String) throws -> [String: String] {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EquipmentRequestValidationError.emptyIdempotencyKey
        }
        return ["Idempotency-Key": key]
    }

    public static func ifMatch(revision: String) throws -> [String: String] {
        guard isValidRevision(revision) else {
            throw EquipmentRequestValidationError.invalidRevision
        }
        return ["If-Match": "\"\(revision)\""]
    }

    static func isValidRevision(_ revision: String) -> Bool {
        !revision.isEmpty && revision.unicodeScalars.allSatisfy {
            $0.value > 0x20 && $0.value != 0x22 && $0.value != 0x7f
        }
    }
}

public enum EquipmentResponseValidation {
    /// 大小写不敏感匹配字段名，但标签必须与本次正文 revision 完全对应。
    public static func validate(revision: String, headers: [String: String]) throws {
        let entityTags = headers.filter { $0.key.caseInsensitiveCompare("ETag") == .orderedSame }
        guard EquipmentRequestHeaders.isValidRevision(revision),
              entityTags.count == 1,
              entityTags.first?.value == "\"\(revision)\"" else {
            throw APIClientError.invalidResponse
        }
    }
}
