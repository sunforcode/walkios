import XCTest
import WalkData

/// account-access：调试数据源只影响当前使用环境中的认证状态。
/// 每例使用独立的 Keychain service，不读取或修改应用的真实凭据。
final class AuthConfigurationTests: XCTestCase {
    private let keychainService = "com.walk.tests.auth.\(UUID().uuidString)"
    private var managers: [AuthManager] = []

    override func tearDown() {
        managers.forEach { $0.currentToken = nil }
        managers.removeAll()
        super.tearDown()
    }

    func testMockAndRealNamespacesKeepIndependentSessions() {
        let real = makeManager(namespace: "auth_token")
        let mock = makeManager(namespace: "auth_token_mock")

        real.saveSession(accessToken: "real-test-token")
        mock.saveSession(accessToken: "mock-test-token")

        XCTAssertEqual(real.currentToken, "real-test-token")
        XCTAssertEqual(mock.currentToken, "mock-test-token")
        XCTAssertNotEqual(real.cacheIdentity, mock.cacheIdentity)
    }

    func testExplicitNamespacePersistsAcrossManagerRecreation() {
        let real = makeManager(namespace: "auth_token")
        real.saveSession(accessToken: "real-test-token")

        // real 与 remoteOnly 只改变读取策略，使用同一个真实认证 namespace。
        let remoteOnly = makeManager(namespace: "auth_token")

        XCTAssertEqual(remoteOnly.currentToken, "real-test-token")
        XCTAssertEqual(remoteOnly.cacheIdentity, real.cacheIdentity)
    }

    func testLoggingOutOrInvalidatingMockDoesNotClearRealSession() {
        let real = makeManager(namespace: "auth_token")
        let mock = makeManager(namespace: "auth_token_mock")
        real.saveSession(accessToken: "real-test-token")
        mock.saveSession(accessToken: "mock-test-token")

        mock.logout()

        XCTAssertFalse(mock.isLoggedIn)
        XCTAssertEqual(real.currentToken, "real-test-token")

        mock.saveSession(accessToken: "another-mock-test-token")
        mock.invalidateSession()

        XCTAssertFalse(mock.isLoggedIn)
        XCTAssertEqual(mock.cacheIdentity, "anonymous")
        XCTAssertEqual(real.currentToken, "real-test-token")
    }

    func testAccountServiceUsesInjectedNamespaceForLoginAndLogout() async throws {
        let real = makeManager(namespace: "auth_token")
        let mock = makeManager(namespace: "auth_token_mock")
        real.saveSession(accessToken: "real-test-token")
        let service = AccountService(
            apiClient: MockAPIClient(fixtures: DefaultMockFixtures.accountFixtures()),
            authManager: mock
        )

        let session = try await service.createSession(verificationID: "test-verification", code: "123456")

        XCTAssertEqual(mock.currentToken, session.accessToken)
        XCTAssertEqual(real.currentToken, "real-test-token")

        try await service.logout()

        XCTAssertFalse(mock.isLoggedIn)
        XCTAssertEqual(real.currentToken, "real-test-token")
    }

    private func makeManager(namespace: String) -> AuthManager {
        let manager = AuthManager(
            persistenceNamespace: namespace,
            keychainService: keychainService
        )
        managers.append(manager)
        return manager
    }
}
