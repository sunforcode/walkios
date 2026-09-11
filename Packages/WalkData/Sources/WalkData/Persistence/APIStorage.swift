import Foundation
import CryptoKit

public protocol APIStorage {
    func save(_ data: Data, for key: String) async throws
    func load(for key: String) async throws -> Data?
    func remove(for key: String) async throws
    func removeAll() async throws
}

public actor APIStorageGeneration {
    private var value = 0

    public init() {}

     public func snapshot() -> Int { value }
     public func isCurrent(_ snapshot: Int) -> Bool { snapshot == value }
     public func invalidate() { value += 1 }
}

public struct APIStorageContext {
     public let schemaVersion: String
     public let environment: String
    private let userIDProvider: @Sendable () -> String

     public init(schemaVersion: String, environment: String, userID: String) {
        self.schemaVersion = schemaVersion
        self.environment = environment
        self.userIDProvider = { userID }
    }

     public init(
        schemaVersion: String,
        environment: String,
        userIDProvider: @escaping @Sendable () -> String
    ) {
        self.schemaVersion = schemaVersion
        self.environment = environment
        self.userIDProvider = userIDProvider
    }

     public var currentUserID: String {
        userIDProvider()
    }
}

public enum StorageKey {
     public static func make<Request: APIRequest>(
        for request: Request,
        schemaVersion: String,
        environment: String,
        userID: String
    ) -> String {
        "schema=\(schemaVersion)|environment=\(environment)|user=\(userID)|request=\(request.identifier)"
    }
}

public actor JSONFileAPIStorage: APIStorage {
    private let directory: URL
    private let fileManager: FileManager

     public init(directory: URL, fileManager: FileManager = .default) throws {
        self.directory = directory
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

     public func save(_ data: Data, for key: String) async throws {
        try data.write(to: fileURL(for: key), options: .atomic)
    }

     public func load(for key: String) async throws -> Data? {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

     public func remove(for key: String) async throws {
        let url = fileURL(for: key)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

     public func removeAll() async throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        for url in try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) where url.pathExtension == "json" {
            try fileManager.removeItem(at: url)
        }
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(digest).appendingPathExtension("json")
    }
}
