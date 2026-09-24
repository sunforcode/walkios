import XCTest
import WalkData
@testable import Walk

/// W2-3：认证命名空间与注入。
///
/// 依据 specs/README.md R-AUTH：客户端、Service 与页面使用 App 注入的同一认证实例；
/// 认证管理器不重新读取启动参数、Info.plist 或 Debug 偏好。认证命名空间以最终服务身份为基础，
/// 再区分 Mock 与真实：Mock 独立；同一服务下 real / remoteOnly 共用真实会话；
/// 不同环境标识或不同 baseURL 隔离。
final class AuthNamespaceTests: XCTestCase {
    private let vialu = URL(string: "https://vialu.cn/walkbg/api/v1")!

    func testMockAndRealUseDifferentNamespacesForTheSameService() {
        let service = APIServiceIdentity(environmentName: "development", baseURL: vialu)
        XCTAssertNotEqual(
            AuthManager.namespace(for: service, isMock: true),
            AuthManager.namespace(for: service, isMock: false)
        )
    }

    func testDifferentServicesAreIsolated() {
        let development = APIServiceIdentity(environmentName: "development", baseURL: vialu)
        let production = APIServiceIdentity(environmentName: "production", baseURL: vialu)
        let otherHost = APIServiceIdentity(
            environmentName: "development",
            baseURL: URL(string: "https://staging.vialu.cn/walkbg/api/v1")!
        )

        let namespaces = Set([development, production, otherHost].map {
            AuthManager.namespace(for: $0, isMock: false)
        })
        XCTAssertEqual(namespaces.count, 3)
    }

    func testAppEnvironmentDerivesNamespaceFromFinalConfiguration() throws {
        func namespace(_ mode: WalkDataMode, _ environmentName: String, _ url: URL) throws -> String {
            try AppEnvironment(configuration: AppConfiguration(
                dataMode: mode,
                baseURL: url,
                environmentName: environmentName
            )).authManager.persistenceNamespace
        }

        let real = try namespace(.real, "development", vialu)
        let remoteOnly = try namespace(.remoteOnly, "development", vialu)
        let mock = try namespace(.mock, "development", vialu)
        let production = try namespace(.real, "production", vialu)

        XCTAssertEqual(real, remoteOnly, "real 与 remoteOnly 共用同一真实会话")
        XCTAssertNotEqual(real, mock, "Mock 会话独立")
        XCTAssertNotEqual(real, production, "同地址不同环境标识隔离")
    }

    /// 同一 App 装配内，客户端鉴权与账号服务使用同一认证实例。
    func testAccountServiceAndClientShareTheInjectedAuthInstance() async throws {
        let environment = try AppEnvironment(configuration: AppConfiguration(
            dataMode: .mock,
            baseURL: URL(string: "https://api.example.invalid/v1")!,
            environmentName: "test"
        ), resourceBundle: Bundle(for: AuthNamespaceTests.self))
        defer { environment.authManager.currentToken = nil }

        let session = try await environment.accountService.createSession(
            verificationID: "test-verification",
            code: "123456"
        )

        XCTAssertEqual(environment.authManager.currentToken, session.accessToken)
        try await environment.accountService.logout()
        XCTAssertFalse(environment.authManager.isLoggedIn)
    }
}
