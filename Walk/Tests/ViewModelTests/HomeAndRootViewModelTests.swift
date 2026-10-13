import XCTest
import WalkData
import WalkDesignSystem
@testable import Walk

@MainActor
final class HomeAndRootViewModelTests: XCTestCase {
    func testLoginSendCodeStoresVerificationIdentity() async {
        let expires = Date(timeIntervalSince1970: 1_800_000_000)
        let sut = LoginViewModel(
            sendCode: { phone in
                XCTAssertEqual(phone, "+8613800138000")
                return VerificationCodeResponse(
                    verificationId: "verification-1",
                    expiresAt: expires,
                    resendAvailableAt: expires
                )
            },
            createSession: { _, _ in XCTFail("session must not be created yet") },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.updatePhone("+8613800138000")

        await sut.sendVerificationCode()

        XCTAssertEqual(sut.verificationID, "verification-1")
        XCTAssertEqual(sut.phase, .verificationCode)
    }

    // account-api：phone SHALL 是 ^\+[1-9][0-9]{1,14}$ 国际格式；PAGE-LOGIN 校准状态：页面不自动补 +86。
    // 因此 normalizedPhone 只接受已是国际格式的输入，不为国内裸号补 +86。
    func testLoginAcceptsInternationalE164PhoneOnly() {
        XCTAssertEqual(LoginViewModel.normalizedPhone("+8613800138000"), "+8613800138000")
        XCTAssertEqual(LoginViewModel.normalizedPhone("+14155550123"), "+14155550123")
        XCTAssertNil(LoginViewModel.normalizedPhone("13800138000"), "不自动补 +86")
        XCTAssertNil(LoginViewModel.normalizedPhone(" 13800138000 "), "不自动补 +86")
        XCTAssertNil(LoginViewModel.normalizedPhone("23800138000"))
        XCTAssertNil(LoginViewModel.normalizedPhone("12345"))
        XCTAssertNil(LoginViewModel.normalizedPhone(""))
    }

    // PAGE-LOGIN：不自动补 +86；客户端按用户输入的国际格式手机号原样发送。
    func testLoginSendCodeSendsInternationalE164PhoneAsEntered() async {
        var sentPhones: [String] = []
        let expires = Date(timeIntervalSince1970: 1_800_000_000)
        let sut = LoginViewModel(
            sendCode: { phone in
                sentPhones.append(phone)
                return VerificationCodeResponse(
                    verificationId: "verification-2",
                    expiresAt: expires,
                    resendAvailableAt: expires
                )
            },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.updatePhone("+8613800138000")
        XCTAssertTrue(sut.canSendCode)

        await sut.sendVerificationCode()

        XCTAssertEqual(sentPhones, ["+8613800138000"])
        XCTAssertEqual(sut.phase, .verificationCode)
        XCTAssertNil(sut.errorMessage)
    }

    func testLoginSendCodeShowsGuidanceForInvalidPhone() async {
        let sut = LoginViewModel(
            sendCode: { _ in
                XCTFail("must not send for invalid phone")
                struct UnexpectedSend: Error {}
                throw UnexpectedSend()
            },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.updatePhone("12345")

        await sut.sendVerificationCode()

        XCTAssertNotNil(sut.errorMessage)
        XCTAssertNil(sut.verificationID)
        XCTAssertEqual(sut.phase, LoginViewModel.Phase.phone)
    }

    func testLoginSendThrottlePreservesRetryTimeAndBlocksPrematureResend() async {
        let retryAt = Date(timeIntervalSinceNow: 300)
        var sendCount = 0
        let sut = LoginViewModel(
            sendCode: { _ in
                sendCount += 1
                throw APIClientError.api(
                    code: "verification_send_throttled",
                    message: "发送受限",
                    retryable: true,
                    details: APIErrorDetails(retryAvailableAt: retryAt)
                )
            },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.updatePhone("+8613800138000")

        await sut.sendVerificationCode()
        await sut.sendVerificationCode()

        XCTAssertEqual(sendCount, 1)
        XCTAssertEqual(sut.retryAvailableAt, retryAt)
        XCTAssertNil(sut.errorMessage, "限流应由 AuthPanel.throttled 投影呈现，不与发送失败态叠加")
    }

    func testLoginCreatesSessionThenLoadsAccount() async {
        var calls: [String] = []
        let account = AccountResponse(
            account: AccountProjection(identity: "account-1"),
            profile: ProfileProjection(identity: "profile-1", maskedPhone: "+86 138****8000", nickname: nil, avatar: nil)
        )
        let sut = LoginViewModel(
            sendCode: { _ in Self.verification() },
            createSession: { verificationID, code in
                calls.append("session:\(verificationID):\(code)")
            },
            loadAccount: {
                calls.append("account")
                return account
            }
        )
        sut.updatePhone("+8613800138000")
        await sut.sendVerificationCode()
        sut.updateCode("012345")

        await sut.login()

        XCTAssertEqual(calls, ["session:verification-1:012345", "account"])
        XCTAssertEqual(sut.account, account)
        XCTAssertTrue(sut.didAuthenticate)
    }

    // account-api：code 是 NonEmptyText，保留前导零按文本校验；PAGE-LOGIN：不固定验证码长度。
    // canLogin 只要求已取得 verificationID 且验证码非空，不固定位数。
    func testLoginRequiresVerificationIDAndNonEmptyCode() async {
        let sut = LoginViewModel(
            sendCode: { _ in Self.verification() },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.updateCode("012345")
        XCTAssertFalse(sut.canLogin, "无 verificationID 不可登录")

        sut.updatePhone("+8613800138000")
        await sut.sendVerificationCode()
        sut.updateCode("")
        XCTAssertFalse(sut.canLogin, "空验证码不可登录")

        // 不固定验证码长度：任意非空数字验证码均可提交。
        for validCode in ["1", "12345", "1234567", "012345"] {
            sut.updateCode(validCode)
            XCTAssertTrue(sut.canLogin, "\(validCode) 应允许登录")
        }
    }

    func testSessionSuccessAuthenticatesEvenWhenAccountProjectionFails() async {
        var calls: [String] = []
        let sut = LoginViewModel(
            sendCode: { _ in Self.verification() },
            createSession: { _, _ in calls.append("session") },
            loadAccount: {
                calls.append("account")
                throw APIClientError.api(
                    code: "account_temporarily_unavailable",
                    message: "账号资料暂不可用",
                    retryable: true
                )
            }
        )
        sut.updatePhone("+8613800138000")
        await sut.sendVerificationCode()
        sut.updateCode("012345")

        await sut.login()

        XCTAssertEqual(calls, ["session", "account"])
        XCTAssertTrue(sut.didAuthenticate)
        XCTAssertNil(sut.account)
        XCTAssertNil(sut.errorMessage)
    }

    func testSessionSuccessPublishesAuthenticationBeforeAccountProjectionCompletes() async {
        let accountReadStarted = expectation(description: "account read started")
        let gate = AsyncGate()
        let sut = LoginViewModel(
            sendCode: { _ in Self.verification() },
            createSession: { _, _ in },
            loadAccount: {
                accountReadStarted.fulfill()
                await gate.wait()
                throw APIClientError.invalidResponse
            }
        )
        sut.updatePhone("+8613800138000")
        await sut.sendVerificationCode()
        sut.updateCode("012345")

        let loginTask = Task { await sut.login() }
        await fulfillment(of: [accountReadStarted], timeout: 1)

        XCTAssertTrue(sut.didAuthenticate)
        await gate.open()
        await loginTask.value
    }

    func testLoginReceivesPendingRootIntentForSourceContext() throws {
        let rootSource = try productionSource(at: "App/RootView.swift")
        let loginSource = try productionSource(at: "Features/Profile/LoginView.swift")

        XCTAssertTrue(rootSource.contains("intent: authFlow.pending?.intent"))
        XCTAssertTrue(loginSource.contains("let intent: PendingAuthIntent?"))
        XCTAssertFalse(loginSource.contains("case .homeStart"))
        XCTAssertTrue(loginSource.contains("case .trips"))
        XCTAssertTrue(loginSource.contains("case .equipment"))
        XCTAssertTrue(loginSource.contains("case .createTrip"))
        XCTAssertTrue(loginSource.contains("case .profile"))
    }

    func testDefaultMockFixturesSupportTypedLoginAndLogout() async throws {
        let client = MockAPIClient(fixtures: DefaultMockFixtures.accountFixtures())

        let verification = try await client.execute(AccountAPI.SendVerificationCode(phone: "+8613800138000"))
        let session = try await client.execute(AccountAPI.CreateSession(
            verificationID: verification.verificationId,
            code: "123456"
        ))
        let logout = try await client.execute(AccountAPI.Logout())

        XCTAssertFalse(verification.verificationId.isEmpty)
        XCTAssertEqual(session.tokenType, "Bearer")
        XCTAssertFalse(session.accessToken.isEmpty)
        XCTAssertTrue(logout.loggedOut)
    }
    func testSystemTabBarVisibilityTracksTheSelectedNavigationPath() {
        var sut = AppShellState()
        XCTAssertTrue(sut.showsGlobalNavigation)

        sut.selectTab(.trips)
        sut.setPath([.tripDetail("trip-1")], for: .trips)
        XCTAssertFalse(sut.showsGlobalNavigation)

        sut.selectTab(.routes)
        XCTAssertTrue(sut.showsGlobalNavigation)

        sut.setPath([.routeList], for: .routes)
        XCTAssertFalse(sut.showsGlobalNavigation)
    }

    func testRootUsesSystemTabBarOnlyOnRootPages() throws {
        let navigationSource = try productionSource(at: "App/RootNavigation.swift")
        let rootSource = try productionSource(at: "App/RootView.swift")

        XCTAssertFalse(navigationSource.contains("UITabBar.appearance().isHidden = true"))
        XCTAssertFalse(rootSource.contains("PrimaryTabBar("))
        XCTAssertTrue(rootSource.contains(".toolbar(.hidden, for: .tabBar)"))
    }

    func testCancelledSendCodeCannotPublishLateVerification() async {
        let started = expectation(description: "send started")
        let gate = AsyncGate()
        let sut = LoginViewModel(
            sendCode: { _ in
                started.fulfill()
                await gate.wait()
                return Self.verification()
            },
            createSession: { _, _ in XCTFail("must not authenticate") },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.updatePhone("+8613800138000")
        let task = Task { await sut.sendVerificationCode() }
        await fulfillment(of: [started], timeout: 1)
        sut.cancelPendingOperations()
        await gate.open()
        await task.value
        XCTAssertNil(sut.verificationID)
        XCTAssertEqual(sut.phase, .phone)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isSubmitting)
    }

    func testSendCodeTaskCancellationRejectsSuccessfulLateResponse() async {
        let started = expectation(description: "send started")
        let gate = AsyncGate()
        let sut = LoginViewModel(
            sendCode: { _ in
                started.fulfill()
                await gate.wait()
                return Self.verification()
            },
            createSession: { _, _ in },
            loadAccount: { throw APIClientError.invalidResponse }
        )
        sut.updatePhone("+8613800138000")
        let task = Task { await sut.sendVerificationCode() }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        await gate.open()
        await task.value
        XCTAssertNil(sut.verificationID)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isSubmitting)
    }

    func testSendCodeCancellationErrorsAreNotPresentedAsFailures() async {
        let cancellationErrors: [Error] = [CancellationError(), APIClientError.transport(.cancelled)]
        for error in cancellationErrors {
            let sut = LoginViewModel(
                sendCode: { _ in throw error },
                createSession: { _, _ in },
                loadAccount: { throw APIClientError.invalidResponse }
            )
            sut.updatePhone("+8613800138000")
            await sut.sendVerificationCode()
            XCTAssertNil(sut.errorMessage)
            XCTAssertNil(sut.verificationID)
            XCTAssertFalse(sut.isSubmitting)
        }
    }

    func testLoginDoesNotFillAccountAfterPageCancellation() async {
        let started = expectation(description: "account started")
        let gate = AsyncGate()
        let sut = LoginViewModel(
            sendCode: { _ in Self.verification() },
            createSession: { _, _ in },
            loadAccount: {
                started.fulfill()
                await gate.wait()
                return AccountResponse(
                    account: AccountProjection(identity: "old"),
                    profile: ProfileProjection(identity: "profile", maskedPhone: "***", nickname: nil, avatar: nil)
                )
            }
        )
        sut.updatePhone("+8613800138000")
        await sut.sendVerificationCode()
        sut.updateCode("012345")
        let task = Task { await sut.login() }
        await fulfillment(of: [started], timeout: 1)
        XCTAssertTrue(sut.didAuthenticate, "认证完成仍先于可选账号回填")
        sut.cancelPendingOperations()
        await gate.open()
        await task.value
        XCTAssertNil(sut.account)
        XCTAssertFalse(sut.isSubmitting)
    }

    func testLoginStateOwnsPhoneValidationAndCooldownCapabilities() {
        var state = LoginState()
        state.phone = "12345"
        XCTAssertNotNil(state.phoneValidationError)
        state.phone = "+8613800138000"
        XCTAssertNil(state.phoneValidationError)
        let now = Date(timeIntervalSince1970: 1_000)
        state.resendAvailableAt = now.addingTimeInterval(60)
        XCTAssertFalse(state.canSendCode(at: now))
        XCTAssertFalse(state.canResend(at: now))
        XCTAssertTrue(state.canSendCode(at: now.addingTimeInterval(60)))
        state.retryAvailableAt = now.addingTimeInterval(120)
        XCTAssertFalse(state.canResend(at: now.addingTimeInterval(60)))
    }

    func testTransportCancelledSessionDoesNotAuthenticateOrShowFailure() async {
        let sut = LoginViewModel(
            sendCode: { _ in Self.verification() },
            createSession: { _, _ in throw APIClientError.transport(.cancelled) },
            loadAccount: { XCTFail("cancelled session must not load account"); throw APIClientError.invalidResponse }
        )
        sut.updatePhone("+8613800138000")
        await sut.sendVerificationCode()
        sut.updateCode("012345")
        await sut.login()
        XCTAssertFalse(sut.didAuthenticate)
        XCTAssertNil(sut.errorMessage)
        XCTAssertFalse(sut.isSubmitting)
    }

    private static func verification() -> VerificationCodeResponse {
        VerificationCodeResponse(
            verificationId: "verification-1",
            expiresAt: .distantFuture,
            resendAvailableAt: .distantPast
        )
    }

    private func productionSource(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let walkRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: walkRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

private actor AsyncGate {
    private var isOpen = false
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        isOpen = true
        continuation?.resume()
        continuation = nil
    }
}
